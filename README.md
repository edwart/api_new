# tal-api
Beacon Talisman API

To install

$ git clone git@github.com:Beacon-Talisman/tal-api.git
$ cd tal-api
$ cpanm -S --installdeps .
$ perl Makefile.PL
$ make test

To run

$ plackup bin/app.psgi
(defaults to listening at localhost port 5000

To test

$ curl -X GET http://localhost:5000/
$ curl -X GET http://localhost:5000/api/v1
