#!/bin/sh

port=5000
> logs/server.log
start_server --port=$port --daemonize --log-file=$PWD/logs/server.log --status-file=$PWD/logs/server.status --pid-file=$PWD/logs/server.pid -- /usr/local/bin/plackup -p $port -s Starman bin/app.psgi

