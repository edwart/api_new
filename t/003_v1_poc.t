use strict;
use warnings;

use TalApi;
use TalApi::V1;
use Test::More tests => 34;
use Plack::Test;
use HTTP::Request::Common;
use JSON::MaybeXS;
use Test::utf8;
use Encode;
use utf8;
use Date::Calc qw( Add_Delta_Days Today );
use MIME::Base64;
use Dancer2;

# HTTP basic auth header for user "tal" password "test" is
# 	Authorization: Basic #dGFsOnRlc3Q=
# The base64 string is encoded characters for "tal:test"
my @auth_header = (
	'Authorization',
	'Basic ' . encode_base64( config->{basic_auth_user} . ':' . config->{basic_auth_pass} )
	);

my $app = TalApi::V1->to_app;
is( ref $app, 'CODE', 'Got TalApi::V1 app' );

my $test = Plack::Test->create($app);
my $res  = $test->request( GET '/' );

ok( $res->is_success, '[API v1 GET /] successful' );
is( $res->status_line, '200 OK', 'status: 200 OK' );
is $res->content_type, 'application/json', 'content-type: application/json';
# is( $res->header('content-type'), 'application/json', 'content-type: application/json' );
# is $res->content_type_charset, 'UTF-8', 'charset: UTF-8';

my $dec = decode_json $res->content;
my $expected = JSON::MaybeXS::from_json('{"module_version":"0.1","tal_api":"v1","is_authenticated":0,"utf8_cyrillic":"cyrillic shcha Щ","auth_key":"","auth_user":"","utf8_symbols":" ⚒ ⚓ ⚔ ⚕ ⚖ ⚗ ⚘ ⚙"}');
is_deeply( $dec, $expected, 'got expected JSON body');

# check UTF8 characters come through encoded correctly
is( $dec->{utf8_cyrillic}, "cyrillic shcha \x{0429}", 'utf8_cyrillic' );
is( $dec->{utf8_symbols}, " ⚒ ⚓ ⚔ ⚕ ⚖ ⚗ ⚘ ⚙", 'utf8_symbols' );
is_sane_utf8($dec->{utf8_cyrillic});

# my $exp_cyrillic = "cyrillic shcha \x{0429}";
# my $exp_cyrillic_bytes = Encode::encode( 'utf-8', $exp_cyrillic );
# my $exp_symbols = " ⚒ ⚓ ⚔ ⚕ ⚖ ⚗ ⚘ ⚙";
# my $exp_symbols_bytes = Encode::encode( 'utf-8', $exp_symbols );
# is( Encode::encode_utf8( $got_cyrillic ), $exp_cyrillic_bytes, 'utf8 cyrillic' );
# is( Encode::encode_utf8( $got_symbols ), $exp_symbols_bytes, 'utf8 symbols' );

$res = $test->request( GET '/', @auth_header ); # GET '/', Authorization => 'Basic dGFsOnRlc3Q=' );
ok( $res->is_success, '[API v1 GET / with Authorization: Basic header] successful' );
$dec = decode_json $res->content;
is( $dec->{is_authenticated}, 1, 'is_authenticated true');

# post /candidateAvailability/{userId}/{candEmail}/{availableFromDate}
#   two sample fixture datbase candidates
#     cand_cand_no, cand_surname, cand_email, cand_external_id
#     139000|Mccallum|nathanmccallum@yahoo.com|6d4a1a52-b541-46ed-b7d9-2cfdc40b65b1
#     139001|Ojoi|ojoimail.ru|ffffffff-b541-46ed-b7d9-2cfdc40b65b2
my $keyapps_userid1 = '6d4a1a52-b541-46ed-b7d9-2cfdc40b65b1';
my $cand_email1 = 'nathanmccallum@yahoo.com';
my $available_from_date = sprintf '%04d-%02d-%02d', Add_Delta_Days( Today(), 5 ); # format "2016-11-29" RFC 3339
my $request = sprintf '/candidateAvailability/%s/%s/%s', $keyapps_userid1, $cand_email1, $available_from_date;
$res = $test->request( POST $request, @auth_header );
ok( $res->is_success, '[API v1 POST '.$request.'] successful' );
is( $res->content, '{"count":1,"message":"OK"}', 'response content: {"count":1,"message":"OK"}');

