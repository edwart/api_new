#!/usr/bin/env perl

use JSON::DWIW;
use YAML qw/Dump/;
use Data::Dumper;

my $file = shift;
my $json_obj = JSON::DWIW->new();

my $data =  $json_obj->from_json_file($file) or die $!;
print Dump $data;
