#!/usr/bin/env perl

use JSON::DWIW;
use Data::Dumper;
my $json = shift;
my $json_obj = JSON::DWIW->new({ pretty => 1});
my $data = $json_obj->from_json_file($json) or die "JSON error: " . JSON::DWIW->get_error_string;
print Data::Dumper->Dump([ $data ], [ qw/$json /]);
