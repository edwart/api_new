#!/bin/sh

#--env development
#--env production
#--daemonize
> logs/server.log
start_server --port=5000 --daemonize --log-file=logs/server.log --status-file=logs/server.status --pid-file=logs/server.pid -- /usr/local/bin/plackup -s Starman bin/app.psgi
#nohup plackup --server HTTP::Server::Simple --port 5000 --host 127.0.0.1 --env staging --access-log logs/plack.access.log bin/app.psgi &

