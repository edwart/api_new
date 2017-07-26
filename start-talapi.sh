#!/bin/sh

#--env development
#--env production
#--daemonize
port=4000
> logs/server.log
start_server --port=$port --daemonize --log-file=logs/server.log --status-file=logs/server.status --pid-file=logs/server.pid -- /usr/local/bin/plackup -p $port -s Starman bin/app.psgi

