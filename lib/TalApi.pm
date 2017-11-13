package TalApi;
use strict;
use warnings;

use Dancer2;
use Dancer2::Plugin::OpenAPI;
use Dancer2::Plugin::Database;
use Data::Dumper;
use MyAPI;
use HTTP::Status qw(:constants :is status_message);
use YAML::XS 'LoadFile';
use JSON::DWIW ();
use Path::Tiny;
use DateTime;
use DateTime::Event::Recurrence;
use FindBin qw/ $Bin /;
use File::Basename qw/ dirname /;
use SQL::Library;
#use SQL::Abstract::More;
use Template;
my $config              = config;
my $openapi = $config->{plugins}->{OpenAPI};
my $namespace = $openapi->{namespace};
debug to_dumper { namespace => $namespace };
#prefix $openapi->{prefix} if $openapi->{prefix};
set serializer $openapi->{serializer} if $openapi->{serializer};
my $apiconfig           = OpenAPI->get_apiconfig;

our $VERSION = '0.1';

sub process_query {
	my ($params) = @_;	
	debug to_dumper { params => $params };

	my $config              = config;
	my $openapi = $config->{plugins}->{OpenAPI};
	my $namespace = $openapi->{namespace};
    my %params = params;
    my $query_parameters = query_parameters->flatten;
    my $route_parameters = route_parameters->flatten;
    my $body_parameters = body_parameters->flatten;
	debug to_dumper { config => $config };
	my $api = MyAPI->new( apiconfig => $apiconfig,
                          cfg => $config,
                          parent_class => 'MyAPI',
        				  query_parameters => $query_parameters,
						  route_parameters => $route_parameters,
						  body_parameters => $body_parameters,
							);
	debug to_dumper { api => $api };
    my $is_query = $api->is_query( $params->{operationId });
    my $is_method = $api->is_method( $params->{operationId });
	debug to_dumper { isquery => $is_query, is_method => $is_method };
#
#	my $config_queries      = $config->{queries};
#	my $sql_sources         = $api->__get_sql_sources();
    if ($api->is_query( $params->{operationId })) {
       debug "is a query";
       return $api->run_query($params);
    }
    elsif ($api->is_method( $params->{operationId })) {
       debug "is a method";
   }
   else {
       error "Not sure what $params->{operationId} is";
   }
    return to_json { };
}

=pod

