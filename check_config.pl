#!/usr/bin/env perl

use JSON::Validator::OpenAPI;
use Data::Dumper;
my $file = shift;

my $val = JSON::Validator::OpenAPI->new;
my $spec = $val->load_and_validate_schema($file);
print Dumper $spec;
