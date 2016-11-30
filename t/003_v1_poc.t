use strict;
use warnings;

use TalApi;
use TalApi::V1;
use Test::More tests => 22;
use Plack::Test;
use HTTP::Request::Common;
use JSON::MaybeXS;
use Test::utf8;
use Encode;
use utf8;
use Date::Calc qw( Add_Delta_Days Today );

my $app = TalApi::V1->to_app;
is( ref $app, 'CODE', 'Got TalApi::V1 app' );

my $test = Plack::Test->create($app);
my $res  = $test->request( GET '/' );

ok( $res->is_success, '[API v1 GET /] successful' );
is( $res->status_line, '200 OK', 'status: 200 OK' );
is $res->content_type, 'application/json', 'content-type: application/json';
# is( $res->header('content-type'), 'application/json', 'content-type: application/json' );
# is $res->content_type_charset, 'UTF-8', 'charset: UTF-8';

# is $res->content, Encode::encode( 'utf-8', "cyrillic shcha \x{0429}" );
# is $res->content, Encode::encode( 'utf-8', " ⚒ ⚓ ⚔ ⚕ ⚖ ⚗ ⚘ ⚙" );
#my $got = $res->content;
my $dec = decode_json $res->content;

my $expected = JSON::MaybeXS::from_json('{"module_version":"0.1","tal_api":"v1","is_authenticated":0,"utf8_cyrillic":"cyrillic shcha Щ","auth_key":"","auth_user":"","utf8_symbols":" ⚒ ⚓ ⚔ ⚕ ⚖ ⚗ ⚘ ⚙"}');
is_deeply( $dec, $expected, 'got expected JSON body');

# check UTF8 characters come through encoded correctly
is( $dec->{utf8_cyrillic}, "cyrillic shcha \x{0429}", 'utf8_cyrillic' );
is( $dec->{utf8_symbols}, " ⚒ ⚓ ⚔ ⚕ ⚖ ⚗ ⚘ ⚙", 'utf8_symbols' );
is_sane_utf8($dec->{utf8_cyrillic});

# is( $got_symbols, " ⚒ ⚓ ⚔ ⚕ ⚖ ⚗ ⚘ ⚙" );
# my $got_cyrillic = $dec->{utf8_cyrillic};
# my $got_symbols = $dec->{utf8_symbols};
# my $exp_cyrillic = "cyrillic shcha \x{0429}";
# my $exp_cyrillic_bytes = Encode::encode( 'utf-8', $exp_cyrillic );
# my $exp_symbols = " ⚒ ⚓ ⚔ ⚕ ⚖ ⚗ ⚘ ⚙";
# my $exp_symbols_bytes = Encode::encode( 'utf-8', $exp_symbols );
# is( Encode::encode_utf8( $got_cyrillic ), $exp_cyrillic_bytes, 'utf8 cyrillic' );
# is( Encode::encode_utf8( $got_symbols ), $exp_symbols_bytes, 'utf8 symbols' );
# is_sane_utf8($got_cyrillic);
# is( $got_cyrillic, "cyrillic shcha \x{0429}" );
# is( $got_symbols, " ⚒ ⚓ ⚔ ⚕ ⚖ ⚗ ⚘ ⚙" );

# post /candidateAvailability/{userId}/{candEmail}/{availableFromDate}
my $keyapps_userid = '6d4a1a52-b541-46ed-b7d9-2cfdc40b65b1';
my $cand_email = 'petere@beacon.co.uk';
my $available_from_date = sprintf '%04d-%02d-%02d', Add_Delta_Days( Today(), 5 ); # format "2016-11-29" RFC 3339
my $request = sprintf '/candidateAvailability/%s/%s/%s', $keyapps_userid, $cand_email, $available_from_date;
$res = $test->request( POST $request );
ok( $res->is_success, '[API v1 POST '.$request.'] successful' );
# is_deeply( decode_json($res->content), {message => 'OK'}, 'response: {"message":"OK"}');
is( $res->content, '{"message":"OK"}', 'response content: {"message":"OK"}');

$request = sprintf '/candidateAvailability/%s/%s/%s', $keyapps_userid, 'wrong_email', 'wrong_date';
$res = $test->request( POST $request );
is( $res->code, 404, '404 candidate not found');
$request = sprintf '/candidateAvailability/%s/%s/%s', 'wrong_userid', 'wrong_email', 'wrong_date';
$res = $test->request( POST $request );
is( $res->code, 400, '400 invalid ID supplied');
$request = sprintf '/candidateAvailability/%s/%s/%s', $keyapps_userid, $cand_email, 'wrong_date';
$res = $test->request( POST $request );
is( $res->code, 400, '400 invalid availableFromDate');

$request = sprintf '/candidateAvailability/%s/%s/%s', $keyapps_userid, 'go boom!', 'wrong_date';
$res = $test->request( POST $request );
ok( ! $res->is_success, 'not success when error' );
is_deeply( decode_json($res->content),
	{ status => 500, title => 'Error 500 - Internal Server Error', message => '{"message":"foo","code":1234}' },
	'error structure for invalid candidateAvailability' );

# get /openJobs
$res = $test->request( GET '/openJobs' );
ok( $res->is_success, '[API v1 GET /openJobs] successful' );
is_deeply( decode_json($res->content),
	[ 1, 3, 5 ],
	'job no list as expected' );


# get /job/{jobNo}:
$res = $test->request( GET '/job/1' );
ok( $res->is_success, '[API v1 GET /job/1] successful' );
# diag explain $res->content;
is_deeply( decode_json($res->content),
	{
		foo => 1,
	},
	'job 1 content as expected' ) or diag explain $res->content;
$res = $test->request( GET '/job/9999999999' );
is( $res->code, 404, '404 job not found');

$res = $test->request( GET '/job/go boom!' );
ok( ! $res->is_success, 'not success when error' );
is_deeply( decode_json($res->content),
	{ status => 500, title => 'Error 500 - Internal Server Error', message => '{"message":"foo","code":1234}' },
	'error structure for invalid job' );

# $res = $test->request( GET '/allJobs' );
# ok( $res->is_success, '[API v1 GET /allJobs] successful' );
# diag explain $res->content;


TODO: {
	local $TODO = "need to write tal-002 PoC methods";

}
