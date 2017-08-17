#!/usr/bin/env perl

use JSON::Validator::OpenAPI;
use JSON::DWIW;
my $json_obj = JSON::DWIW->new({ pretty => 1});
my $data = $json_obj->from_json($json_str);

use JSON;
my $file = shift;
my $val = JSON::Validator::OpenAPI->new;
my $spec = $val->load_and_validate_schema($file);

print $json_obj->to_json($val->schema->data);
