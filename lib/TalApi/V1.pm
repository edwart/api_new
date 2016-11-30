package TalApi::V1;
use Dancer2;

our $VERSION = '0.1';

# use Dancer2::Plugin::Auth::Extensible;
# use Dancer2::Plugin::Auth::HTTP::Basic::DWIW;

# use Dancer2::Debugger;
use MIME::Base64;
use Encode;
use Date::Calc qw( check_date Today Date_to_Days );
use Try::Tiny;
use Dancer2::Plugin::Database;

# our $schema = schema 'test';

sub _dbh { database( config->{dbname} ) }
# sub _dbh { database('test') }

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

    debug "V1 /";

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

post '/candidateAvailability/:userId/:candEmail/:availableFromDate' => sub {
# input path userId, candEmail, availableFromDate
# // input body #/definitions/inputCandidateAvailability

    debug "V1 /candidateAvailability";

    # e.g. 6d4a1a52-b541-46ed-b7d9-2cfdc40b65b1
    my $user_id = route_parameters->get('userId') || send_error('expected userId', 400);
    # e.g. petere@beacon.co.uk
    my $cand_email = route_parameters->get('candEmail') || send_error('expected candNo', 404);
    # format "2016-11-29" RFC 3339
    my $available_from_date = route_parameters->get('availableFromDate') || send_error('expected availableFromDate', 400);

    $user_id eq '6d4a1a52-b541-46ed-b7d9-2cfdc40b65b1' || send_error('invalid ID supplied',400);
    if ( $cand_email eq 'go boom!' ) {
        my $msg = encode_json({ code=>1234, message=>'foo' });
        send_error( $msg, 500 );
    }
    $cand_email eq 'petere@beacon.co.uk' || send_error('candidate not found', 404);
    # info "afd $available_from_date";
    my ($y,$m,$d) = ( $available_from_date =~ m/(\d{4})-(\d{2})-(\d{2})/ ) or send_error('invalid availableFromDate format',400);
    # info "y $y m $m d $d";
    check_date($y,$m,$d) || send_error("invalid availableFromDate value: $y-$m-$d",400);
    try {
        Date_to_Days($y,$m,$d) >= Date_to_Days(Today()) or send_error("invalid availableFromDate before today: $y-$m-$d",400);
    } catch {
        send_error("invalid availableFromDate: $_", 500);
    };

    warn "TODO: DBIC update cand_avail_date";

    return { message => 'OK' };
};

get '/openJobs' => sub {

    debug "V1 /openJobs";

    my $today = sprintf "%04d-%02d-%02d", Today();
    my $sql = <<EOM ;
SELECT
    jb_job_no
FROM
    job
WHERE
    jb_job_status in ("Open","Standing", "Urgent", "Unfilled")
AND jb_date_active <= ?
AND jb_date_closed < '1901-01-01'
AND jb_start_date >= ?
ORDER BY
    jb_job_no
EOM
    my $job_nos = _dbh()->selectcol_arrayref( $sql, undef, $today, $today );
    # info $job_nos;
    return $job_nos;

    # +[ 1, 3, 5 ];
};

# get 'allJobs' => sub {
#     # my $sth = $dbh->prepare();
#     # $sth->execute();
#     # my @jobs = $schema->resultset('job')->search(); # undef, { columns => [qw/ jb_job_no /] } );
#     # return \@jobs;
#     my $job_nos = _dbh()->selectcol_arrayref("select jb_job_no from job order by jb_job_no", undef);
#     return $job_nos;
# };

get '/job/:jobNo' => sub {

    debug "V1 /job";

    my $job_no = route_parameters->get('jobNo') || send_error('expected jobNo', 404);
    debug "job_no $job_no";
    if ( $job_no eq 'go boom!' ) {
        my $msg = encode_json({ code=>1234, message=>'foo' });
        send_error( $msg, 500 );
    }
    $job_no =~m/^\d+$/ or send_error("invalid jobNo not numeric: $job_no", 404);
    $job_no > 0 or send_error("invalid jobNo not > 0: $job_no", 404);
    # $job_no eq '9999999999' && send_error("job not found: $job_no", 404);

    my $sql = "SELECT * from job WHERE jb_job_no = ?";
    my $job = _dbh()->selectrow_hashref($sql, undef, $job_no);

    $job->{jb_job_no} || send_error("job not found: $job_no", 404);

    return $job;
    # +{
    #     foo             => '1',
    # };
};




# future methods

post '/candidateCompliance/:candNo' => sub {
# input path candNo
# input body #/definitions/inputCandidateCompliance

    return "TODO";

    my $cand_no = route_parameters->get('candNo') || send_error('expected candNo', 400);
};

# for development only
get '/candidates' => sub {

    return "TODO";

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


get '/candidate/:candNo' => sub {
# input path candNo
# returns #/definitions/candidate

    return "TODO";

    my $cand_no = route_parameters->get('candNo') || send_error('expected candNo', 400);

    +{
        cand_cand_no        => 1,
        cand_surname        => 'Edwards',
    };
};

post '/candidateAdd' => sub {
# input body #/definitions/newCandidate
# returns #/definitions/candidateQueueEntry

    return "TODO";

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



true;

__END__

=head1 NAME

TalApi:V1 - version of Beacon Talisman API


=head1 VERSION

This document describes TalApi::V1 version 0.1


=head1 SYNOPSIS

    use TalApi::V1;

=cut
