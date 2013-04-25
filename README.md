
# Google Analytics - A Little Printer publication

In progress.

Useful: https://gist.github.com/jotto/2932998  
https://github.com/tpitale/legato/wiki/
https://www.ewanheming.com/2013/02/ppc-software-development/selecting-a-google-analytics-api-profile-id
http://ga-dev-tools.appspot.com/explorer/


## Setting up

Assuming you're familiar with the [guide to creating a publication](http://remote.bergcloud.com/developers/reference)...

1. Set the environment variable `RACK_ENV` to either `production` or `development`.

2. Go to https://code.google.com/apis/console#access and create a new Project. In "Settings" turn "Analytics API" on. In "API Access", create an OAuth 2.0 client ID.

3. Set the "Redirect URIs" to be like:

    http://your-app-name.herokuapp.com/daily/return/
    http://your-app-name.herokuapp.com/weekly/return/

Depending on where the publication is hosted. eg, replace `your-app-name.herokuapp.com` with `localhost` if running locally. 

4. Set two environment variables for your app, using the Google API Project's Client ID and Client secret: `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`.

So, your four environment variables will be:

    RACK_ENV
    GOOGLE_CLIENT_ID
    GOOGLE_CLIENT_SECRET

Run locally with:

    $ bundle exec ruby publication.rb

or, if you require a specific port, maybe for use with something like [localtunnel](http://progrium.com/localtunnel/):

    $ bundle exec ruby publication.rb -p 5000
