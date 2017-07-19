#!/bin/sh

#--env development
#--env production
#--daemonize
nohup plackup --server HTTP::Server::Simple --port 5001 --host 127.0.0.1 --env production --access-log /var/www/cgi-bin/tal-api/logs/plack-prod.access.log bin/app.psgi &

