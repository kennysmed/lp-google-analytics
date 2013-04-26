# coding: utf-8
require 'oauth2'
require 'sinatra'

require_relative 'lib/analytics.rb'

enable :sessions

raise 'GOOGLE_CLIENT_ID is not set' if !ENV['GOOGLE_CLIENT_ID']
raise 'GOOGLE_CLIENT_SECRET is not set' if !ENV['GOOGLE_CLIENT_SECRET']


auth_client = OAuth2::Client.new(
  ENV['GOOGLE_CLIENT_ID'], ENV['GOOGLE_CLIENT_SECRET'], {
    :site => 'https://accounts.google.com',
    :authorize_url => '/o/oauth2/auth',
    :token_url => '/o/oauth2/token'
  })


configure do
  if settings.development?
    # So we can see what's going wrong on Heroku.
    set :show_exceptions, true
  end

  # What's the maximum number of Analytics Profiles we allow the user to
  # subscribe to in one publication?
  set :maximum_profiles, 3

  # The different frequencies we can display results for.
  # The frequencies should be options within the URL route matching for each
  # endpoint, eg:
  #   get %r{/(daily|weekly)/edition/} do |frequency|
  set :valid_frequencies, ['daily', 'weekly']

  # The default, which can be changed depending on URL.
  set :frequency, 'daily'

  # Which day of the week does the weekly version appear on?
  # 1 = Monday, 2 = Tuesday, etc.
  # NOTE: Google Analytics weeks only run Sun-Sat, so we can't currently
  # change which kind of week's data we output.
  set :weekly_day, 1
end


helpers do
  # Set the `frequency` setting to `frequency` if it's valid. Else, ignore.
  def set_frequency(frequency)
    settings.frequency = frequency if settings.valid_frequencies.include?(frequency)
  end

  # Extract the Account ID from a Web Property ID.
  # Web Property ID is like 'UA-89135-2' and Account ID is '89135'
  def web_property_id_to_account_id(wp_id)
    /^UA-(\d+)-\d+$/.match(wp_id)[1].to_i
  end

  # Create a structure that lists a user's Accounts, Web Properties and
  # Profiles.
  # Each one is keyed by its ID (integers for Accounts and Profiles, strings
  # for Web Properties)
  # {
  #   12345 => {
  #     'name'=>'Account Name',
  #     'properties'=>{
  #       'UA-12345-1' => {
  #         'name'=>'Web Property Name',
  #         'profiles'=>{
  #           '98765'  => {'name'=>'Profile Name A'},
  #           '876543' => {'name'=>'Profile Name B'}
  #         }, 
  #       },
  #       ...
  #     },
  #     ...
  #   }
  # }
  def get_profiles(user)
    user_profiles = {}

    user.accounts.each do |a|
      user_profiles[a.id.to_i] = {'name'=>a.name, 'properties'=>{}}
    end 

    user.web_properties.each do |wp|
      account_id = web_property_id_to_account_id(wp.id)
      user_profiles[account_id]['properties'][wp.id] = {
                                              'name'=>wp.name, 'profiles'=>{}}
    end

    user.profiles.each do |p|
      account_id = web_property_id_to_account_id(p.web_property_id)
      user_profiles[account_id]['properties'][p.web_property_id]['profiles'][p.id.to_i] = {
                                                              'name'=>p.name}
    end

    return user_profiles
  end

  # The Legato class for getting the list of results to show in the graph.
  def graph_query
    settings.frequency == 'weekly' ? VisitByDate : VisitByHour
  end

  # Which Legato query do we use to get the Total Visits in this day/week?
  def total_visits_query
    settings.frequency == 'weekly' ? VisitByWeek : VisitByDate
  end

  # Which Legato query do we use to get the Total Visitors in this day/week?
  def total_visitors_query
    settings.frequency == 'weekly' ? VisitorByWeek : VisitorByDate
  end

  # Which Legato query do we use to get the Total Pageviews in this day/week?
  def total_pageviews_query
    settings.frequency == 'weekly' ? PageviewByWeek : PageviewByDate
  end
end


get %r{/(daily|weekly)/meta.json} do |frequency|
  set_frequency(frequency)
  content_type :json
  erb :meta
end


