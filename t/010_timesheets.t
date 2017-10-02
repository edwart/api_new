# t/010_timesheets.t
use strict;
use warnings;

use TalApi;
use Test::More tests => 50;
use Plack::Test;
use HTTP::Request::Common;
use JSON::MaybeXS;

my $app = TalApi->to_app;
is( ref $app, 'CODE', 'Got app' );

my $test = Plack::Test->create($app);

my ($res, $dec);


$res  = $test->request( GET '/timesheets/pending' );
ok( $res->is_success, '[GET /timesheets/pending] successful' );
# print explain decode_json $res->content;
$dec = decode_json $res->content;
is $dec->{status}, "0", "status 0";
is_deeply $dec->{pagination}, { currentPage => 1, hasMoreItems => "0", perPage => 37, total => 37, pages => 1 }, 'pagination';
is scalar @{$dec->{data}}, 37, 'data record count';
is $dec->{pagination}->{total}, scalar @{$dec->{data}}, 'pagination total matches data record count';
is_deeply $dec->{data}->[0],
    {
      'cu_name' => 'Dillon Enterprises',
      'oa_assignment' => 'Managing Director',
      'oa_booking_no' => '25078004',
      'tp_extranet_status' => undef,
      'tp_week_date' => '2017-01-06'
    },
    '{data}->[0] first record fields as expected'
    or diag explain 'record: ', $dec->{data}->[0];


$res  = $test->request( GET '/timesheets/history' );
ok( $res->is_success, '[GET /timesheets/history] successful' );
$dec = decode_json $res->content;
is_deeply $dec->{pagination}, { currentPage => 1, hasMoreItems => "", perPage => 5, total => 5, pages => 1 }, 'pagination';
is $dec->{pagination}->{total}, scalar @{$dec->{data}}, 'pagination total matches data record count';


note 'SQL field = value';
$res  = $test->request( GET '/timesheets/history?tp_week_no=21' );
ok( $res->is_success, '[GET /timesheets/history?tp_week_no=21] successful' );
$dec = decode_json $res->content;
is $dec->{status}, "0", "status 0";
is_deeply $dec->{pagination}, { currentPage => 1, hasMoreItems => "", perPage => 5, total => 1, pages => 0 }, 'pagination';
is $dec->{data}->[0]->{tp_timesheet_no}, 41, 'tp_timesheet_no';
is $dec->{data}->[0]->{oa_assignment}, "Managing Director", 'oa_assignment';
is $dec->{data}->[0]->{oa_booking_no}, "25078004", 'oa_booking_no';
is $dec->{data}->[0]->{cu_name}, 'Dillon Enterprises', 'cu_name';
is $dec->{data}->[0]->{tp_week_no}, 21, 'tp_week_no';
is $dec->{data}->[0]->{tp_json_entry}->{week_date}, '25082017', 'tp_json_entry.week_date';
is_deeply $dec->{data}->[0]->{tp_json_entry},
	decode_json '{"week_date":"25082017","allowed_rates":[{"hours":35,"pay_rate":20,"payrate_no":1,"rate_desc":"Standard Hours","inv_amt":20,"pay_amt":20,"rate_invoice":20,"pay_type":"hours","ignore_hours":2},{"hours":35,"pay_type":"hours","ignore_hours":2,"payrate_no":2,"rate_desc":"Overtime","inv_amt":21,"pay_amt":21},{"hours":35,"pay_rate":21,"payrate_no":3,"rate_desc":"Lunch allowance","inv_amt":20,"pay_amt":20,"rate_invoice":21,"pay_type":"units","ignore_hours":2},{"hours":35,"pay_rate":21,"payrate_no":4,"rate_desc":"Day","inv_amt":20,"pay_amt":20,"rate_invoice":21,"pay_type":"days","ignore_hours":2}],"days":[{"rates":[{"quantity":0,"code":1},{"quantity":0,"code":2},{"quantity":0,"code":3},{"quantity":0,"code":4}],"date":"19082017"},{"rates":[{"quantity":0,"code":1},{"quantity":4,"code":2},{"quantity":1,"code":3},{"quantity":0,"code":4}],"date":"20082017"},{"rates":[{"quantity":7.5,"code":1},{"quantity":0,"code":2},{"quantity":1,"code":3},{"quantity":0,"code":4}],"date":"21082017"},{"rates":[{"quantity":7.5,"code":1},{"quantity":0,"code":2},{"quantity":1,"code":3},{"quantity":0,"code":4}],"date":"22082017"},{"rates":[{"quantity":7.5,"code":1},{"quantity":0,"code":2},{"quantity":1,"code":3},{"quantity":0,"code":4}],"date":"23082017"},{"rates":[{"quantity":7.5,"code":1},{"quantity":0,"code":2},{"quantity":1,"code":3},{"quantity":0,"code":4}],"date":"24082017"},{"rates":[{"quantity":7.5,"code":1},{"quantity":0,"code":2},{"quantity":1,"code":3},{"quantity":0,"code":4}],"date":"25082017"}]}',
	'tp_json_entry';
	# got this string with: print explain $res->content;  and picking out the tp_json_entry block


