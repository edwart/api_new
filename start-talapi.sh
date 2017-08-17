#!/bin/sh

port=5000
mkdir -p logs
> logs/server.log
start_server --port=$port --daemonize --log-file=logs/server.log --status-file=logs/server.status --pid-file=logs/server.pid -- /usr/local/bin/plackup -p $port -s Starman bin/app.psgi

