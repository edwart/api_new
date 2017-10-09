package TalApi;
use strict;
use warnings;

use Dancer2;
use Dancer2::Plugin::OpenAPI;
use Dancer2::Plugin::Database;
use Data::Dumper;
use YAML::XS 'LoadFile';
use Path::Tiny;
use DateTime;
use DateTime::Event::Recurrence;
use FindBin qw/ $Bin /;
use File::Basename qw/ dirname /;
use SQL::Library;
use SQL::Beautify;
use Template;

# set logger => 'null' if $ENV{HARNESS_ACTIVE} && ! $ENV{TEST_VERBOSE};
set log => 'error' if $ENV{HARNESS_ACTIVE} && ! $ENV{TEST_VERBOSE};

set serializer => 'Mutable';

my $sql_beautifier = SQL::Beautify->new;
my $config              = config;
my $methods             = __get_list_of_methods();
my $database_handles    = __get_db_handles();
my $queries             = __get_queries();
my $sql_sources         = __get_sql_sources();
my $apiconfig           = OpenAPI->get_apiconfig;
my $tt = new Template(START_TAG => '<%', END_TAG => '%>');
our $VERSION = '0.1';

get '/interface' => sub {

    template 'interface.tt', { config => $apiconfig };
};
get '/createtimesheet/:filename' => sub {

    my %params = params;
    my %query_parameters = query_parameters->flatten;
    debug to_dumper {query_parameters => \%query_parameters, params => \%params };
    debug 'In createtimesheet get';

    my $fromfile = path(route_parameters->get('filename'))->slurp;
    debug to_dumper {fromfile => $fromfile };
    my $data = from_json($fromfile);
    my $jsondata = $data->{tp_json_entry};
    my $json = to_json($jsondata);
    $data->{tp_json_entry} = qq!$json!;
    debug to_dumper { timesheets => $data };

    set serializer => undef;

    template 'timesheet.tt', { timesheets => $data };
};
sub GetApiVersionInfo {
#    debug to_dumper $apiconfig;
    return to_json $apiconfig->{info};
}
sub GetTimesheet_sub {
    my @passed = @_;
    debug "In GetTimesheet_sub";
    my %query_parameters = query_parameters->flatten;
    my %route_parameters = route_parameters->flatten;
    my $sql;
    my $query_modifiers;
    if (exists($query_parameters{timesheetNo})) {
	    ($sql, $query_modifiers) = __get_query_sql('GetTimesheetById');
		return __run_query( query => 'GetTimesheetById',
                                      sql => $sql,
                                      query_modifiers=> $query_modifiers,
                                    );
	}
	else {
		if (exists($query_parameters{bookingNo}) and exists($query_parameters{weekEndDate})) {
            my $timesheet = __get_timesheet_for_weekend( bookingNo => $query_parameters{bookingNo},
                                                         weekEndDate => $query_parameters{weekEndDate});
            if ($timesheet->{pagination}->{total} < 1) {
                # get last week's if it exists
                my $lastweekenddate = __get_previous_weekdate($query_parameters{weekEndDate});
                my $lastweek_timesheet = __get_timesheet_for_weekend( bookingNo => $query_parameters{bookingNo},
                                                                      weekEndDate => $lastweekenddate );
                debug "Building Blank timesheet";
                my $blank =  __build_blank_timesheet(bookingNo => $query_parameters{bookingNo},
                                                     weekEndDate => $query_parameters{weekEndDate},
                                                     lastweektimesheet => scalar(@{ $lastweek_timesheet->{data} }) > 0 ? $lastweek_timesheet->{data}
                                                                                                                       : undef);
            }
            else {
                debug "Returning Existing timesheet";
                return to_json $timesheet;
            }
		}
		else {
            return __error(msg => "you must provide either a timesheet Id or and booking number and weekend date");
		}
    }
}
sub CreateOrAmendTimesheet {
    my @passed = @_;
    debug "In GetTimesheet_sub";
    my %query_parameters = query_parameters->flatten;
    my %route_parameters = route_parameters->flatten;
    my %body_parameters = route_parameters->flatten;
    my $sql;
    my $query_modifiers;
    unless (exists($query_parameters{timesheetNo})) {
        return __error(msg => "Mandatatory parameter timesheetNo missing");
    }
    ($sql, $query_modifiers) = __get_query_sql('GetTimesheetById');
    my $timesheet =  __run_query( query => 'GetTimesheetById',
                                    sql => $sql,
                                    query_modifiers=> $query_modifiers,
                                );
    unless (scalar(@{ $timesheet->{data}}) > 0) {
        return __error(msg => "timesheet $query_parameters{timesheetNo} dowes not exist");
    }
    my $json_entry = to_json $body_parameters{tp_json_entry} ;
    $body_parameters{tp_json_entry} = $json_entry;
    ($sql, $query_modifiers) = __get_query_sql('UpdateTimesheet', { %query_parameters, %body_parameters });
    return   __run_query( query => 'UpdateTimesheet',
                                    sql => $sql,
                                    query_modifiers=> $query_modifiers,
                                );
}
sub __get_previous_weekdate {
    my ($weekenddate) = @_;
    $weekenddate =~ m/^(\d{4})-?(\d{2})-?(\d{2})/;
    my ($year, $month, $day) = ($1, $2, $3);
    my %datetime = ( year => $year,
                     month => $month,
                     day => $day,
                     hour => 1,
                     minute => 1,
                     second => 1,
                    );
    debug to_dumper {  datetime => \%datetime };
    return DateTime->new(%datetime)->subtract(days => 7)->ymd('-');
}
sub __get_timesheet_for_weekend {
    my %params = @_;
    my ($sql, $query_modifiers) = __get_query_sql('GetTimesheet');
    return __run_query( query => 'GetTimesheet',
                                    sql => $sql,
                                    query_modifiers=> $query_modifiers,
                                    );
}
sub __build_blank_timesheet {
    my (%params) = @_;

=pod
    my %query_parameters = query_parameters->flatten;
    my %route_parameters = route_parameters->flatten;
    my %body_parameters = body_parameters->flatten;

=cut

    my $data;
    my @allowed_rates = ();
    if (defined($params{lastweektimesheet})) {
        $data = $params{lastweektimesheet};
        my $lastweek = from_json( $data->{tp_json_entry} );
        @allowed_rates = @{ $lastweek->{allowed_rates} };
        $data->{tp_json_entry_hash}{lastweek} = $lastweek;
    }
    else {
        my ($sql, $query_modifiers) = __get_query_sql('GetBookingDetails', \%params);
        my $booking = __run_query( query => 'GetBookingDetails',
                                        sql => $sql,
                                        query_modifiers=> $query_modifiers,
                                        );
        debug to_dumper { booking => $booking };
        if ($booking->{pagination}->{total} < 1) {
            return __error(code => 204,
                           msg => "Booking $params{bookingNo} does not exist");
        }
        my ($sql2m, $qm2) =  __get_query_sql('GetRateCodes');
        my $ratecodes = __run_query( query => 'GetRateCodes',
                                        sql => $sql2m,
                                        query_modifiers=> $qm2,
                                        );
        debug to_dumper { ratecodes => $ratecodes };
        my %ratecodes = ();
        foreach my $rc (@{ $ratecodes->{data} }) {
            $ratecodes{$rc->{rc_payrate_no}} = $rc;
        }
        my $today = DateTime->today->ymd('-');
        $data = { 
            tp_booking_no => $params{bookingNo},
            tp_amend_by => 'api',
            tp_amend_on => "$today",
            tp_batch_no => 0,
            tp_branch => 0,
            tp_booking_no_V => $params{bookingNo},
            tp_client_code => "",
            tp_client_code_V => "",
            tp_cost_centre => "",
            tp_custref => "",
            tp_error => 0,
            tp_hours_tot_V => 0,
            tp_imago_id => 0,
            tp_json_accept => 0,
            tp_not_working => 0,
            tp_process_level => 0,
            tp_payroll_no_V => 0,
            tp_recvd_date => "$today",
            tp_serial_code => "",
            tp_source => "",
            tp_surname => "",
            tp_surname_V => "",
            tp_type => "P",
            tp_type_V => "P",
            tp_week_no => 12,
            tp_week_no_V => 12,
            tp_week_date => $params{weekEndDate},
            tp_week_date_V => "$params{weekEndDate}",
            tp_xfer_date => "$today",
        };
        debug to_dumper { booking => $booking, data =>  $booking->{'data'} };
        my $dta = $booking->{data}[0]; 
        my %ratedetails = ();
        while (my ($k, $v) = each %{ $dta }) {
            if ($k =~ m/__(\d_)/) {
                my $n = $1;
                $ratedetails{$k} = $v if $dta->{"oa_payrate_no__$n"} > 0;
            }
        }
        debug to_dumper { dta => \%ratedetails };
        for my $n (1..8) {
            debug to_dumper { n => $n, rate_no => $dta->{"oa_payrate_no__$n"} };
            if ($dta->{"oa_payrate_no__${n}"} != 0 and defined($ratecodes{$dta->{"oa_payrate_no__$n"}}->{rc_rate_desc})) {
                debug to_dumper { n => $n, rate_no => $dta->{"oa_payrate_no__$n"} };
                my $rd = $ratecodes{$dta->{"oa_payrate_no__$n"}};
                debug to_dumper { rd => $rd };
                my %ar = ( hours => $dta->{"oa_rate_hours__$n"},
                        pay_type => $rd->{rc_pay_type},
                        pay_rate => $dta->{"oa_payrate__$n"},
                        inv_rate => $rd->{rc_inv_rate},
                        payrate_no => $dta->{"oa_payrate_no__$n"},
                        rate_desc => $rd->{rc_rate_desc},
                        );
                debug to_dumper { n => $n, ar => \%ar };
                push(@allowed_rates, { %ar });
            }
        }
    }
    debug to_dumper { allowed_rates => \@allowed_rates };
    if (scalar(@allowed_rates) < 1) {
        return __error(msg => "Unable to set up timesheet - there are no rates allowed on this booking");
    }
    my @rates = ();
    foreach my $ar (@allowed_rates) {
        push(@rates, { code => $ar->{payrate_no},
                       quantity => 0,
                       });
    }
    $data->{tp_json_entry_hash}{ allowed_rates} = \@allowed_rates;
    $data->{tp_json_entry_hash}{days} ||= [];
    $data->{tp_json_entry_hash}{ week_rate_total_days } ||= 0;
    $data->{tp_json_entry_hash}{ week_rate_total_hours } ||= 0;
    $data->{tp_json_entry_hash}{ week_rate_total_units } ||= 0;
    
    foreach my $weekdate (__generate_week_of_dates($params{weekEndDate})) {
        push(@{ $data->{tp_json_entry_hash}{days}}, { rates => [ @rates ],
                                                      date => $weekdate });
    }
    unless (exists($data->{tp_json_entry_hash}{lastweek})) {
        $data->{tp_json_entry_hash}{lastweek} ||= [];
        foreach my $weekdate (__generate_week_of_dates(__get_previous_weekdate($params{weekEndDate}))) {
            push(@{ $data->{tp_json_entry_hash}{lastweek}}, { rates => [ @rates ],
                                                        date => $weekdate });
        }
    }
    $data->{tp_json_entry} = to_json($data->{tp_json_entry_hash});
    delete($data->{tp_json_entry_hash});
    my $body_parameters = $data;
    my ($sql, $query_modifiers) =  __get_query_sql('NewTimesheet', $body_parameters);
    my $newtimesheet = __run_query( query => 'NewTimesheet',
                                    sql => $sql,
                                    query_modifiers=> {limit => -1},
                                    );
    debug to_dumper {  newtimesheet => $newtimesheet};
    my %result = (
                    debug => {},
                    data => $data,
                    status => 0,
                    pagination => { total => 1,
                              currentPage => 1,
                              hasMoreItems => 0,
                              pages => 1,
                              perPage => 1,
                              },
                    );
    ($sql, $query_modifiers) =  __get_query_sql('GetTimesheet');
    my $status = __run_query( query => 'GetTimesheetById',
                                      sql => $sql,
                                      query_modifiers=> $query_modifiers,
                                    );
    debug to_dumper { status => $status };
    return to_json $status;
}
sub __generate_week_of_dates {
    my ($weekenddate) = @_;
    $weekenddate =~ m/^(\d{4})-?(\d{2})-?(\d{2})/;
    my ($year, $month, $day) = ($1, $2, $3);
    debug to_dumper {  weekEndDate => $weekenddate, year => $year, month => $month, day => $day };

    my %datetime = ( year => $year,
                    month => $month,
                    day => $day,
                    hour => 1,
                    minute => 1,
                    second => 1,
                    );
    debug to_dumper {  datetime => \%datetime };
    my $startofweek = DateTime->new(%datetime)->subtract(days => 6);
    my @weekdates  = ();
    foreach my $n (0..6) {
        push(@weekdates, $startofweek->add(days => $n)->ymd('-'));
    }
    return @weekdates;
}
sub __error {
    my %params = @_;
    $params{code} ||= 404;
	return qq!{
				"status": "$params{code}",
                "error": "$params{msg}"
			}!;
}
sub GetPendingTimesheets {
    my @passed = @_;
$DB::single = 1;
    debug "In GetPendingTimesheets";
    my %result = (
                    debug => {},
                    data => [],
                    status => 0,
                    );
    my %query_parameters = query_parameters->flatten;
    my %route_parameters = route_parameters->flatten;
    my %body_parameters = body_parameters->flatten;
    my $sql;
    my $query_modifiers;
    ($sql, $query_modifiers) = __get_query_sql('GetBookings');
    $result{debug}{GetBookings} = $sql;
    $query_modifiers->{limit} = -1;
    $query_modifiers->{fields} = [ qw/oa_booking_no oa_date_start oa_date_end/ ];
    my $bookings = __run_query( query => 'GetBookings',
                                      sql => $sql,
                                      query_modifiers=> $query_modifiers,
                                    );
    debug to_dumper { bookings => $bookings };
    foreach my $booking (@{ $bookings->{data} } ) {
        debug to_dumper { booking => $booking };
        debug "Calling __get_query_sql GetBlankTimesheets";
        ($sql, $query_modifiers) = __get_query_sql('GetBlankTimesheets'),
        $result{debug}{GetBlankTimesheets}{$booking->{oa_booking_no}} = $sql;
        $query_modifiers->{limit} = -1;
        $query_modifiers->{search} = 'oa_booking_no='.$booking->{oa_booking_no};
        my $blank_timesheets = __run_query( query => 'GetBlankTimesheets',
                                        sql => $sql,
                                        query_modifiers=> $query_modifiers,
                                        );
        ($sql, $query_modifiers) = __get_query_sql( 'GetTimesheetHistory'),
        $result{debug}{GetTimesheetHistory}{$booking->{oa_booking_no}} = $sql;
        $query_modifiers->{limit} = -1;
        $query_modifiers->{search} = 'oa_booking_no='.$booking->{oa_booking_no};
        # TODO add timepool.tp_week_date >= 05-04-2017
        my $existing_timesheets = __run_query( query => 'GetTimesheetHistory',
                                                sql => $sql,
                                                query_modifiers=> $query_modifiers,
                                                );

        my %timesheets = map { $_ => undef } @{ __get_fridays($booking->{oa_date_start}) }; # TODO from 05-04-ccyy
        foreach my $ts (@{ $existing_timesheets->{data} }) {
            $timesheets{ $ts->{tp_week_date} } = $ts->{tp_extranet_status};
        }
        foreach my $ts (@{ $blank_timesheets->{data} }) {
            $timesheets{ $ts->{tp_week_date} } = $ts->{tp_extranet_status};
        }

        foreach my $friday (sort keys %timesheets ) {
            my $status = $timesheets{$friday} // '';
            push(@{ $result{data}}, {
                    oa_booking_no => $booking->{oa_booking_no},
                    oa_assignment => $booking->{oa_assignment},
                    cu_name => $booking->{cu_name},
                    tp_week_date => $friday,
                    tp_extranet_status =>$timesheets{$friday},
                },
                ) unless $status =~ /^(Approved|Paid)$/;
        }
    }
    $result{pagination} = { total => scalar(@{ $result{data} }),
                              currentPage => 1,
                              hasMoreItems => 0,
                              pages => 1,
                              perPage => scalar(@{ $result{data} }),
                              };
    debug to_dumper \%result;
    return  to_json \%result;

}
sub GetBookingTimesheets {
    my @passed = @_;
    my %query_parameters = query_parameters->flatten;
    my %route_parameters = route_parameters->flatten;
    my %body_parameters = body_parameters->flatten;
    my %query_modifiers = ();
    my $ratecodes = process_query( query => 'GetBookingRateCodes',
                        query_params => \%query_parameters,
                        route_params => \%route_parameters,
                        body_params => \%body_parameters,
                        query_modifiers=> \%query_modifiers,
                        );
    return to_json $ratecodes;
}
=pod

