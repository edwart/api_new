# tal-api
Beacon Talisman API

To install

$ git clone git@github.com:Beacon-Talisman/tal-api.git
$ cd tal-api
$ cpanm -S --installdeps .
$ perl Makefile.PL
$ make test

To run in development environment

$ plackup bin/app.psgi
(defaults to listening at localhost port 5000

To run in staging environment
$ ./run-talapi.sh
Plack logs requests to plack.access.log
Dancer2 logs to logs/staging.log

To test endpoint

$ curl -X GET http://localhost:5000/
$ curl -X GET http://localhost:5000/api/v1

To run unit tests

$  PLACK_ENV=test make test

one test
$ PLACK_ENV=test prove -Ilib t/003_v1_poc.t

Development testing

$ PLACK_ENV=test PERL5LIB=lib perl t/003_v1_poc.t
$ PLACK_ENV=development PERL5LIB=lib perl t/003_v1_poc.t

with debugger
$ PLACK_ENV=test PERL5LIB=lib perl -d t/003_v1_poc.t

to see SQL statements
$ DBI_TRACE=2 PLACK_ENV=test PERL5LIB=lib perl t/003_v1_poc.t