sub GetTimesheet_sub {
    my %params = @_;
    my $query_config = $params{query_config};
    debug "In GetTimesheet_sub";
    my %query_parameters = query_parameters->flatten;
    my %route_parameters = route_parameters->flatten;
    my $sql;
    my $bind;
    my %all_parameters = ( %query_parameters, %route_parameters );
    debug to_dumper { query_parameters => \%query_parameters, route_parameters => \%route_parameters };
    if (exists($all_parameters{timesheetNo})) {
	    ($sql, $bind) = __get_query_sql('GetTimesheetById', query_config => $query_config);
		return __run_query( query => 'GetTimesheetById',
                                      sql => $sql,
                                      bind => $bind,
                                    );
	}
	else {
		if (exists($all_parameters{bookingNo}) and exists($all_parameters{weekEndDate})) {
            my $timesheet = __get_timesheet_for_weekend( query_config => $query_config,
                                                         bookingNo => $all_parameters{bookingNo},
                                                         weekEndDate => $all_parameters{weekEndDate});
            debug to_dumper { timesheet => $timesheet };
            if ($timesheet->{pagination}->{total} < 1) {
                # get last week's if it exists
                my $lastweekenddate = __get_previous_weekdate($all_parameters{weekEndDate});
                my $lastweek_timesheet = __get_timesheet_for_weekend( query_config => $query_config,
                                                                      bookingNo => $all_parameters{bookingNo},
                                                                      weekEndDate => $lastweekenddate );
                debug "Building Blank timesheet";
                if  (scalar(@{ $lastweek_timesheet->{data} }) > 0) {
                    return to_json __build_blank_timesheet(query_config => $query_config,
                                                            bookingNo => $all_parameters{bookingNo},
                                                            weekEndDate => $all_parameters{weekEndDate},
                                                            lastweektimesheet => $lastweek_timesheet->{data});
                }
                else {
                    return to_json  __build_blank_timesheet(query_config => $query_config,
                                                            bookingNo => $all_parameters{bookingNo},
                                                             weekEndDate => $all_parameters{weekEndDate});
                }
            }
            else {
                debug "Returning Existing timesheet";
                return to_json $timesheet;
            }
		}
		else {
            return __error(code => HTTP_PRECONDITION_FAILED,
                           msg => "you must provide either a timesheet Id or and booking number and weekend date");
		}
    }
}
sub CreateOrAmendTimesheet {
    my %params = @_;
    debug "In CreateOrAmendTimesheet ";
    my $query_config = $params{query_config};
    my %query_parameters = query_parameters->flatten;
    my %route_parameters = route_parameters->flatten;
    my %body_parameters = body_parameters->flatten;
    my $sql;
    my $bind;
    debug to_dumper { query_parameters => \%query_parameters,
                      route_parameters => \%route_parameters,
                      body_parameters => \%body_parameters };
    unless (exists($route_parameters{timesheetNo}) or exists($query_parameters{timesheetNo})) {
        return __error(code => HTTP_PRECONDITION_FAILED,
                       msg => "Mandatatory parameter timesheetNo missing");
    }
    ($sql,$bind) = __get_query_sql('GetTimesheetById', query_config => $query_config);
    my $timesheet =  __run_query( query => 'GetTimesheetById',
                                  sql => $sql,
                                  bind => $bind,
                                );
    unless (scalar(@{ $timesheet->{data}}) > 0) {
        return __error(code => HTTP_PRECONDITION_FAILED,
                       msg => "timesheet $query_parameters{timesheetNo} does not exist");
    }
    my $data = $timesheet->{data}->[0];
    my $tp_json_entry = $data->{tp_json_entry};
    my $tp_json_entry_saved = $data->{tp_json_entry};
    debug to_dumper { body_parameters => \%body_parameters,
                      tp_json_entry => $tp_json_entry };

    if (exists($body_parameters{comment})) {
        if (exists($tp_json_entry->{comment})) {
            $tp_json_entry->{comment_history} ||= [];
            my %oldcomment = ();
            foreach my $field (qw/comment comment_type comment_by comment_on comment_at/) {
                $oldcomment{ $field } = $tp_json_entry->{ $field } if $tp_json_entry->{ $field };
            }
            push(@{ $tp_json_entry->{comment_history} }, { %oldcomment });
        }
        $tp_json_entry->{comment} = $body_parameters{comment};
        $tp_json_entry->{comment_type} = $body_parameters{comment_type} || 'general';
        $tp_json_entry->{comment_by} = 'api';
        $tp_json_entry->{comment_on} = DateTime->today->ymd('-');
        $tp_json_entry->{comment_at} = DateTime->now->hms(':');
        debug to_dumper { body_parameters => \%body_parameters };
    }
    delete($body_parameters{comment});
    delete($body_parameters{comment_type});
    if (exists($body_parameters{not_working}) and $body_parameters{not_working} == 1) {
        $tp_json_entry->{saved} = [ @{ $tp_json_entry_saved->{days} } ];
        $body_parameters{tp_not_working} = 1;
        debug to_dumper { body_parameters => \%body_parameters,
                        tp_json_entry => $tp_json_entry };
    }
    delete($body_parameters{not_working});
    if (exists($body_parameters{is_submitted}) and $body_parameters{is_submitted} == 1) {
        $body_parameters{tp_extranet_status} = 'Submitted';
        debug to_dumper { body_parameters => \%body_parameters,
                        tp_json_entry => $tp_json_entry };
    }
    delete($body_parameters{is_submitted});
    if (exists($body_parameters{loaded_previous_week}) and $body_parameters{loaded_previous_week} == 1) {
        $tp_json_entry->{saved} = [ @{ $tp_json_entry_saved->{days} } ];
        $tp_json_entry->{loaded_previous_week} = 1;
        debug to_dumper { body_parameters => \%body_parameters,
                        tp_json_entry => $tp_json_entry };
    }
    delete($body_parameters{loaded_previous_week});
    debug to_dumper { body_parameters => \%body_parameters,
                    tp_json_entry => $tp_json_entry };
        

    if (exists($body_parameters{days_entry})) {
    debug to_dumper { days_entry => $body_parameters{days_entry} };
        my ($days_entry, $error_msg) = $json_obj->from_json($body_parameters{days_entry});
    debug to_dumper { days_entry => $days_entry, error => $error_msg };
#        my $days_entry = from_json($body_parameters{days_entry});
        my %changes = ();
        foreach my $day (@{ $days_entry }) {
            my $rates = $day->{rates};
            for (my $rateno=0; $rateno<scalar(@{ $rates}); $rateno++) {
                $changes{ $day->{date} }{ $rates->[$rateno]->{code} } =  $rates->[$rateno]->{quantity};
            }
        }
        debug to_dumper { changes => \%changes };
        for (my $dayno=0; $dayno<scalar(@{ $tp_json_entry->{days} }); $dayno++) {
            my $day = $tp_json_entry->{days}[$dayno];
            debug to_dumper { day => $day };
            if (exists($changes{ $day->{date} })) {
                my $rates = $day->{rates};
            debug to_dumper { rates => $rates };
                for (my $rateno=0; $rateno<scalar(@{ $rates }); $rateno++) {
                    my $rate = $rates->[$rateno];
            debug to_dumper { oldday => $tp_json_entry->{days}[$dayno] };
            debug to_dumper { old => $tp_json_entry->{days}[$dayno]{rates}[$rateno]{quantity},
                              new => $changes{ $day->{date} }{ $rate->{code} } };

                    delete($tp_json_entry->{days}[$dayno]{quantity}) if exists $tp_json_entry->{days}[$dayno]{quantity};
                    $tp_json_entry->{days}[$dayno]{rates}[$rateno]{quantity} = $changes{ $day->{date} }{ $rate->{code} };

            debug to_dumper { newday => $tp_json_entry->{days}[$dayno] };
            debug to_dumper { rate => $rate, dayno => $dayno, newval =>  $changes{ $day->{date} }{ $rate->{code} } };
                }
            }
        }
    }


    delete($body_parameters{days_entry});
    debug to_dumper $tp_json_entry;
    $body_parameters{tp_json_entry} = to_json($tp_json_entry);
    debug to_dumper $body_parameters{tp_json_entry};
    $body_parameters{tp_timesheet_no} = $route_parameters{timesheetNo};
#    foreach my $field (keys %body_parameters) {
#        delete( $body_parameters{$field}) unless exists $data->{$field};
#    }
    
    $body_parameters{tp_amend_by} = 'api';
    $body_parameters{tp_amend_at} = DateTime->now->hms(':');
    $body_parameters{tp_amend_on} = DateTime->now->ymd('-');
    debug to_dumper { body_parameters => \%body_parameters };

    ($sql, $bind) = __get_query_sql('UpdateTimesheet',  query_config => $query_config, %body_parameters );
    #return __error(code => HTTP_PRECONDITION_FAILED,
    #                       msg => "no sql query for UpdateTimesheet\n".Dumper { body => \%body_parameters });
    return  to_json __run_query( query => 'UpdateTimesheet',
                                 sql => $sql,
                                 bind => $bind,
                                );
}
sub __get_previous_weekdate {
    my ($weekenddate) = @_;
    debug to_dumper {  weekenddate => $weekenddate };
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
    my ($sql, $bind) = __get_query_sql('GetTimesheet', %params);
    return __run_query( query => 'GetTimesheet',
                        sql => $sql,
                        bind => $bind,
                        );
}
sub __build_blank_timesheet {
    my (%params) = @_;
    debug to_dumper { params => \%params };

    my $query_config = $params{query_config};
    my $data = {};
    debug to_dumper { data2 => $data };
    my @allowed_rates = ();
    if (defined($params{lastweektimesheet}) and defined($params{lastweektimesheet}->[0]->{allowed_rates})) {
        my $d = $params{lastweektimesheet}->[0];
        debug to_dumper { data => $d };

        my $lastweek = $data->{tp_json_entry};
        
        @allowed_rates = @{ $lastweek->{allowed_rates} } if $lastweek->{allowed_rates};
        $data->{tp_json_entry_hash}{previous_week} = $lastweek;
        $data->{tp_json_entry_hash}{tp_has_previous_week} = 1;
        debug to_dumper { data2 => $data };
    }
    else {
        $data->{tp_json_entry_hash}{tp_has_previous_week} = 0;
        my ($sql, $bind) = __get_query_sql('GetBookingDetails', %params);
        my $booking = __run_query( query => 'GetBookingDetails',
                                   sql => $sql,
                                   nolimit => 1,   
                                   bind => $bind,
                                        );
        debug to_dumper { booking => $booking };
        if ($booking->{pagination}->{total} < 1) {
            return __error(code => HTTP_PRECONDITION_FAILED,
                           msg => "Booking $params{bookingNo} does not exist");
        }
        my ($sql2m, $qm2, $bind2) =  __get_query_sql('GetRateCodes', %params);
        my $ratecodes = __run_query( query => 'GetRateCodes',
                                     nolimit => 1,
                                     sql => $sql2m,
                                     bind => $bind2,
                                        );
        my %ratecodes = ();
        foreach my $rc (@{ $ratecodes->{data} }) {
            $ratecodes{$rc->{rc_payrate_no}} = $rc;
        }
        debug to_dumper { ratecodes => [ sort keys %ratecodes ] };
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
            tp_extranet_status => "",
            tp_extranet_queried => 0,
            tp_comment => "",
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
        debug to_dumper { data2 => $data };
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
        debug to_dumper { data2 => $data };
        for my $n (1..8) {
            debug to_dumper { n => $n, rate_no => $dta->{"oa_payrate_no__$n"} };
            my $rate_no = $dta->{"oa_payrate_no__$n"};
            debug to_dumper { "ratecode_$rate_no" => $ratecodes{$rate_no} };
            if ($dta->{"oa_payrate_no__${n}"} != 0 and defined($ratecodes{$dta->{"oa_payrate_no__$n"}}->{rc_rate_desc})) {
                debug to_dumper { n => $n, rate_no => $dta->{"oa_payrate_no__$n"} };
                my $rd = $ratecodes{$dta->{"oa_payrate_no__$n"}};
                my $limit = $rd->{rc_payrate_no};
                $limit ||= 0;
                if ($limit == 0) {
                    $limit = choose_one(7,8,9,10,11,12) if $rd->{rc_pay_type} eq 'hours';
                    $limit = 1 if $rd->{rc_pay_type} eq 'days';
                }

                debug to_dumper { rd => $rd };
                my %ar = ( hours => $dta->{"oa_rate_hours__$n"},
                        pay_type => $rd->{rc_pay_type},
                        pay_rate => $dta->{"oa_payrate__$n"},
                        inv_rate => $rd->{rc_inv_rate},
                        limit => $limit,
                        payrate_no => $dta->{"oa_payrate_no__$n"},
                        rate_desc => $rd->{rc_rate_desc},
                        );
                debug to_dumper { n => $n, ar => \%ar };
                push(@allowed_rates, { %ar });
            }
        }
        debug to_dumper { data2 => $data };
    }
    debug to_dumper { data2 => $data };
    debug to_dumper { allowed_rates => \@allowed_rates };
    if (scalar(@allowed_rates) < 1) {
        return __error(code => HTTP_EXPECTATION_FAILED,
                       msg => "Unable to set up timesheet - there are no rates allowed on this booking");
    }
    my @rates = ();
    foreach my $ar (@allowed_rates) {
        push(@rates, { code => $ar->{payrate_no},
                       quantity => 0,
                       });
    }
    debug to_dumper { data2 => $data };
    $data->{tp_json_entry_hash}{ allowed_rates} = \@allowed_rates;
    $data->{tp_json_entry_hash}{days} ||= [];
    $data->{tp_json_entry_hash}{ week_rate_total_days } ||= 0;
    $data->{tp_json_entry_hash}{ week_rate_total_hours } ||= 0;
    $data->{tp_json_entry_hash}{ week_rate_total_units } ||= 0;
    $data->{tp_json_entry_hash}{ loaded_previous_week } ||= 0;
    
    foreach my $weekdate (__generate_week_of_dates($params{weekEndDate})) {
        push(@{ $data->{tp_json_entry_hash}{days}}, { rates => [ @rates ],
                                                      date => $weekdate });
    }
    unless (exists($data->{tp_json_entry_hash}{previous_week})) {
        $data->{tp_json_entry_hash}{previous_week} ||= [];
        foreach my $weekdate (__generate_week_of_dates(__get_previous_weekdate($params{weekEndDate}))) {
            push(@{ $data->{tp_json_entry_hash}{previous_week}}, { rates => [ @rates ],
                                                        date => $weekdate });
        }
        $data->{tp_json_entry_hash}{tp_has_previous_week} = 0;
    }
    else {
        $data->{tp_json_entry_hash}{tp_has_previous_week} = 1;
    }
    $data->{tp_json_entry_hash}{tp_has_previous_week} = 1 if scalar( @{ $data->{tp_json_entry_hash}{previous_week} }) > 0;
    $data->{tp_json_entry} = to_json($data->{tp_json_entry_hash});
    delete($data->{tp_json_entry_hash});
    delete $data->{bookingNo} if exists $data->{bookingNo};
    debug to_dumper { data2 => $data };
    my ($sql, $bind) =  __get_query_sql('NewTimesheet',
                                         %{ $data });
    my $newtimesheet = __run_query( query => 'NewTimesheet',
                                    sql => $sql,
                                    nolimit => 1,
                                    bind => $bind,
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
    ($sql, $bind) =  __get_query_sql('GetTimesheet', query_config => $query_config);

    my $status = __run_query( query => 'GetTimesheetById',
                              sql => $sql,
                              bind => $bind,
                              );
    debug to_dumper { status => $status };
    return $status;
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
    debug to_dumper { 
                      status => $params{code},
                      error =>  $params{msg},
                    };
	return qq!{
				"status": "$params{code}",
                "error": "$params{msg}"
			}!;
}
sub GetPendingTimesheets {
    my %params = @_;
$DB::single = 1;
    debug "In GetPendingTimesheets";
    my $query_config = $params{query_config};
    debug to_dumper { query_config => $query_config  };
    my %result = (
                    debug => {},
                    data => [],
                    status => 0,
                    );
    my %query_parameters = query_parameters->flatten;
    my %route_parameters = route_parameters->flatten;
    my %body_parameters = body_parameters->flatten;
    my ($sql, $bind) = __get_query_sql('GetBookings', query_config => $query_config);
    $result{debug}{GetBookings}{sql} = $sql;
    $result{debug}{GetBookings}{bind} = $sql;
    my $bookings = __run_query( query => 'GetBookings',
                                sql => $sql,
                                fields => [ qw/oa_booking_no oa_date_start oa_date_end/ ],
                                nolimit => 1,
                                bind => $bind,
                                );
    debug to_dumper { bookings => $bookings };
    my @data = ();
    foreach my $booking (@{ $bookings->{data} } ) {
        debug to_dumper { booking => $booking };
        debug "Calling __get_query_sql GetBlankTimesheets";
        ($sql, $bind) = __get_query_sql('GetBlankTimesheets',
                                        bookingNo => $booking->{oa_booking_no},
                                        query_config => $query_config);
        $result{debug}{GetBlankTimesheets}{$booking->{oa_booking_no}}{sql} = $sql;
        $result{debug}{GetBlankTimesheets}{$booking->{oa_booking_no}}{bind} = $bind;
        my $blank_timesheets = __run_query( query => 'GetBlankTimesheets',
                                            sql => $sql,
                                            nolimit => 1,
                                            search => 'oa_booking_no='.$booking->{oa_booking_no},
                                            bind => $bind,
                                        );
        %params = ( %query_parameters, %route_parameters, %body_parameters);
        $params{bookingNo} = $booking->{oa_booking_no};
#        $query_modifiers->{where}{bookingNo} = $booking->{oa_booking_no};
        ($sql, $bind) = __get_query_sql( 'GetTimesheetHistory', \%params);
        $result{debug}{GetTimesheetHistory}{$booking->{oa_booking_no}}{sql} = $sql;
        $result{debug}{GetTimesheetHistory}{$booking->{oa_booking_no}}{bind} = $bind;
#        $query_modifiers->{limit} = -1;
#        $query_modifiers->{search} = 'oa_booking_no='.$booking->{oa_booking_no};
        # TODO add timepool.tp_week_date >= 05-04-2017
        my $existing_timesheets = __run_query( query => 'GetTimesheetHistory',
                                               sql => $sql,
                                               nolimit => 1,
                                               bind => $bind,
                                            );

        debug to_dumper { existing_timesheets => $existing_timesheets->{data} };
        my %timesheets = map { $_ => undef } @{ __get_fridays($booking->{oa_date_start}) }; # TODO from 05-04-ccyy
        foreach my $ts (@{ $existing_timesheets->{data} }) {
            $timesheets{ $ts->{tp_week_date} }{tp_extranet_status} = $ts->{tp_extranet_status};
            $timesheets{ $ts->{tp_week_date} }{tp_extranet_queried} = $ts->{tp_extranet_queried};
        }
        foreach my $ts (@{ $blank_timesheets->{data} }) {
            $timesheets{ $ts->{tp_week_date} }{tp_extranet_status} = $ts->{tp_extranet_status};
            $timesheets{ $ts->{tp_week_date} }{tp_extranet_queried} = 0;
        }

        debug to_dumper { timesheets => \%timesheets };
        debug to_dumper { booking => $booking };
        foreach my $friday (sort keys %timesheets ) {
            my $status = $timesheets{$friday} // '';
            push(@data, {
                    oa_booking_no => $booking->{oa_booking_no},
                    oa_assignment => $booking->{oa_assignment},
                    cu_name => $booking->{cu_name},
                    tp_week_date => $friday,
                    tp_extranet_status =>"",
                    tp_extranet_queried =>0,
                },
                ) unless $status =~ /^(Approved|Paid)$/;
        }
        debug to_dumper { data => \@data, query_config => $query_config };
    }

    my $limit = $query_config->{limit} || 5;
    my $page = $query_config->{page} || 1;
    my $row_count = scalar(@data);;
    my $pages = int($row_count / $limit);
    my $last_row = $row_count;
    unless ( $limit == -1 ) {
        my $limit_offset = ($page * $limit) - $limit;
        $last_row = $limit_offset + $limit - 1;
        my @wanted = @data[$limit_offset..$last_row];
        $result{data} = \@wanted;
        $result{pagination}{pages} = $pages;
        $result{pagination}{perPage} = $limit;
        $result{pagination}{currentPage} = $page;
        $result{pagination}{hasMoreItems} = $last_row < $row_count;
        $result{pagination}{total} = scalar(@data);
    }
    else {
        $result{data} = \@data;
        $result{pagination} = { total => scalar(@{ $result{data} }),
                                currentPage => 1,
                                hasMoreItems => 0,
                                pages => 1,
                                perPage => scalar(@{ $result{data} }),
                                };
    }
    debug to_dumper \%result;
    return  to_json \%result;

}
sub GetBookingTimesheets {
    my %params = @_;
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

sub __get_query_sql {
    my ($query, %params) = @_;
    debug to_dumper { query => $query, params => \%params,  config_queries => \$config_queries} if %params;
    my $sql = undef;
    my @bind = ();
    my $sql_source = $sql_sources->{ $query } || $sql_sources->{ default };
    my $dbh = $database_handles->{ $sql_source };
    my %query_parameters = query_parameters->flatten;
    my %route_parameters = route_parameters->flatten;
    my %body_parameters = body_parameters->flatten;
    my %all_params = ( %query_parameters, %route_parameters, %body_parameters, %params );

    if (exists($config_queries->{$query})) {
        my $query_config = $params{query_config};
        my $qd = $config_queries->{$query};
        if ($qd->{default}) {
            debug 'Has Default';
            foreach my $thing (keys %{ $qd->{default} }) {
                foreach my $default (keys %{ $qd->{default}->{$thing} }) {
                    $all_params{ "$default" } = $qd->{default}->{$thing}->{$default};
                }
            }
        }
    debug to_dumper { query => $query, params => \%all_params } if %params;


        if ($qd->{type} eq 'insert') {
          debug to_dumper {qd => $qd,
                           insert => \%params };
          ($sql, @bind) = $sql_abs->insert($qd->{table},
                                           \%params);
          debug to_dumper {sql => $sql, bind => \@bind };

        }
        elsif ($qd->{type} eq 'update') {
            my %fields = ();
            my %tables = ();
            my %where = ();
            my %to_pass = %params;

            delete $to_pass{query_config};
            if ($qd->{where}) {
                foreach my $table (keys %{ $qd->{where} }) {
                    if (exists($qd->{where}->{$table}->{required})) {
                        foreach my $field (keys %{ $qd->{where}->{ $table }->{required} }) {
                            my $fd = $qd->{where}->{ $table }->{required}->{$field};
                            if (ref($fd) eq 'HASH') {
                                foreach my $keyword (keys %{ $fd }) {
                                    if ($keyword eq 'in') {
                                        $tables{$table} = 1;
                                        $where{"$table.$field"} = { -in => [ split(/\n/,$fd->{$keyword}) ] };
                                    }
                                }
                            }
                            else {
                                if ($fd =~ m/^params/) {
                                    $where{"$table.$field"} = $fd;
                                }
                                else {
                                    $where{"$table.$field"} = \"= $fd";
                                }
                                $tables{$table} = 1;
                            }
                       } 
                    } 
                    debug to_dumper {where => \%where };
                    if (exists($qd->{where}->{ $table }->{optional})) {
                        foreach my $optional (keys %{ $qd->{where}->{ $table }->{optional} }) {
                            my $fd = $qd->{where}->{optional}->{ $table }->{$optional};
                            if ($optional =~ m/^params\.(\w+)$/) {
                                my $field = $1;
                                if (exists($all_params{ $field })) {
                                    if (ref($fd) eq 'HASH') {
                                        foreach my $keyword (keys %{ $fd }) {
                                            if ($keyword eq 'in') {
                                                $tables{$table} = 1;
                                                $where{"$table.$field"} = { -in => [ split(/\n/,$fd->{$keyword}) ] };
                                            }
                                        }
                                    }
                                    else {
                                        if ($fd =~ m/^params/) {
                                            $where{"$table.$field"} = $fd;
                                        }
                                        else {
                                            $where{"$table.$field"} = \"= $fd";
                                        }
                                        $tables{$table} = 1;
                                    }
                                }
                            }
                        }
                    }
                    debug to_dumper {where => \%where };
                }
            }
            foreach my $par (keys %where ) {
                my $val = $where{$par};
                debug to_dumper { par => $par, val => $val };
                if ($val =~ /^params\.(\w+)/) {
                    my $param = $1;
                debug to_dumper { param => $param, val => $val, all_params => \%all_params };
                    if (exists($all_params{ $val})) {
                        $where{$par} = $all_params{ $val };
                    }
                    if (exists($all_params{ $par})) {
                        $where{$par} = $all_params{ $par };
                    }
                    if (exists($all_params{ $param})) {
                        $where{$par} = $all_params{ $param };
                    }
                }
                elsif ( $val =~ m/^([^.]+)\.(\w+)/ ) {
                    my $table = $1;
                    my $column = $2;
                    $val =~ m/^([^.]+)\.(\w+)/;
                    my $table2 = $1;
                    my $column2 = $2;
                    
                }
            }
            debug to_dumper {where => \%where };
            debug to_dumper {qd => $qd,
                            update => \%to_pass };
          ($sql, @bind) = $sql_abs->update($qd->{table},
                                           \%to_pass, \%where);
          debug to_dumper {sql => $sql, bind => \@bind };
        }
        elsif ($qd->{type} eq 'select') {
            my %fields = ();
            my %tables = ();
            my %where = ();
          debug to_dumper {select => \%params };
            foreach my $table (keys %{ $qd->{table} }) {
                $tables{$table} = 1;
                unless ($query_config->{has_fields_selection}) {
                    foreach my $field (split(/\n/, $qd->{table}->{$table})) {
                        $fields{"$table.$field"} = 1;
                    }
                }
            }
            debug to_dumper { query_definition => $qd };
            if ($qd->{where}) {
                foreach my $table (keys %{ $qd->{where} }) {
                    if (exists($qd->{where}->{$table}->{required})) {
                        foreach my $field (keys %{ $qd->{where}->{ $table }->{required} }) {
                            my $fd = $qd->{where}->{ $table }->{required}->{$field};
                            if (ref($fd) eq 'HASH') {
                                foreach my $keyword (keys %{ $fd }) {
                                    if ($keyword eq 'in') {
                                        $tables{$table} = 1;
                                        $where{"$table.$field"} = { -in => [ split(/\n/,$fd->{$keyword}) ] };
                                    }
                                }
                            }
                            else {
                                if ($fd =~ m/^params/) {
                                    $where{"$table.$field"} = $fd;
                                }
                                else {
                                    $where{"$table.$field"} = \"= $fd";
                                }
                                $tables{$table} = 1;
                            }
                       } 
                    } 
                    debug to_dumper {where => \%where };
                    if (exists($qd->{where}->{ $table }->{optional})) {
                        foreach my $optional (keys %{ $qd->{where}->{ $table }->{optional} }) {
                            my $fd = $qd->{where}->{optional}->{ $table }->{$optional};
                            if ($optional =~ m/^params\.(\w+)$/) {
                                my $field = $1;
                                if (exists($all_params{ $field })) {
                                    if (ref($fd) eq 'HASH') {
                                        foreach my $keyword (keys %{ $fd }) {
                                            if ($keyword eq 'in') {
                                                $tables{$table} = 1;
                                                $where{"$table.$field"} = { -in => [ split(/\n/,$fd->{$keyword}) ] };
                                            }
                                        }
                                    }
                                    else {
                                        if ($fd =~ m/^params/) {
                                            $where{"$table.$field"} = $fd;
                                        }
                                        else {
                                            $where{"$table.$field"} = \"= $fd";
                                        }
                                        $tables{$table} = 1;
                                    }
                                }
                            }
                        }
                    }
                    debug to_dumper {where => \%where };
                }
            }
            my $source = [];
            debug to_dumper {where => \%where };
            debug to_dumper {params => \%params };
            debug to_dumper {all_params => \%all_params };
            foreach my $par (keys %where ) {
                my $val = $where{$par};
                debug to_dumper { par => $par, val => $val };
                if ($val =~ /^params\.(\w+)/) {
                    my $param = $1;
                debug to_dumper { param => $param, val => $val, all_params => \%all_params };
                    if (exists($all_params{ $val})) {
                        $where{$par} = $all_params{ $val };
                    }
                    if (exists($all_params{ $par})) {
                        $where{$par} = $all_params{ $par };
                    }
                    if (exists($all_params{ $param})) {
                        $where{$par} = $all_params{ $param };
                    }
                }
                elsif ( $val =~ m/^([^.]+)\.(\w+)/ ) {
                    my $table = $1;
                    my $column = $2;
                    $val =~ m/^([^.]+)\.(\w+)/;
                    my $table2 = $1;
                    my $column2 = $2;
                    
                }
            }
            debug to_dumper {where => \%where };
            if (scalar(keys( %tables)) > 1) {
                $source = [ keys %tables ];
            }
            else {
                $source = (keys( %tables ))[0];

            }
            debug to_dumper { where => \%where };
            $query_config->{where} = \%where;
#          ($sql, @bind) = $sql_abs->select(-from => $source,
#                                           -columns => [ keys %fields ],
#                                           -where => $query_config->{where},
#                                           -order => $query_config->{order}
#          [ keys %fields ], $query_config->{where}, $query_config->{order});

          ($sql, @bind) = $sql_abs->select($source, 
                                           [ keys %fields ],
                                           $query_config->{where},
                                           $query_config->{order});
          debug to_dumper { statement => $sql, where => $query_config->{where}, bind => \@bind, fields => \%fields, query_config => $query_config };
        }
    }
    else {
        return __error(code => HTTP_INTERNAL_SERVER_ERROR, msg => "Unknown query $query");
    }
    debug to_dumper { query => $query, sql => $sql, bind => \@bind };
    return ($sql, \@bind);
}
sub process_query_old {
    my @passed = @_;

    debug "In process_query";
#    my %query_modifiers = ();
    my $query = $passed[0]{ operationId };
    my $query_config = process_query_parameters();

#    unless (exists( $queries->{ $sql_source }->{ $query })) {
    unless (exists($config_queries->{$query})) {
        if (exists( $methods->{$query} )) {
            my $sub = TalApi->can( $query );
            debug "Calling Sub $query";

            return &$sub(params => \@_, query_config => $query_config );
        }
        else {
            return qq!{
                        "error": "unknown query $query"
                    }!;
        }
    }
    debug "Running query $query";
    my ($sql, $bind ) = __get_query_sql($query, query_config => $query_config );
    my $database = $config_queries->{$query}->{database};
    debug to_dumper { database => $database, config_queries => $config_queries->{$query}, query => $query, sql => $sql, bind => $bind,  };
    $database ||= 'mysql';
    return to_json __run_query( query => $query,
                                config => $config_queries->{$query},
                                database => $database,
                                sql => $sql,
                                bind => $bind,
                                );
}

=pod

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
    $params{bind} ||= ();
    debug to_dumper { __run_query => \%params };
    $params{config} ||= $config_queries->{ $params{query}};
    $params{database} ||= 'mysql';
    my $calc_rows_sql = $params{sql};
    $calc_rows_sql =~ s/select\s+/select SQL_CALC_FOUND_ROWS /mi;
    my $ret;
    my $sth;
    $params{limit} = -1 if $params{nolimit};

    my $limit = $params{limit} || 5;
    my $page = $params{page} || 1;
    my $pages = 1;
    my $last_row;
    my $row_count;
    if ($calc_rows_sql ne $params{sql}) {
        debug to_dumper { sql => $params{sql},
                          calc_rows_sql => $calc_rows_sql,
                          database => $params{database}};
        my $sth1 = $database_handles->{ $params{database} }->prepare($calc_rows_sql) or return __error(code => HTTP_INTERNAL_SERVER_ERROR, 
                                                                                           msg => $DBI::errstr);
        $sth1->execute(@{ $params{bind} }) or return __error(code => HTTP_INTERNAL_SERVER_ERROR, msg => $DBI::errstr);
        $row_count = $database_handles->{ $params{database} }->selectrow_array('SELECT FOUND_ROWS()');

#        $limit = $params{query_modifiers}{limit} || 5;
#        $page = $params{query_modifiers}{page} || 1;
        $last_row =$row_count;
        unless ( $limit == -1 ) {
            my $limit_offset = ($page * $limit) - $limit;
            $last_row = $limit_offset + $limit;

            my $limit_clause = " LIMIT $limit_offset, $limit";
            $params{sql} .= " $limit_clause";
        }
        debug to_dumper { sql => $params{sql}, bind => $params{bind} };
        $sth = $database_handles->{ $params{database} }->prepare($params{sql} );
        $ret = $sth->execute(@{ $params{bind} }) or return __error(code => HTTP_INTERNAL_SERVER_ERROR, msg => $DBI::errstr);
        $pages = int($sth->rows / $limit);
    }
    else {
        debug to_dumper { sql => $params{sql}, bind => $params{bind} };
        $sth = $database_handles->{ $params{database} }->prepare($params{sql} );
        $ret = $sth->execute(@{ $params{bind} })  or return __error(code => HTTP_INTERNAL_SERVER_ERROR, msg => $DBI::errstr);
        $row_count = 1;
        $last_row = $ret;
    }
    debug to_dumper { sql => $params{sql},
                       bind => $params{bind},
                    rows => $row_count };

    my %result = (
                    debug => { $params{database} => { $params{query} => { sql => $params{sql}, bind => $params{bind} } } },
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
            if (exists($params{config}{fromperl})) {
                my $type = ref($params{config}{fromperl});
                debug to_dumper  { fromperl => $params{config}{fromperl},
                                    type => $type };
                my $data;
                if ($type eq 'ARRAY') {
                    debug "An Array";
                    foreach my $fieldtoconvert (@{ $params{config}{fromperl} }) {
                        if (ref($fieldtoconvert) eq 'HASH') {
                            my @fields = values %{ $fieldtoconvert };
                            my $value = $row->{ $fields[0] };
                debug to_dumper  { value => $value };
                            eval $value;
                debug to_dumper  { data => $data };
                        }
                        else {
                    debug "Not A Hash";
                            
                        }
                    }
                }
                elsif ($type eq 'HASH') {
                    debug "A Hash";
                    my @fields = values %{ $params{config}{fromperl} };
        debug to_dumper  { fields => \@fields };
                    my $value = $row->{ $fields[0] };
        debug to_dumper  { value => $value };
                    eval $value;
                    
                }
                else {
                    debug "Neither and ARERAY nor a Hash - <$type>";
                }
            }
            if (exists($row->{tp_json_entry})) {
                my $decoded = from_json($row->{tp_json_entry});
                $row->{tp_json_entry} = $decoded;
            }
            push(@{ $result{data } }, $row);
        }
    }
    else {
        delete($result{pagination});
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
sub process_query_parameters {
    my %query_parameters = query_parameters->flatten;
    my $dbh = $database_handles->{'mysql'};
    my $has_fields_selection = 0;
    my $has_order_by = 0;
    my @fields = ();
    my %order = ();
    my %asc = ();
    my %desc = ();
    my %where = ();
    my %query_modifiers = ();
    my $limit = 5;
    my $page = 1;

    debug to_dumper { query_parameters => \%query_parameters };
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
            $asc{ $field } = $val if $val == 1;
            $desc{ $field } = $val if $val == -1;
            $has_order_by = 1;
            push(@{ $query_modifiers{orderby} }, "$field $direction");
        }
        elsif ($par =~ m/^like(\w+)/) {
            my $field = $1;
            $query_modifiers{where} ||= [];
            $where{ $field }{ -like } = $val;
            push(@{ $query_modifiers{where} }, qq!$field LIKE '$val'!);
        }
        elsif ($par =~ m/^between(\w+)/) {
            my $field = $1;
            my @values = split(',', $val);
            $query_modifiers{between} ||= [];
            $where{ $field }{ -between } = \@values;
            push(@{ $query_modifiers{where} }, qq!$field between '!.join("' AND '", @values)."'");
        }
        elsif ($par eq 'select') {
            @fields = split(',', $val);
            $has_fields_selection = 1;
            $query_modifiers{fields} = \@fields;
        }
        elsif ($par eq 'limit') {
            $limit = $val;
            $query_modifiers{$par} =  $val;
        }
        elsif ($par eq 'page') {
            $page = $val;
            $query_modifiers{$par} =  $val;

        }
        else {
            $query_modifiers{where} ||= [];
            if ($val =~ m/,/) {
                my @values = map {$dbh->quote($_) } split(',', $val);
                $where{ $par }{ -in } = \@values;
                push(@{ $query_modifiers{where} }, qq!$par IN !.'('. join(',', @values). ')');
            }
            elsif ($val =~ m/^>=/) { # tp_week_date=>=2017-09-21 ->  tp_week_date >= 2017-09-21
                $val = substr $val, 2;
                $where{ $par }{ '>=' } = $val;
                push(@{ $query_modifiers{where} }, qq!$par >= !.$dbh->quote($val));
            }
            elsif ($val =~ m/^>/) {  # tp_week_date=>2017-09-21  ->  tp_week_date > 2017-09-21
                $val = substr $val, 1;
                $where{ $par }{ '>' } = $val;
                push(@{ $query_modifiers{where} }, qq!$par > !.$dbh->quote($val));
            }
            elsif ($val =~ m/^<=/) { # tp_week_date=<=2017-09-21 ->  tp_week_date <= 2017-09-21
                $val = substr $val, 2;
                $where{ $par }{ '<=' } = $val;
                push(@{ $query_modifiers{where} }, qq!$par <= !.$dbh->quote($val));
            }
            elsif ($val =~ m/</) {   # tp_week_date=<2017-09-21  ->  tp_week_date < 2017-09-21
                $val = substr $val, 1;
                $where{ $par }{ '<' } = $val;
                push(@{ $query_modifiers{where} }, qq!$par < !.$dbh->quote($val));
            }
            else {
                push(@{ $query_modifiers{where} }, qq!$par = !.$dbh->quote($val)) if $par ne 'candId';
                $where{ $par } = $val;
            }
            delete($query_modifiers{where}) if scalar(@{ $query_modifiers{where} }) < 1;
        }
    } );
    my @order = ();

    push(@order, { '-asc' => [ keys %asc ]})  if scalar(keys %asc) > 0;
    push(@order, { '-desc' => [ keys %desc ]})  if scalar(keys %desc) > 0;
    return { fields => \@fields,
             has_fields_selection => $has_fields_selection,
             where => \%where,
             order => \@order,
             has_order_by => $has_order_by, 
             limit => $limit,
             page => $page,
             query_modifiers => \%query_modifiers };

}

sub GetMotd {
    return q!{ "id": "100", 
               "title": "ServerOutage",
               "message": "The System will be unavailable for 1 hour from midnight on 11/10/2017 for essential maintenance"
             }!;
};
sub choose_one {
    my @choices = @_;
    my $no = scalar(@choices);
    return $choices[ int(rand($no)) ];
}
=cut

true;