# The Edition - what will be printed for the user.
# 
# == Parameters
#   params[:access_token] will be the Google Analytics refresh_token.
#   params[:profiles] will be a space-separated list of Google Analytics
#     Profile IDs.
#   params[:local_delivery_time] An ISO 8601 timestamp of the printer's time.
# 
get %r{/(daily|weekly)/edition/} do |frequency|
  set_frequency(frequency)

  printer_date = Date.iso8601(params[:local_delivery_time])
  if frequency == 'weekly' && printer_date.cwday != settings.weekly_day 
    etag Digest::MD5.hexdigest(params[:access_token] + Date.today.strftime('%d%m%Y'))
    return 204, "No weekly Analytics are delivered on this day of the week."
  end

  # The Google API refresh_token will be sent in params[:access_token]
  # Use that to get a new access_token_obj.
  # TODO: Error checking.
  access_token_obj = OAuth2::AccessToken.from_hash(auth_client,
                              :refresh_token => params[:access_token]).refresh!
  # TODO: Error checking.
  user = Legato::User.new(access_token_obj)

  # Get an array of the Profiles that we have IDs in params[:profiles] for.
  # Which will be all of them, unless the user has deleted or been removed
  # from one since they subscribed.
  profiles = user.profiles.select{|p| params[:profiles].split(' ').include?(p.id)}

  # TODO: If profile is length==0, then display message to user?

  # Prepare the start/end dates and sorting.
  if settings.frequency == 'weekly'
    periods = [
      # Google Analytics weeks run Sunday-Saturday.
      # Last week (Sun-Sat).
      {:start => (printer_date - 7 - settings.weekly_day),
        :end => (printer_date - 1 - settings.weekly_day)},
      # The week before last (Sun-Sat).
      {:start => (printer_date - 14 - settings.weekly_day),
        :end => (printer_date - 8 - settings.weekly_day)}
    ] 
    sort = ['date', 'hour']
  else
    periods = [
      # Yesterday.
      {:start => (printer_date - 1),
        :end => (printer_date - 1)},
      # The same weekday as yesterday, but a week earlier.
      {:start => (printer_date - 8),
        :end => (printer_date - 8)}
    ]
    sort = ['hour']
  end

  # This is what we'll put all the data in for the template.
  # It'll contain one hash for each Profile.
  @profiles_data = []

  profiles.each do |profile|
    profile_data = {:name => profile.name,
                    :periods => []}

    # So we first gather the data for yesterday or last week.
    # Then we gather the data for the same day the previous week / the week before last.
    periods.each do |period|
      # The structure we fill with data for this period.
      period_data = {:visits => [],
                        :total_visits=> 0, :total_visitors=> 0,
                        :total_pageviews => 0} 

      # Hourly or daily data for the graph.
      period_data[:visits] = graph_query.results(profile,
                                    :start_date => period[:start],
                                    :end_date => period[:end],
                                    :sort => sort)

      period_data[:total_visits] = total_visits_query.results(profile,
                                    :start_date => period[:start],
                                    :end_date => period[:end]
                                    ).first.visits

      period_data[:total_visitors] = total_visitors_query.results(profile,
                                    :start_date => period[:start],
                                    :end_date => period[:end]
                                    ).first.visitors

      period_data[:total_pageviews] = total_pageviews_query.results(profile,
                                    :start_date => period[:start],
                                    :end_date => period[:end]
                                    ).first.pageviews

      profile_data[:periods].push(period_data)
    end
    @profiles_data.push(profile_data)
  end

  erb :publication
end


# == Parameters
#   params['return_url'] will be the publication-specific URL we return the
#     user to after authenticating.
#
get %r{/(daily|weekly)/configure/} do |frequency|
  set_frequency(frequency)
  return 400, 'No return_url parameter was provided' if !params['return_url']

  # Save the return URL so we still have it after authentication.
  session[:bergcloud_return_url] = params['return_url']

  begin
    redirect auth_client.auth_code.authorize_url(
      :scope => 'https://www.googleapis.com/auth/analytics.readonly',
      :redirect_uri => url("/#{settings.frequency}/return/"),
      :access_type => 'offline',
      :approval_prompt => 'force'
    )
  end
end


# Return from Google having authenticated (hopefully).
# We can now get the access_token and refresh_token from Google.
# Then we can let the user select which of their Profiles (if more than one)
# that they want to use.
get %r{/(daily|weekly)/return/} do |frequency|
  set_frequency(frequency)

  return 500, "No access token was returned by Google" if !params[:code]

  access_token_obj = auth_client.auth_code.get_token(params[:code], {
                      :redirect_uri => url("/#{settings.frequency}/return/"),
                      :token_method => :post
                    })
  # TODO: Error checking.
  user = Legato::User.new(access_token_obj)

  if user.profiles.length == 1
    # If the user only has one Profile, no need for any config. We use that.
    # The refresh_token is used in future to get another access_token for the
    # same user. So this is what we send back to bergcloud.com.
    redirect "#{session[:bergcloud_return_url]}?config[access_token]=#{access_token_obj.refresh_token}&config[profiles]=#{user.profiles.first.id}"
  else
    session[:refresh_token] = access_token_obj.refresh_token
    session[:access_token] = access_token_obj.token
    redirect url("/#{settings.frequency}/local_config/")
  end
end


# Display the form for choosing which Analytics Profile(s) to use.
get %r{/(daily|weekly)/local_config/} do |frequency|
  set_frequency(frequency)

  # TODO: Error checking.
  # If access_token has expired, try session[:refresh_token]?
  access_token_obj = OAuth2::AccessToken.new(
                                          auth_client, session[:access_token])

  # TODO: Error checking.
  user = Legato::User.new(access_token_obj)
  @accounts_properties_profiles = get_profiles(user)
  @form_error = session[:form_error]
  session[:form_error] = nil
  erb :local_config
end


# The user has come here after submitting the form for selecting one or more
# Google Analytics profiles.
# If they have chosen one or more, then we can return them to bergcloud.com
post %r{/(daily|weekly)/local_config/} do |frequency|
  set_frequency(frequency)

  if params[:profiles] && params[:profiles].length
    # The user selected some profile(s).

    # TODO: Check the Profile IDs are valid.
    # TODO: Check we have the refresh token still.
    redirect "#{session[:bergcloud_return_url]}?config[access_token]=#{session[:refresh_token]}&config[profiles]=#{params[:profiles].join('+')}"
  else
    # No profiles submitted. Re-show form.
    session[:form_error] = "Plesae select a Profile"
    redirect url("/#{settings.frequency}/local_config/")
  end
end


get %r{/(daily|weekly)/sample/} do |frequency|
  set_frequency(frequency)
  erb :publication
end


get %r{/(daily|weekly)/validate_config/} do |frequency|
  set_frequency(frequency)
end
