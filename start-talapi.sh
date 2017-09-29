#!/bin/sh


port=`cat PORT`
while getopts "p" arg; do
  case $arg in
    p)
      port=$OPTARG
      ;;
  esac
done
echo "PORT=$port"
mkdir -p logs
> logs/server.log
echo start_server --port=$port --daemonize --log-file=$PWD/logs/server.log --status-file=$PWD/logs/server.status --pid-file=$PWD/logs/server.pid -- /usr/local/bin/plackup -p $port -s Starman bin/app.psgi
start_server --port=$port --daemonize --log-file=$PWD/logs/server.log --status-file=$PWD/logs/server.status --pid-file=$PWD/logs/server.pid -- /usr/local/bin/plackup -p $port -s Starman bin/app.psgi --workers=20
