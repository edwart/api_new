# t/010_timesheets.t
use strict;
use warnings;

use TalApi;
use Test::More tests => 2;
use Plack::Test;
use HTTP::Request::Common;

my $app = TalApi->to_app;
is( ref $app, 'CODE', 'Got app' );

my $test = Plack::Test->create($app);

my $res  = $test->request( GET '/timesheets/pending' );

ok( $res->is_success, '[GET /timesheets/pending] successful' );
