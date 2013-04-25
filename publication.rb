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

  # The different periods we can display results for.
  # The periods should be options within the URL route matching for each
  # endpoint, eg:
  #   get %r{/(daily|weekly)/edition/} do |period|
  set :valid_periods, ['daily', 'weekly']

  # The default, which can be changed depending on URL.
  set :period, 'daily'
end


helpers do
  # Set the `period` setting to `period` if it's valid. Else, ignore.
  def set_period(period)
    settings.period = period if settings.valid_periods.include?(period)

    # Set the dimensions that we'll need Google Analytics data for.
    if settings.period == 'weekly'
      UniqueVisitor.dimensions(:date)
      Visit.dimensions(:date)

    else
      UniqueVisitor.dimensions(:date, :hour)
      Visit.dimensions(:date, :hour)

    end
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
end


get %r{/(daily|weekly)/meta.json} do |period|
  set_period(period)
  content_type :json
  erb :meta
end


# The Edition - what will be printed for the user.
# 
# == Parameters
#   params[:access_token] will be the Google Analytics refresh_token.
#   params[:profiles] will be a space-separated list of Google Analytics
#     Profile IDs.
# 
get %r{/(daily|weekly)/edition/} do |period|
  set_period(period)

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

  # This is what we'll put all the data in for the template.
  # It'll contain one hash for each Profile.
  @profiles_data = []


  # Calculate start_date
  # Calculate end_date
  # Set sort base on period.

  profiles.each do |profile|
    profile_data = {}
    # profile_data['visits'] = Visit.results(profile,
    #                                       :start_date => )

  end

  erb :publication
end


# == Parameters
#   params['return_url'] will be the publication-specific URL we return the
#     user to after authenticating.
#
get %r{/(daily|weekly)/configure/} do |period|
  set_period(period)
  return 400, 'No return_url parameter was provided' if !params['return_url']

  # Save the return URL so we still have it after authentication.
  session[:bergcloud_return_url] = params['return_url']

  begin
    redirect auth_client.auth_code.authorize_url(
      :scope => 'https://www.googleapis.com/auth/analytics.readonly',
      :redirect_uri => url("/#{settings.period}/return/"),
      :access_type => 'offline',
      :approval_prompt => 'force'
    )
  end
end


# Return from Google having authenticated (hopefully).
# We can now get the access_token and refresh_token from Google.
# Then we can let the user select which of their Profiles (if more than one)
# that they want to use.
get %r{/(daily|weekly)/return/} do |period|
  set_period(period)

  return 500, "No access token was returned by Google" if !params[:code]

  access_token_obj = auth_client.auth_code.get_token(params[:code], {
                      :redirect_uri => url("/#{settings.period}/return/"),
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
    redirect url("/#{settings.period}/local_config/")
  end
end


# Display the form for choosing which Analytics Profile(s) to use.
get %r{/(daily|weekly)/local_config/} do |period|
  set_period(period)

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
post %r{/(daily|weekly)/local_config/} do |period|
  set_period(period)

  if params[:profiles] && params[:profiles].length
    # The user selected some profile(s).

    # TODO: Check the Profile IDs are valid.
    # TODO: Check we have the refresh token still.
    redirect "#{session[:bergcloud_return_url]}?config[access_token]=#{session[:refresh_token]}&config[profiles]=#{params[:profiles].join('+')}"
  else
    # No profiles submitted. Re-show form.
    session[:form_error] = "Plesae select a Profile"
    redirect url("/#{settings.period}/local_config/")
  end
end


get %r{/(daily|weekly)/sample/} do |period|
  set_period(period)
  erb :publication
end


get %r{/(daily|weekly)/validate_config/} do |period|
  set_period(period)
end
