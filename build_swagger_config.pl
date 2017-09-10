#!/usr/bin/env perl

use strict;
use warnings;
use Data::Printer;
use Data::Dumper;
use DBI;
use Carp::Always;
use JSON::DWIW;
use JSON::Validator::OpenAPI;
use File::Temp qw/ tempfile tempdir /;
my $database = 'Talisman_APItest';
my $hostname = 'localhost';
my $port = 3306;
my $user = 'root';
my $password = 'gemini2';
my $dsn = "DBI:mysql:database=$database;host=$hostname;port=$port";
our $dbh = DBI->connect($dsn, $user, $password) or die DBI::errstr;
my %default_responses = ( 200 => { description => "success" },
                          default => { description => "unexpected error" },
                          );

our $api;
do 'config/api.pl' or die "can't do config/api.pl: $!";

p $api;
=pod
my %api = (
'/' => {
    get => {
        summary => 'Get Api Version Info',
        operationId => 'GetApiVersionInfo',
        responses => \%default_responses,
    },
},
'/openJobs' => {
    get => {
        summary => 'Get List of Open Jobs',
        operationId => 'GetOpenJobs',
        responses => \%default_responses,
    },
},
'/ratecodes' => {
    get => {
        summary => 'List Talisman rate codes',
        operationId => 'GetRateCodes',
        responses => \%default_responses,
    }
},
'/bookings' => {
    get => {
        summary => 'Returns bookings',
        operationId => 'GetBookings',
        responses => \%default_responses,
    }
},
'/booking/{bookingNo}/{workweekEndDate}' => {
    'get' => {
        summary => 'Returns rate codes, limits, pay rates for a booking, any existing timesheet detail record for that booking and workwkend',
        operationId => 'GetBookings',
        parameters => { bookingNo       => { sql => 'bookings.oa_booking_no', desc => "Booking Number" },
                        workweekEndDate => { sql => 'timesheet.th_paywkend', desc => "Date of week end" },
        responses => \%default_responses,
    },
},
);
=cut


my %tables = ();
my $config = { %{ $api } };

#delete $config->{paths};
p $api;
foreach my $path (keys %{ $api->{paths} }) {
    foreach my $method (keys %{ $api->{paths}->{$path} }) {
        my $cfg = $api->{paths}->{$path}{$method};
#        p $path, $method, $cfg;
        $api->{paths}{$path}{$method} = $cfg;
        if (exists($cfg->{parameters})) {
            my $params = process_parameters($cfg->{parameters}, \%tables);
            $config->{paths}{$path}{$method}{parameters} = $params;
        }
        my $responses = process_responses($cfg->{responses}, \%tables);
    }
}
p %tables;
get_column_info(\%tables, $config);
my $json_obj = JSON::DWIW->new({ pretty => 1, bare_solidus => 1, convert_bool => 1});
p  $config;
my $json = $json_obj->to_json( $config ) or die "JSON error: " . JSON::DWIW->get_error_string;

p $json;
$json =~ s!"(true|false)"!$1!g;
my $val = JSON::Validator::OpenAPI->new;
my ($fh, $filename) = tempfile( SUFFIX => '.json');
p $filename;
$fh->print($json);
$fh->close;
my $spec = $val->load_and_validate_schema($filename);
sub get_column_info {
    my ($tables, $config) = @_;
    my %conversion = ( date => { type   => 'string',
                                 pattern =>  '/^[1|2][0-9]{7,7}$/',
                                required => "true",
                                format  =>  'date',
                                 },
                       int => { type    => 'integer',
                                required => "true",
                                format  =>  'int32'},
                    );


    foreach my $table (sort keys %{ $tables }) {
        my $sql = qq!SELECT column_name, data_type, is_nullable, column_default
                     FROM INFORMATION_SCHEMA.COLUMNS 
                    WHERE table_name = '$table'
                    AND column_name IN ('!. join(q!','!, keys(%{ $tables->{$table}})). q!')!;
        my $sth = $dbh->prepare($sql) or die DBI::errstr;
        $sth->execute;
        while (my $row = $sth->fetchrow_hashref) {
            my $param = (keys( %{ $tables->{$table}{$row->{column_name}} }))[0];
            my %cfg = ( description => $row->{column_name},
                        name => $row->{column_name},
                        in => 'path',
#                        required => 'true',
                        );
            unless (exists($conversion{ $row->{data_type} })) {
                warn "ERROR: datatype $row->{data_type} not in conversion table";
                $cfg{ type } = $row->{data_type};
            }
            else {
                %cfg = ( %cfg,
                         %{ $conversion{ $row->{data_type} } } ); 
            }
            $config->{parameters}{$param} = { %cfg };
        }
    }
}   
sub process_parameters {
    my ($params, $tables) = @_;
    my @params = ();
    foreach my $param (keys %{ $params }) {
        warn Dumper { param => $param, params => $params };
        if (exists($params->{$param}->{sql})) {
            my ($table, $field) = split('\.', $params->{$param}->{sql});
            warn Dumper { param => $param, params => $params, table => $table, field => $field } unless defined $field;
            $tables->{$table}{$field}{$param} = $param;
            push(@params, { '$ref' => "#/parameters/$param" });
        }
        else {

        }
    }
    p @params;
    return \@params;
}
sub process_responses {
    my ($params, $tables) = @_;
    my @responses = ();
    return \@responses;
}
