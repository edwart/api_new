#!/usr/bin/env perl

use JSON::DWIW;
use Data::Dumper;
my $file = shift;
my $json_obj = JSON::DWIW->new({ pretty => 1, bare_solidus => 1});
my ($data, $error_msg) = $json_obj->from_json_file($file) or die "JSON error: $error_msg";
#print Dumper $data, $error_msg;
print $json_obj->to_json($data);