sub NewTimesheet {
    my @passed = @_;

    my %query_parameters = query_parameters->flatten;
    my %route_parameters = route_parameters->flatten;
    my %body_parameters = body_parameters->flatten;
    debug to_dumper {
                     passed => \@passed,
                     query_parameters => \%query_parameters,
                     route_parameters => \%route_parameters,
                     body_parameters => \%body_parameters,
                     };
    return '{
                "OK": "It worked !"
            }';

}

=cut

sub __get_query_sql {
    my ($query, $extra_params) = @_;
    my $sql = undef;
    my $sql_source = $sql_sources->{ $query } || $sql_sources->{ default };
    my $dbh = $database_handles->{ $sql_source };
    my $preprocessed = $queries->{ $sql_source }->{ $query };
    my %query_modifiers = ( );
    my $quoted_pars = {};
    unless (defined $extra_params) {
        my %query_parameters = query_parameters->flatten;
        my %route_parameters = route_parameters->flatten;
        my %body_parameters = body_parameters->flatten;
        debug to_dumper {preprocessed => $preprocessed, query_parameters => \%query_parameters,body_parameters=> \%body_parameters,route_parameters => \%route_parameters, extra_params => $extra_params   };

        # each() handles multiple values for same key
        query_parameters->each( sub {
            my $par = $_[0];
            my $val = $_[1];
            debug to_dumper { par => $par,
                            val => $val };

            if  ($par =~ m/^sort(\w+)/) {
                my $field = $1;
                my $direction = $val eq '1' ? 'ASC' : 'DESC';
                debug "sort by $field in direction $direction";
                $query_modifiers{orderby} ||= [];
                push(@{ $query_modifiers{orderby} }, "$field $direction");
            } elsif ($par =~ m/^like(\w+)/) {
                my $field = $1;
                $query_modifiers{where} ||= [];
                push(@{ $query_modifiers{where} }, qq!$field LIKE '$val'!);
            } elsif ($par eq 'select') {
                my @fields = split(',', $val);
                $query_modifiers{fields} = \@fields;
            } elsif ($par =~ m/^(limit|page)/) {
                $query_modifiers{$par} =  $val;

            } else {
                $query_modifiers{where} ||= [];
                if ($val =~ m/,/) {
                    my @values = map {$dbh->quote($_) } split(',', $val);
                    push(@{ $query_modifiers{where} }, qq!$par IN !.'('. join(',', @values). ')');
                }
                elsif ($val =~ m/^>=/) { # tp_week_date=>=2017-09-21 ->  tp_week_date >= 2017-09-21
                    $val = substr $val, 2;
                    push(@{ $query_modifiers{where} }, qq!$par >= !.$dbh->quote($val));
                }
                elsif ($val =~ m/^>/) {  # tp_week_date=>2017-09-21  ->  tp_week_date > 2017-09-21
                    $val = substr $val, 1;
                    push(@{ $query_modifiers{where} }, qq!$par > !.$dbh->quote($val));
                }
                elsif ($val =~ m/^<=/) { # tp_week_date=<=2017-09-21 ->  tp_week_date <= 2017-09-21
                    $val = substr $val, 2;
                    push(@{ $query_modifiers{where} }, qq!$par <= !.$dbh->quote($val));
                }
                elsif ($val =~ m/</) {   # tp_week_date=<2017-09-21  ->  tp_week_date < 2017-09-21
                    $val = substr $val, 1;
                    push(@{ $query_modifiers{where} }, qq!$par < !.$dbh->quote($val));
                }
                else {
                    push(@{ $query_modifiers{where} }, qq!$par = !.$dbh->quote($val));
                }
            }
        } );
        debug to_dumper { query_modifiers=> \%query_modifiers };
        $quoted_pars = __quote_params({ %route_parameters, %query_parameters, %body_parameters});
        $quoted_pars->{candId} ||= 200285;
    }
    else {
        $quoted_pars = __quote_params($extra_params);
    }
    debug to_dumper { params=> $quoted_pars, modifiers => \%query_modifiers  };
    $tt->process(\$preprocessed, { params => $quoted_pars,
                                modifiers => \%query_modifiers}, \$sql) or die $tt->error;
    $sql =~ s/\s*$//;
#    my $beautified = $sql_beautifier->query($sql);
#    debug to_dumper {postprocessed => $sql, beautified => $beautified };

#    my $nice_sql = $sql_beautifier->beautify;
    return ($sql, \%query_modifiers);
}
sub process_query {
    my @passed = @_;

    debug "In process_query";
    my %query_parameters = query_parameters->flatten;
    my %route_parameters = route_parameters->flatten;
    my %body_parameters = body_parameters->flatten;
#    my %query_modifiers = ();
    my $query = $passed[0]{ operationId };
    my $sql_source = $sql_sources->{ $query } || $sql_sources->{ default };
    my $dbh = $database_handles->{ $sql_source };

    unless (exists( $queries->{ $sql_source }->{ $query })) {
        if (exists( $methods->{$query} )) {
            my $sub = TalApi->can( $query );
            debug "Calling $query";

            return &$sub(@_);
        }
        else {
            return qq!{
                        "error": "unknown query $query"
                    }!;
        }
    }
    my ($sql, $query_modifiers ) = __get_query_sql($query);
    debug to_dumper { sql => $sql, modifiers => $query_modifiers };

=pod
    my $sql = undef;
    my $preprocessed = $queries->{ $sql_source }->{ $query };
    debug to_dumper {preprocessed => $preprocessed, query_parameters => \%query_parameters,body_parameters=> \%body_parameters,route_parameters => \%route_parameters   };
    my %query_modifiers = ( );

    while (my ($par, $val) = each %query_parameters) {
          debug to_dumper { par => $par,
                            val => $val };
          if  ($par =~ m/^sort(\w+)/) {
            my $field = $1;
            my $direction = $val eq '1' ? 'ASC' : 'DESC';
            $query_modifiers{orderby} ||= [];
            push(@{ $query_modifiers{orderby} }, "$field $direction");
        } elsif ($par eq 'select') {
            my @fields = split(',', $val);
            $query_modifiers{fields} = \@fields;
        } elsif ($par =~ m/^(limit|page)/) {
            $query_modifiers{$par} =  $val;

        } else {
            $query_modifiers{where} ||= [];
            if ($val =~ m/,/) {
                my @values = map {$dbh->quote($_) } split(',', $val);
                push(@{ $query_modifiers{where} }, qq!$par IN !.'('. join(',', @values). ')');
            }
            else {
                push(@{ $query_modifiers{where} }, qq!$par = !.$dbh->quote($val));
            }
        }
    }

    debug to_dumper { query_modifiers=> \%query_modifiers };
    my $quoted_pars = __quote_params({ %route_parameters, %query_parameters, %body_parameters });
    $quoted_pars->{candId} ||= 200285;
    $quoted_pars->{fridays} ||= $fridays;
    debug to_dumper { params=> $quoted_pars, modifiers => \%query_modifiers  };
    $tt->process(\$preprocessed, { params => $quoted_pars,
                                   modifiers => \%query_modifiers}, \$sql) or die $tt->error;
    $sql =~ s/\s*$//;
    debug to_dumper {postprocessed => $sql };
    my $beautified = $sql_beautifier->query($sql);

    my $nice_sql = $sql_beautifier->beautify;

=cut

    debug to_dumper { params => \%query_parameters, modifiers => $query_modifiers, sql => $sql, query => $query };


    return to_json __run_query( query => $query,
                        sql => $sql,
                        query_modifiers=> $query_modifiers,
                        );

}
sub __quote_params {
    my ($params) = @_;
    my %quoted_params = ();
    my $dbh = $database_handles->{'mysql'};
    while (my ($param, $value) = each %{ $params }) {
        $quoted_params{ $param } = $dbh->quote($value);
    }
    return \%quoted_params
}
sub __get_list_of_methods {
    use Class::Sniff;
    my %methods = ();
    my $sniff = Class::Sniff->new({class => 'TalApi'});
    my $report = $sniff->report;
#    debug $report;
    foreach my $name (keys %TalApi::) {
        next if $name =~ m/^__/;
        my $sub = TalApi->can( $name );
        next unless defined $sub;
        my $proto = prototype $sub;
        next if defined $proto and length($proto) == 0;
        $methods{$name} = 1;
    }
#    debug to_dumper { methods => \%methods };
    return \%methods;
}
sub __get_db_handles {
    my %database_handles = ();
    foreach my $db (keys %{ $config->{plugins}->{Database}->{connections} }) {
        $database_handles{$db} = database($db, );
    }
    return \%database_handles;
}
sub __get_queries {
    my %sqllibraries = ();
    our %queries = (); # = map { $_ => $sql->retr($_) } @elements;
    my $libs = $config->{plugins}->{OpenAPI}->{SQLLibrary}->{config};
    foreach my $library (keys %{ $libs->{libraries} }) {
        my $sql = new SQL::Library { lib => dirname($Bin).'/'. $libs->{libraries}->{ $library }}
            or warn "Can't open SQL::Library ". dirname($Bin).'/'. $libs->{libraries}->{ $library } ;
        $sqllibraries{$library} = $sql;
        $queries{$library} = {};
        my @elements = $sqllibraries{$library}->elements;
        $queries{$library} = { map { $_ => $sql->retr($_) } @elements };
    }
    return \%queries;
}
sub __get_sql_sources {
    my $libs = $config->{plugins}->{OpenAPI}->{SQLLibrary}->{config};
    return YAML::XS::LoadFile( dirname($Bin).'/'. $libs->{datasource} );
}

