# coding: utf-8
require 'legato'
require 'oauth2'
require 'sinatra'
require 'redis'

client = OAuth2::Client.new(
  ENV['GOOGLE_CLIENT_ID'], ENV['GOOGLE_CLIENT_SECRET'], {
  :authorize_url => 'https://accounts.google.com/o/oauth2/auth',
  :token_url => 'https://accounts.google.com/o/oauth2/token'
})

configure do
  if settings.production?
    uri = URI.parse(ENV['REDISCLOUD_URL'])
    REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  else
    REDIS = Redis.new()
  end

  if settings.development?
    # So we can see what's going wrong on Heroku.
    set :show_exceptions, true
  end

  # The different periods we can display results for.
  # The periods should be options within the URL route matching for each
  # endpoint, eg:
  #   get %r{/(daily|weekly)/edition/} do |period|
  set :valid_periods, ['daily', 'weekly']

  # The default, which can be changed depending on URL.
  set :period, 'daily'
end

helpers do
  # So we know where to do redirects to.
  # Example return: 'http://my-app-name.herokuapp.com'
  # Should handle http/https and port numbers.
  def domain
    protocol = request.secure? ? 'https' : 'http'
    port = request.env['SERVER_PORT'] ? ":#{request.env['SERVER_PORT']}" : ''
    return "#{protocol}://#{request.env['SERVER_NAME']}#{port}"
  end

  # Set the `period` setting to `period` if it's valid. Else, ignore.
  def set_period(period)
    settings.period = period if settings.valid_periods.include?(period)
  end
end

get %r{/(daily|weekly)/meta.json} do |period|
  set_period(period)
  content_type :json
  erb :meta
end

get %r{/(daily|weekly)/edition/} do |period|
  set_period(period)
  erb :publication
end

get %r{/(daily|weekly)/configure/} do |period|
  set_period(period)
end

get %r{/(daily|weekly)/return/} do |period|
  set_period(period)
end

get %r{/(daily|weekly)/sample/} do |period|
  set_period(period)
  erb :publication
end

get %r{/(daily|weekly)/validate_config/} do |period|
  set_period(period)
end
