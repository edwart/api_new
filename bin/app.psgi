#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib ( "$FindBin::Bin/../lib",
	"$FindBin::Bin/../perl5lib",
	);

#use Carp::Always;
use Plack::Builder;
use Plack::Middleware::CrossOrigin;
use Dancer2::Debugger;
use TalApi;
builder {
    enable 'CrossOrigin', origins => '*';
    mount "/" => TalApi->to_app;
};

#TalApi->to_app;
