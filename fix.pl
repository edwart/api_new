#!/usr/bin/env perl
use feature 'say';
use strict;
use warnings;
use Data::Dumper;
use DateTime;
use DateTime::Event::Recurrence;
use Carp::Always;
$Data::Dumper::Sortkeys = 1;
use JSON::DWIW;
use Data::Rand;
use DBI;
our $json_obj = JSON::DWIW->new;
my $database = 'Talisman_APITest2';
my $hostname = 'localhost';
my $port = 3306;
my $user = 'root';
my $password = 'gemini2';
my $dsn = "DBI:mysql:database=$database;host=$hostname;port=$port";
my $dbh = DBI->connect($dsn, $user, $password, { RaiseError => 1, AutoCommit => 1 } );
our %ratecodes = ();

my $sth_rates = $dbh->prepare('SELECT * from ratecode ORDER BY rc_payrate_no');
$sth_rates->execute;
while (my $row = $sth_rates->fetchrow_hashref) {
    $ratecodes{ $row->{rc_payrate_no} } = { %{ $row } };
}
#say Dumper  \%ratecodes;

my $sth_timepool = $dbh->prepare('SELECT * from timepool') or die $DBI::errstr;
$sth_timepool->execute();
# my $sth2 = $dbh->prepare('UPDATE timepool set tp_json_entry = ? WHERE tp_timesheet_no = ?') or die $DBI::errstr; 
#$sth->execute or die $DBI::errstr;
my %existing_timesheets = ();
my %existing_timesheets2 = ();
while (my $row = $sth_timepool->fetchrow_hashref) {
    my $tp_json_entry = $json_obj->from_json($row->{tp_json_entry});
    next if scalar(@{ $tp_json_entry->{allowed_rates} }) < 1;
     
    $existing_timesheets{ $row->{tp_booking_no} } { $row->{tp_week_date} } = { %{ $row } };
    $existing_timesheets2{ $row->{tp_booking_no} } { $row->{tp_week_date} } = 1;
}
say Dumper { existing_timesheets => \%existing_timesheets2 };
my $sth_bookings = $dbh->prepare(qq!
select bookings.*
from bookings, timepool
WHERE bookings.oa_booking_no = timepool.tp_booking_no
!);
$sth_bookings->execute();
while (my $row = $sth_bookings->fetchrow_hashref) {
    next if $row->{oa_date_start} eq '0000-00-00';
    $row->{oa_date_end} = DateTime->today->ymd('-') if $row->{oa_date_end} eq '0000-00-00';
    my $fridays = __get_fridays($row->{oa_date_start}, $row->{oa_date_end});
    foreach my $friday (@{ $fridays }) {
#        say Dumper { row => $row };
        if (exists( $existing_timesheets{ $row->{oa_booking_no} } {$friday})) {
            say "Updating $row->{oa_booking_no} on $friday";
#            say Dumper { existing_timesheets => $existing_timesheets{ $row->{oa_booking_no} } {$friday} };
            update_timesheet(bookingno => $row->{oa_booking_no}, weekenddate => $friday, existing_data => $existing_timesheets{ $row->{oa_booking_no} } {$friday});
        }
#        else {
#            create_timesheet($row->{oa_booking_no}, $friday );
#        }
    }
}

