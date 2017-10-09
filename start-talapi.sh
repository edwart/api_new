#!/usr/bin/bash


DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "dir is $DIR"
port=`cat $DIR/PORT`
workers=10
while getopts "p:w:" arg; do
  case $arg in
    p) port=$OPTARG ;;
    w) workers=$OPTARG ;;
    *) echo "Eh?";;
  esac
done
echo "PORT=$port"
mkdir -p logs
> logs/server.log
echo start_server --port=$port --daemonize --log-file=$DIR/logs/server.log --status-file=$DIR/logs/server.status --pid-file=$DIR/logs/server.pid -- /usr/local/bin/plackup -p $port -s Starman bin/app.psgi --workers=$workers
start_server --port=$port --daemonize --log-file=$DIR/logs/server.log --status-file=$DIR/logs/server.status --pid-file=$DIR/logs/server.pid -- /usr/local/bin/plackup -p $port -s Starman bin/app.psgi --workers=$workers

