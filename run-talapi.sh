#!/bin/sh

#--env development
#--env production
#--daemonize
plackup --server HTTP::Server::Simple --port 5000 --host 127.0.0.1 --env staging --access-log /var/www/cgi-bin/tal-api/plack.access.log bin/app.psgi &

