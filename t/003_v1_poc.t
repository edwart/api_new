use strict;
use warnings;

use TalApi;
use TalApi::V1;
use Test::More tests => 8;
use Plack::Test;
use HTTP::Request::Common;
use JSON::MaybeXS;
use Test::utf8;
use Encode;
use utf8;

my $app = TalApi::V1->to_app;
is( ref $app, 'CODE', 'Got app' );

my $test = Plack::Test->create($app);
my $res  = $test->request( GET '/' );

ok( $res->is_success, '[API v1 GET /] successful' );
is( $res->status_line, '200 OK', 'status: 200 OK' );
is $res->content_type, 'application/json', 'content-type: application/json';
# is( $res->header('content-type'), 'application/json', 'content-type: application/json' );
# is $res->content_type_charset, 'UTF-8', 'charset: UTF-8';

# is $res->content, Encode::encode( 'utf-8', "cyrillic shcha \x{0429}" );
# is $res->content, Encode::encode( 'utf-8', " ⚒ ⚓ ⚔ ⚕ ⚖ ⚗ ⚘ ⚙" );
my $got = $res->content;
my $dec = decode_json $res->content;
is( $dec->{utf8_cyrillic}, "cyrillic shcha \x{0429}", 'utf8_cyrillic' );
is( $dec->{utf8_symbols}, " ⚒ ⚓ ⚔ ⚕ ⚖ ⚗ ⚘ ⚙", 'utf8_symbols' );
is_sane_utf8($dec->{utf8_cyrillic});

my $exp = JSON::MaybeXS::from_json('{"module_version":"0.1","tal_api":"v1","is_authenticated":0,"utf8_cyrillic":"cyrillic shcha Щ","auth_key":"","auth_user":"","utf8_symbols":" ⚒ ⚓ ⚔ ⚕ ⚖ ⚗ ⚘ ⚙"}');
is_deeply( $dec, $exp, 'got expected JSON body');

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