sub __run_query {
    my %params = @_;
    debug to_dumper { __run_query => \%params };
    my $calc_rows_sql = $params{sql};
    $calc_rows_sql =~ s/select\s+/select SQL_CALC_FOUND_ROWS /mi;
    my $ret;
    my $sth;
    my $limit = 0;
    my $page = 1;
    my $pages = 1;
    my $last_row;
    my $row_count;
    if ($calc_rows_sql ne $params{sql}) {
        debug to_dumper { sql => $params{sql},
                        calc_rows_sql => $calc_rows_sql };
        my $sth1 = $database_handles->{ mysql }->prepare($calc_rows_sql) or return __error(msg => $DBI::errstr);
        $sth1->execute() or return __error(msg => $DBI::errstr);
        $row_count = $database_handles->{ mysql }->selectrow_array('SELECT FOUND_ROWS()');

        $limit = $params{query_modifiers}{limit} || 5;
        $page = $params{query_modifiers}{page} || 1;
        $last_row =$row_count;
        unless ( $limit == -1 ) {
            my $limit_offset = ($page * $limit) - $limit;
            $last_row = $limit_offset + $limit;

            my $limit_clause = " LIMIT $limit_offset, $limit";
            $params{sql} .= " $limit_clause";
        }
        debug to_dumper { sql => $params{sql} };
        $sth = $database_handles->{ mysql }->prepare($params{sql} );
        $ret = $sth->execute() or return __error(msg => $DBI::errstr);
        $pages = int($sth->rows / $limit);
    }
    else {
        $sth = $database_handles->{ mysql }->prepare($params{sql} );
        $ret = $sth->execute()  or return __error(msg => $DBI::errstr);
        $row_count = $ret;
    }
    debug to_dumper { sql => $params{sql},
                    rows => $row_count };

    my %result = (
                    debug => { sql => { $params{query} => $params{sql} } },
                    pagination => { total => $row_count },
                    status => defined $ret ? 0 : $sth->errstr,
                    data => [],
                    );
    $result{pagination}{pages} = $pages;
    $result{pagination}{perPage} = $limit;
    $result{pagination}{currentPage} = $page;
    $result{pagination}{hasMoreItems} = $last_row < $row_count;

    if ($sth->{NUM_OF_FIELDS} > 0 ) { # this is a select statement
        while (my $row = $sth->fetchrow_hashref) {
            if (exists($row->{tp_json_entry})) {
                my $decoded = from_json($row->{tp_json_entry});
                $row->{tp_json_entry} = $decoded;
            }
            push(@{ $result{data } }, $row);
        }
    }
    return \%result;
}
sub __get_fridays {
    my ($from_date) = @_;
    my ($year, $month, $day) = split('-',$from_date);

    my $dt_start = DateTime->new(year => $year, month => $month, day => $day);
    my $dt_end = DateTime->today();
    my $der = DateTime::Event::Recurrence->weekly(days => 5);
    my @dates = ();
    push(@dates, $_->ymd('-')) for $der->as_list( start => $dt_start, end => $dt_end );
    return \@dates;
}

# go back to 5th April, start day of this financial year
sub __financial_year_start_friday {
    my $dt = DateTime->today;
    # if before april 5th, then this is in previous year
    if ( $dt->month < 4 || ( $dt->month == 4 && $dt->day < 5 ) )
    {
        $dt->add( years => -1 );
    }
    $dt->set_month( 4 );
    $dt->set_day( 5 );
    # move forward to Friday
    while ( $dt->day_of_week != 5 )
    {
        $dt->add( days => 1 );
    }
    return $dt;
}

true;