sub update_timesheet {
    my %params = @_;
    my $data = $params{existing_data};
    my $json_entry = $json_obj->from_json( $data->{tp_json_entry} );
    my $allowed_rates = $json_entry->{allowed_rates};
    return if scalar(@{ $allowed_rates }) < 1;
    $json_entry->{week_rate_total_days} = 0;
    $json_entry->{week_rate_total_hours} = 0;
    $json_entry->{week_rate_total_units} = 0;
    my %rates = ();
    my @days = ( 0, 0.25, 0.5, 0.75, 1.0) ;
    my @statuses = ("Entered",
                    "Completed",
                    "Paid",
                    "Awaiting entry",
                    "Awaiting authorization",
                    "Queried");
    my @who = ("John Doe", "Someone Else", "The Boss", "Someone Important");
    my $tp_extranet_status = $statuses[ int(rand(6)) ];
    $json_entry->{status_history} = {};
    for (my $n = 0; $n <= $status_ind; $n++) {
        my $status = $statuses[ $n ];
        $json_entry->{status_history}->{ $status } = { amended_on => DateTime->today->subtract( days => int(rand(30)))->ymd('-'),
                                                       amended_by => $who[ int(rand(4)) ] };
    }

    for( my $dayno = 0; $dayno < scalar(@{ $json_entry->{days} }); $dayno++) {
        my $day = $json_entry->{days}[$dayno];
#        delete($json_entry->{days}[$dayno]{quantity});
        for (my $rateno = 0; $rateno < scalar(@{ $allowed_rates }); $rateno++) {
            my $rate = $allowed_rates->[$rateno];
#        foreach my $rate (@{ $allowed_rates }) {
            my $rc = $ratecodes{$rate->{payrate_no}};
            if ($rc->{rc_pay_type} eq 'hours') {
                my $rand = int(rand(9));
                $json_entry->{days}[$dayno]->{rates}->[$rateno]->{quantity} = $rand;
#                say Dumper { rand => $rand, dayno => $dayno, day => $json_entry->{days}[$dayno] };
                $json_entry->{week_rate_total_hours} += $rand;
            }
            if ($rc->{rc_pay_type} eq 'days') {
                my $rand = $days[ int(rand(5))];
                $json_entry->{days}[$dayno]->{rates}->[$rateno]->{quantity} = $rand;
#                say Dumper { rand => $rand, dayno => $dayno, day => $json_entry->{days}[$dayno] };
                $json_entry->{week_rate_total_days} += $rand;
            }
            if ($rc->{rc_pay_type} eq 'units') {
                my $rand = int(rand(200));
                $json_entry->{days}[$dayno]->{rates}->[$rateno]->{quantity} = $rand;
#                say Dumper { rand => $rand, dayno => $dayno, day => $json_entry->{days}[$dayno] };
                $json_entry->{week_rate_total_units} += $rand;
            }
        }
    }
    my $sth = $dbh->prepare('UPDATE timepool set tp_extranet_status = ?, tp_amend_by = "fix.pl", tp_amend_at = CURTIME(), tp_amend_on = CURDATE(), tp_json_entry = ? WHERE tp_timesheet_no = ?') or die $DBI::errstr; 

    my $tp_json_entry = $json_obj->to_json($json_entry);
    say Dumper { status => $tp_extranet_status,
                 data => $json_entry,
                 json => $tp_json_entry };
    
    $sth->execute($tp_extranet_status,
                  $tp_json_entry,
                  $data->{tp_timesheet_no}) or die $DBI::errstr;



}

=pod

sub create_timesheet {
    my (%params) = @_;

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
        );
    my $today = DateTime->today->ymd('-');
    my  $data = { 
                tp_amend_by => 'script',
                tp_amend_on => "$today",
                tp_batch_no => 0,
                tp_branch => 0,
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
                tp_xfer_date => "$today",
            };
 my $sth2 = $dbh->prepare('INSERT INTO timepool') or die $DBI::errstr; 
    while (my $row = $sth->fetchrow_hashref) {
        my $data = $json_obj->from_json($row->{tp_json_entry});
        my $week_rate_total_days = 0;
        my $week_rate_total_hours = 0;
        my $week_rate_total_units = 0;
    #    foreach my $day (@{ $data->{days} }) {
    #        foreach my $rate (@{ $day->{rates}
    #    }

        $data->{week_rate_total_days} = $week_rate_total_days;
        $data->{week_rate_total_hours} = $week_rate_total_hours;
        $data->{week_rate_total_units} = $week_rate_total_units;
        $row->{tp_json_entry} = $json_obj->to_json($data);
        say Dumper { row => $row, data => $data };
    #    $sth2->execute($row->{tp_json_entry}, $row->{tp_timesheet_no}) or die $DBI::errstr;
    #    $sth2->finish;
    }
    $sth->finish;
}

=cut

sub __get_fridays {
    my ($from_date, $to_date) = @_;
    my ($year, $month, $day) = split('-',$from_date);
    $to_date = DateTime->today->ymd('-');
    my ($toyear, $tomonth, $today) = split('-',$to_date);

    my $dt_start = DateTime->new(year => $year, month => $month, day => $day);
    my $dt_end = DateTime->new(year => $toyear, month => $tomonth, day => $today);
    my $der = DateTime::Event::Recurrence->weekly(days => 5);
    my @dates = ();
    push(@dates, $_->ymd('-')) for $der->as_list( start => $dt_start, end => $dt_end );
    return \@dates;
}
