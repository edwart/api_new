#!perl
#!perl -T

use Test::More;
#eval "use Test::Pod::Coverage 1.04";
eval "use Test::Pod::Coverage";
print "got $@\n";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage" if $@;
all_pod_coverage_ok();