note 'SQL greater equal than INTEGER';
$res = $test->request( GET '/timesheets/history?tp_week_no=>=24' );
ok( $res->is_success, '[GET /timesheets/history?tp_week_no=>=24] successful' );
$dec = decode_json $res->content;
# print explain decode_json $res->content;
is_deeply $dec->{pagination}, { currentPage => 1, hasMoreItems => '', perPage => 5, total => 2, pages => 0 }, 'pagination'
  or diag explain $dec->{pagination};
for ( map { $_->{tp_week_no} } @{ $dec->{data} } )
{
	ok $_ >= 24, 'data[] tp_week_no >= 24'
	  or diag explain 'got ', $_;
}

note 'SQL greater than INTEGER';
$res = $test->request( GET '/timesheets/history?tp_week_no=>24' );
ok( $res->is_success, '[GET /timesheets/history?tp_week_no=>24] successful' );
$dec = decode_json $res->content;
is_deeply $dec->{pagination}, { currentPage => 1, hasMoreItems => '', perPage => 5, total => 1, pages => 0 }, 'pagination'
  or diag explain $dec->{pagination};
ok $dec->{data}->[0]->{tp_week_no} > 24, 'tp_week_no > 24'
  or diag explain 'got ', $dec->{data}->[0]->{tp_week_no};

note 'SQL lesser than INTEGER';
$res = $test->request( GET '/timesheets/history?tp_week_no=<24' );
ok( $res->is_success, '[GET /timesheets/history?tp_week_no=<24] successful' );
$dec = decode_json $res->content;
is_deeply $dec->{pagination}, { currentPage => 1, hasMoreItems => '', perPage => 5, total => 3, pages => 0 }, 'pagination'
  or diag explain $dec->{pagination};
for ( @{ $dec->{data} } )
{
	ok $_->{tp_week_no} < 24, 'data tp_week_no '.$_->{tp_week_no}.' < 24'
	  or diag explain 'got ', $_;
}

note 'SQL lesser equal than INTEGER';
$res = $test->request( GET '/timesheets/history?tp_week_no=<=24' );
ok( $res->is_success, '[GET /timesheets/history?tp_week_no=<=24] successful' );
$dec = decode_json $res->content;
is_deeply $dec->{pagination}, { currentPage => 1, hasMoreItems => '', perPage => 5, total => 4, pages => 0 }, 'pagination'
  or diag explain $dec->{pagination};
for ( @{ $dec->{data} } )
{
	ok $_->{tp_week_no} <= 24, 'data tp_week_no '.$_->{tp_week_no}.' <= 24'
	  or diag explain 'got ', $_;
}


note 'SQL greater than DATE';
$res = $test->request( GET '/timesheets/history?tp_week_date=>2017-09-21' );
ok( $res->is_success, '[GET /timesheets/history?tp_week_date=>2017-09-21] successful' );
$dec = decode_json $res->content;
is_deeply $dec->{pagination}, { currentPage => 1, hasMoreItems => '', perPage => 5, total => 1, pages => 0 }, 'pagination'
  or diag explain $dec->{pagination};
is $dec->{data}->[0]->{tp_week_date}, '2017-09-22', 'tp_week_date'
  or diag explain 'got ', $dec->{data}->[0]->{tp_week_date};


note 'SQL DATE range';
$res = $test->request( GET '/timesheets/history?tp_week_date=>=2017-09-01&tp_week_date=<=2017-09-15' );
ok( $res->is_success, '[GET /timesheets/history?tp_week_date=>=2017-09-01&tp_week_date=<=2017-09-15] successful' );
$dec = decode_json $res->content;
is_deeply $dec->{pagination}, { currentPage => 1, hasMoreItems => '', perPage => 5, total => 3, pages => 0 }, 'pagination'
  or diag explain $dec->{pagination};
is $dec->{data}->[0]->{tp_week_date}, '2017-09-01', 'tp_week_date';
is $dec->{data}->[1]->{tp_week_date}, '2017-09-08', 'tp_week_date';
is $dec->{data}->[2]->{tp_week_date}, '2017-09-15', 'tp_week_date';
# for ( @{ $dec->{data} } )
# {
# 	diag 'tp_week_no ', $_->{tp_week_no}, ' tp_week_date ', $_->{tp_week_date};
# }


note 'SQL field IN value set';
$res  = $test->request( GET '/timesheets/history?tp_week_no=21,22' );
$dec = decode_json $res->content;
ok( $res->is_success, '[GET /timesheets/history?tp_week_no=21,22] successful' );
is_deeply $dec->{pagination}, { currentPage => 1, hasMoreItems => '', perPage => 5, total => 2, pages => 0 }, 'pagination'
  or diag explain $dec->{pagination}; #print explain decode_json $res->content;
is $dec->{data}->[0]->{tp_week_no}, 21, 'record 0 tp_week_no 21';
is $dec->{data}->[1]->{tp_week_no}, 22, 'record 1 tp_week_no 22';


