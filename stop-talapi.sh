port=5000
start_server --port=$port --stop --daemonize --log-file=logs/server.log --status-file=logs/server.status --pid-file=logs/server.pid -- /usr/local/bin/plackup -p $port -s Starman bin/app.psgi
