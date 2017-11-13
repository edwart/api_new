#!/usr/bin/bash
export PATH=$PWD/perl5lib/bin:$PATH
export PERL5LIB=$PWD/perl5lib/lib/perl5


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
echo start_server --port=$port --daemonize --log-file=$DIR/logs/server.log --status-file=$DIR/logs/server.status --pid-file=$DIR/logs/server.pid -- $PWD/perl5lib/bin/plackup -p $port -s Starman bin/app.psgi --workers=$workers
start_server --port=$port --daemonize --log-file=$DIR/logs/server.log --status-file=$DIR/logs/server.status --pid-file=$DIR/logs/server.pid -- $PWD/perl5lib/bin/plackup -p $port -s Starman bin/app.psgi --workers=$workers

