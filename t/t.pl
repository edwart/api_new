use strict;
use warnings;

BEGIN {
	# $ENV{PLACK_ENV} ||= 'development';
	$ENV{PLACK_ENV} ||= 'test';
	use lib 'lib';
	# $ENV{DBI_TRACE} = '2'; # for database tracing
}

use TalApi;
use TalApi::V1;
use Test::More tests => 3;
use Plack::Test;
use HTTP::Request::Common;
use JSON::MaybeXS;
use Test::utf8;
use Encode;
use utf8;
use Date::Calc qw( Add_Delta_Days Today );
use MIME::Base64;

my $app = TalApi::V1->to_app;
is( ref $app, 'CODE', 'Got TalApi::V1 app' );

my $test = Plack::Test->create($app);

my @auth_header = ( 'Authorization', 'Basic ' . encode_base64( 'tal:test' ) );

#my $res = $test->request( GET '/openJobs' );#, Authorization => 'Basic dGFsOnRlc3Q=' );

# my $res = $test->request( GET '/openJobs' );
#ok( $res->is_success, '[API v1 GET /openJobs] successful' );
#diag explain $res->content;

# my $res = $test->request( GET '/job/10110' );
# ok( $res->is_success, '[API v1 GET /job/10110] successful' );
# diag explain $res->content;

 # my $keyapps_userid1 = '6d4a1a52-b541-46ed-b7d9-2cfdc40b65b1';
 # my $cand_email1 = 'nathanmccallum@yahoo.com';
 # my $available_from_date = sprintf '%04d-%02d-%02d', Add_Delta_Days( Today(), 5 ); # format "2016-11-29" RFC 3339
 # my $request = sprintf '/candidateAvailability/%s/%s/%s', $keyapps_userid1, $cand_email1, $available_from_date;
 # my $res = $test->request( POST $request, @auth_header );
 # ok( $res->is_success, '[API v1 POST '.$request.'] successful' );
 # # is_deeply( decode_json($res->content), {message => 'OK'}, 'response: {"message":"OK"}');
 # is( $res->content, '{"count":1,"message":"OK"}', 'response content: {"count":1,"message":"OK"}');

my $res = $test->request( GET '/openJobs', @auth_header );
ok( $res->is_success, '[API v1 GET /openJobs] successful' );
is_deeply( decode_json($res->content),
	[10102,10107,10108,10109,10110,10111,10112,10113],
	'job no list as expected' ) or diag explain "got:", $res->content;

# SELECT jb_job_no FROM job WHERE jb_job_status in ("Open","Standing", "Urgent", "Unfilled")
# AND jb_date_active <= 2016-12-05 AND jb_date_closed < '1901-01-01' AND jb_start_date >= 2016-12-05
# ORDER BY jb_job_no;

# SELECT jb_job_no, jb_job_status, jb_date_active, jb_date_closed, jb_start_date FROM job WHERE jb_job_status in ("Open","Standing", "Urgent", "Unfilled")
# AND jb_date_active <= "2016-12-05" AND jb_date_closed < "1901-01-01" AND jb_start_date >= "2016-12-05" ORDER BY jb_job_no;


