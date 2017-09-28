#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
#use Carp::Always;
use lib "$FindBin::Bin/../lib";

use Plack::Builder;
use Plack::Middleware::CrossOrigin;
use Dancer2::Debugger;
use TalApi;
builder {
    enable 'CrossOrigin', origins => '*';
    mount "/" => TalApi->to_app;
};

#TalApi->to_app;
