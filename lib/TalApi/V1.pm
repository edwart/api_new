package TalApi::V1;
use Dancer2;

our $VERSION = '0.1';

# use Dancer2::Plugin::Auth::Extensible;
# use Dancer2::Plugin::Auth::HTTP::Basic::DWIW;

use Dancer2::Debugger;
use MIME::Base64;
use Encode;

set serializer => 'JSON';

hook before_serializer => sub {
    response_header 'Content-Language', 'en';
};

#sub auth_key { request_header 'talapi-key' }; # if passed as a API header key
sub _auth_key {
    # if passed as HTTP basic authentication https://en.wikipedia.org/wiki/Basic_access_authentication
    return request_header 'authorization'
};

=head2 is_authenticated

Is the session authenticated

Returns bool true if authenticated, else false.

=cut

sub is_authenticated {
    set auth_realm => '';
    set auth_user => '';

    my $header = _auth_key() || return 0;

    my ($auth_method, $auth_string) = split(' ', $header);
    return 0 unless $auth_method eq 'Basic' && length $auth_string;
    set auth_realm  => 'Basic';
    # die \400 unless $auth_method eq 'Basic';
    # || send_error("Unauthorized", 401);

    my ($username, $password) = split(':', decode_base64($auth_string));
    return 0 unless defined $username && defined $password;
    set auth_user   => $username;

    info auth_realm => setting 'auth_realm';
    info auth_user => $username;
    info auth_pass => $password;

    return check_user_pass(setting('auth_realm'), setting('auth_user'), $password);
}

=head2 check_user_pass

CHeck if username and password are valid.

Returns bool.

=cut

sub check_user_pass {
    my ($realm, $username, $password) = @_;

    return 1 if $username eq 'tal' && $password eq 'test';

    return 0;
}

=head2 http_basic_auth_check

Is the session authenticated using HTTP Basic authentication

=cut

sub http_basic_auth_check {
    return is_authenticated();
}

# REST methods start here

=head2 get /

Get Talisman API V1 debug information

=cut

get '/' => sub {
# returns  Talisman API version information

    debug "in V1 /";

    my $is_authenticated = http_basic_auth_check();

    set charset => 'utf-8';

    +{
        tal_api             => 'v1',
        module_version      => $VERSION,
        auth_user           => setting('auth_user'),
        is_authenticated    => $is_authenticated,
        auth_key            => _auth_key() // '',
        utf8_cyrillic       => "cyrillic shcha \x{0429}",
        utf8_symbols        => decode_utf8(" ⚒ ⚓ ⚔ ⚕ ⚖ ⚗ ⚘ ⚙"), # utf8 octets into perl characters
        # utf8_test           => encode_utf8(""), # "\x{F8FF}", # 
    };
};

# for development only
get '/candidates' => sub {

    debug "in V1 /candidates";

    send_error("Unauthorized", 401) unless http_basic_auth_check();

    +[
        {
            cand_cand_no    => 1,
            cand_surname    => 'Edwards',
            cand_forename   => 'Peter',
        },
        {
            cand_cand_no    => 2,
            cand_surname    => 'Watt',
            cand_forename   => 'Angus',
        },
    ];
};

post '/candidateAdd' => sub {
# input body #/definitions/newCandidate
# returns #/definitions/candidateQueueEntry

    debug "in V1 /candidateAdd";

    my $newcand;
    # model newCandidate
    # id: integer
    # username: string
    # email: string
    # salutation: string
    # firstName: string
    # middleNames: string
    # lastName: string
    # knownAs: string
    # mobilePhone: string
    # TODO use JSON Schema validator
    for ( qw( id username email salutation firstName middleNames lastName knownAs mobilePhone ) )
    {
        $newcand->{$_} = body_parameters->get($_)
            // send_error("missing parameter $_", 405);
    }

    # TODO write $newcand to Talisman newcandq table (like cvq)
    # my $schema = schema 'talisman';
    # my $cand_queue_no = $schema->resultset('newcandq')->insert( $newcand )
    #       || send_error('failed to insert new candidate to queue', 500);
    my $cand_queue_no = 1234;

    return +{
        cand_queue_no       => $cand_queue_no,
    };
};

post '/candidateAvailability/:candNo' => sub {
# input path candNo
# input body #/definitions/inputCandidateAvailability

    debug "in V1 /candidateAvailability";

    my $cand_no = route_parameters->get('candNo') || send_error('expected candNo', 400);


    return "";
};

get '/candidate/:candNo' => sub {
# input path candNo
# returns #/definitions/candidate

    my $cand_no = route_parameters->get('candNo') || send_error('expected candNo', 400);

    +{
        cand_cand_no        => 1,
        cand_surname        => 'Edwards',
    };
};

# future methods

post '/candidateCompliance/:candNo' => sub {
# input path candNo
# input body #/definitions/inputCandidateCompliance

    my $cand_no = route_parameters->get('candNo') || send_error('expected candNo', 400);

    return "";
};

true;

__END__

=head1 NAME

TalApi:V1 - version of Beacon Talisman API


=head1 VERSION

This document describes TalApi::V1 version 0.1


=head1 SYNOPSIS

    use TalApi::V1;

=cut