warn "TODO set date to not today for this cand";
$request = sprintf '/candidateAvailability/%s/%s/%s', 'ffffffff-b541-46ed-b7d9-2cfdc40b65b2', 'ojoimail.ru', $available_from_date;
$res = $test->request( POST $request, @auth_header );
ok( $res->is_success, '[API v1 POST '.$request.'] successful' );
is( $res->content, '{"count":1,"message":"OK"}', 'response content: {"count":1,"message":"OK"}');
warn "TODO check date is now updated in SQLite database";

$request = sprintf '/candidateAvailability/%s/%s/%s', $keyapps_userid1, 'wrong_email', $available_from_date;
$res = $test->request( POST $request, @auth_header );
is( $res->code, 404, '404 candidate not found');
$request = sprintf '/candidateAvailability/%s/%s/%s', 'wrong_userid', 'wrong_email', 'wrong_date';
$res = $test->request( POST $request, @auth_header );
is( $res->code, 400, '400 invalid ID supplied');
$request = sprintf '/candidateAvailability/%s/%s/%s', $keyapps_userid1, $cand_email1, 'wrong_date';
$res = $test->request( POST $request, @auth_header );
is( $res->code, 400, '400 invalid availableFromDate');

$request = sprintf '/candidateAvailability/%s/%s/%s', $keyapps_userid1, 'go boom!', $available_from_date;
$res = $test->request( POST $request, @auth_header );
ok( ! $res->is_success, 'not success when error' );
is_deeply( decode_json($res->content),
	{ status => 500, title => 'Error 500 - Internal Server Error', message => '{"message":"foo","code":1234}' },
	'error structure for invalid candidateAvailability' ) or diag explain $res->content;

# get /openJobs
$res = $test->request( GET '/openJobs', @auth_header );
ok( $res->is_success, '[API v1 GET /openJobs] successful' );
is_deeply( decode_json($res->content),
	[10102,10107,10108,10109,10110,10111,10112,10113,10125],
	'job no list as expected' ) or diag explain $res->content;

# get /job/{jobNo}:
$res = $test->request( GET '/job/10110', @auth_header );
ok( $res->is_success, '[API v1 GET /job/10110] successful' );
$dec = decode_json $res->content;
is( $dec->{jb_client_ref}, "  AVL-2374-260", 'jb_client_ref');
is( $dec->{jb_desc}, "DUCT MATE", 'jb_desc');
is( $dec->{jb_rate_code__1}, "503", 'jb_rate_code__1') or diag explain $res->content;

$res = $test->request( GET '/job/9999999999', @auth_header );
is( $res->code, 404, '404 job not found');

$res = $test->request( GET '/job/go boom!', @auth_header );
ok( ! $res->is_success, 'not success when error' );
is_deeply( decode_json($res->content),
	{ status => 500, title => 'Error 500 - Internal Server Error', message => '{"message":"foo","code":1234}' },
	'error structure for invalid job' );


# make sure all protected paths have authentication check
$res = $test->request( GET '/job/1' );
ok( ! $res->is_success, 'No authentication, returns not success' );
is( $res->code, 401, 'code 401 when no auth' );
is_deeply( decode_json($res->content),
	{ status => 401, title => 'Error 401 - Unauthorized', message => 'Unauthorized' },
	'status 401 message Unauthorized title Error 401 - Unauthorized' )
		or diag explain $res->content;
for (
		( GET '/openJobs' 							),
		( GET '/job/1' 								),
		( POST '/candidateAvailability/foo/bar/baz' ),
	)
	{
		$res = $test->request( $_ );
		# is ( $res->code, 401, join(' ', '401 for '. $_->uri) );
		is ( decode_json($res->content)->{message}, 'Unauthorized', 'Unauthorized '. $_->uri);
	}
