
# Google Analytics

## Summary

This is a Ruby + Sinatra app that generates two publications: a daily and a weekly version of similar data, pulled from a user's Google Analytics account.

The two endpoints are:

* http://your-domain/daily/
* http://your-domain/weekly/

The code is shared between the two, with some variations (in both the Ruby and JavaScript) depending on which of the publications is being viewed.

When a user subscribes, they must authenticate with their Google Analytics account. Once they've authenticated, our app presents them with a form listing all of their Google Analytics profiles, so they can choose which they want to appear in the Little Printer publication.

They are then returned to the BERG Cloud Remote site to choose the publication's delivery time. Nothing is stored locally, so no database is required.

See example publications:

* Daily: http://remote.bergcloud.com/publications/138
* Weekly: http://remote.bergcloud.com/publications/139


## Setting up

Assuming you're familiar with the [guide to creating a publication](http://remote.bergcloud.com/developers/reference)...

1. Set the environment variable `RACK_ENV` to either `production` or `development`.

2. Go to https://code.google.com/apis/console#access and create a new Project. In "Settings" turn "Analytics API" on. In "API Access", create an OAuth 2.0 client ID.

3. Set the "Redirect URIs" to both of these URIs:

        http://your-app-name.herokuapp.com/daily/return/  
        http://your-app-name.herokuapp.com/weekly/return/

    Depending on where the publication is hosted. eg, replace `your-app-name.herokuapp.com` with `localhost` if running locally. 

4. Set two environment variables for your app, using the Google API Project's Client ID and Client secret: `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`.

So, your three environment variables will be:

    RACK_ENV
    GOOGLE_CLIENT_ID
    GOOGLE_CLIENT_SECRET

Run locally with:

    $ bundle exec ruby publication.rb

or, if you require a specific port, maybe for use with something like [localtunnel](http://progrium.com/localtunnel/):

    $ bundle exec ruby publication.rb -p 5000


## Using this publication as an example

This publication is reasonably complicated, but demonstrates a few things:

* Publishing two (daily and weekly) publications from the same codebase.
* Authenticating a user with Google Analytics via OAuth 2.
* Presenting the user with a custom options form before returning them to the BERG Cloud Remote.
* Displaying JavaScript graphs in a publication using d3.

Some useful references for experimenting with this stuff:

* A Ruby script for generating OAuth tokens, making it easier to experiment in irb: https://gist.github.com/philgyford/5503279 
* Documentation for Legato, the Ruby gem we use to query Google Analytics:
https://github.com/tpitale/legato/wiki/
* An explanation of the structure of Google Analytics Accounts, Properties and Profiles: https://www.ewanheming.com/2013/02/ppc-software-development/selecting-a-google-analytics-api-profile-id
* An easy way to experiment with querying the Google Analytics API: http://ga-dev-tools.appspot.com/explorer/
* d3 <http://d3js.org/> is pretty baffling, but this publication's graph is partly based on this example, which you can experiment with: http://jsfiddle.net/dtkav/Jz6QG/ Most JavaScript charting libraries should work in publications, but you may have to embed the library's code in the page, rather than linking to it (to ensure it loads and runs before the page is rendered to an image).

----

BERG Cloud Developer documentation: http://remote.bergcloud.com/developers/

