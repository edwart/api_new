#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use TalApi;
use TalApi::V1;
use Plack::Builder;

builder {
	# top level website pages and RESTful routes independent of the API version
	mount '/'			=> TalApi->to_app;
	# version 1 of API
	mount '/api/v1'		=> TalApi::V1->to_app;
	# version 2 of API (not implemented yet, but ready for future versions)
	# mount '/api/v2'		=> TalApi::V2->to_app;
}
