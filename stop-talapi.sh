port=5000
start_server --port=$port --stop --daemonize --log-file=$PWD/logs/server.log --status-file=$PWD/logs/server.status --pid-file=$PWD/logs/server.pid -- /usr/local/bin/plackup -p $port -s Starman bin/app.psgi
