# t/010_timesheets.t
use strict;
use warnings;

use TalApi;
use Test::More tests => 2;
use Plack::Test;
use HTTP::Request::Common;
use JSON::MaybeXS;


my $app = TalApi->to_app;
is( ref $app, 'CODE', 'Got app' );

my $test = Plack::Test->create($app);

my ($res, $dec);

#my $res  = $test->request( GET '/timesheets/pending' );
#ok( $res->is_success, '[GET /timesheets/pending] successful' );

#my $res  = $test->request( GET '/timesheets/history' );
#ok( $res->is_success, '[GET /timesheets/history] successful' );
#print explain decode_json $res->content;
##diag explain decode_json $res->content;

# field = value
$res  = $test->request( GET '/timesheets/history?tp_week_no=21' );
ok( $res->is_success, '[GET /timesheets/history?tp_week_no=21] successful' );
#print explain decode_json $res->content;
$dec = decode_json $res->content;
is $dec->{status}, "0", "status 0";
is_deeply $dec->{pagination}, { currentPage => 1, hasMoreItems => "", perPage => 5, total => 1, pages => 0 }, 'pagination';
is $dec->{data}->[0]->{tp_timesheet_no}, 41, 'tp_timesheet_no';
is $dec->{data}->[0]->{oa_assignment}, "Managing Director", 'oa_assignment';
is $dec->{data}->[0]->{oa_booking_no}, "25078004", 'oa_booking_no';
is $dec->{data}->[0]->{cu_name}, 'Dillon Enterprises', 'cu_name';
is $dec->{data}->[0]->{tp_week_no}, 21, 'tp_week_no';
#is_deeply $dec->{data}->[0]->{tp_json_entry}, {}, 'tp_json_entry';
is $dec->{data}->[0]->{tp_json_entry}->{week_date}, '25082017', 'tp_json_entry.week_date';


#print explain $dec;

# field IN value set
#my $res  = $test->request( GET '/timesheets/history?tp_week_no=21,22' );
#ok( $res->is_success, '[GET /timesheets/history?tp_week_no=21] successful' );
#print explain decode_json $res->content;

#my $res  = $test->request( GET '/timesheets/history?tp_week_no=21,22' );
#ok( $res->is_success, '[GET /timesheets/history?tp_week_no=21] successful' );
#print explain decode_json $res->content;





#$dec = decode_json $res->content;
#is( $dec->{jb_client_ref}, "  AVL-2374-260", 'jb_client_ref');

#is_deeply( decode_json($res->content),
#   { status => 401, title => 'Error 401 - Unauthorized', message => 'Unauthorized' },
#   'status 401 message Unauthorized title Error 401 - Unauthorized' )
#      or diag explain $res->content;
