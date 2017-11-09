#!/usr/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

$DIR/stop-talapi.sh
DATE=`date +%Y%m%d_%H%M%S`
mv logs/server.log logs/server_${DATE}.log 
gzip logs/server_${DATE}.log
$DIR/start-talapi.sh "$@"
