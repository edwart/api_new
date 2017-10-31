#!/usr/bin/env perl
use feature 'say';
use strict;
use warnings;
use Data::Dumper;
use Data::Printer;
use DateTime;
use Carp::Always;
use DateTime;
use DateTime::Event::Recurrence;
$Data::Dumper::Sortkeys = 1;
use JSON::DWIW;
use SQL::Abstract;
use Data::Rand;
use DBI;
our $json_obj = JSON::DWIW->new;
my $database = 'Talisman_APITest4';
my $hostname = 'localhost';
my $port = 3306;
my $user = 'root';
my $password = 'gemini2';
my $dsn = "DBI:mysql:database=$database;host=$hostname;port=$port";
my $dbh = DBI->connect($dsn, $user, $password, { RaiseError => 1, AutoCommit => 1, ShowErrorStatement => 1 } );
our %columns = ();
our  %tables = ();
our %bookings = ();
$dbh->do("delete from timepool");
my $sth_book = $dbh->prepare("SELECT * from bookings
                              LEFT JOIN xbookings ON bookings.oa_booking_no = xbookings.xoa_booking_no
                              LEFT JOIN slclient  ON bookings.oa_cust_code = slclient.cu_cust_code") or die $DBI::errstr;
$sth_book->execute or die $DBI::errstr;
while (my $row = $sth_book->fetchrow_hashref) {
    $bookings{ $row->{oa_booking_no} } = { %{ $row } };
}
foreach my $table (qw/timecard timehist timepool/) {
    get_columns($table);
}
my $sth_ratecodes = $dbh->prepare("select rc_payrate_no,
                                        rc_pay_type,
                                        rc_pay_tax,
                                        rc_pay_vatonly,
                                        rc_pay_factor,
                                        rc_pay_desc,
                                        rc_rate_desc,
                                        rc_pay_spec,
                                        rc_pay_rate,
                                        rc_inv_vattype,
                                        rc_inv_vatonly,
                                        rc_inv_factor,
                                        rc_inv_rate,
                                        rc_factor_code,
                                        rc_hrs_day
                                   from ratecode")  or die $DBI::errstr;
$sth_ratecodes->execute or die $DBI::errstr;

my %ratecodes = ();
while (my $row = $sth_ratecodes->fetchrow_hashref) {
    $ratecodes{ $row->{rc_payrate_no} } = { %{ $row } };
}
my $sql = SQL::Abstract->new;
my $sth = $dbh->prepare('select * from timecard order by tc_booking_no, tc_workwkend asc') or die $DBI::errstr;
$sth->execute;

my $today = DateTime->today->ymd('-');
my $now = DateTime->now->hms(':');
my $lastrecord = undef;
my $last_workwkend = undef;
my $last_workweek = undef;
my $last_tp_json_entry = undef;
while ( my $timecard = $sth->fetchrow_hashref ) {


    if (defined($lastrecord)) {
        $timecard->{tc_workweek}++;
        $timecard->{tc_workwkend} =~ m/(\d{4})-(\d{2})-(\d{2})/;
        my ($year, $month, $day)  = ($1, $2, $3);
        my $dt = DateTime->new(day => $day, month => $month, year => $year);
        $timecard->{tc_workweek}++;
        $timecard->{tc_workwkend} = $dt->add( days => 7)->ymd('-');
        warn Dumper { timecard => $timecard };
    }

    $timecard->{tc_surname} ||= "unknown";
#
#    say Dumper $timecard;
    my %record = (
        tp_json_accept => "Y",
        tp_week_date => $timecard->{tc_workwkend},
        tp_amend_by => "script",
        tp_amend_on => $today,
        tp_amend_at => $now,
        tp_xfer_date => $today,
        tp_cost_centre => "unknown",
        tp_branch => $timecard->{tc_oa_branch},
        tp_source => "timecard",
        tp_extranet_status => "Entered",
        tp_week_no_V => $timecard->{tc_workweek},
        tp_error => "none",
        tp_client_code => "unknown",
        tp_recvd_date => $timecard->{tc_enter_date},
        tp_serial_code => $timecard->{tc_in_serno},
        tp_hours_tot_V => $timecard->{tc_hour_total},
        tp_process_level => "unknown",
        tp_batch_no => "unknown",
        tp_imago_id => $timecard->{tc_image_no},
        tp_surname => $timecard->{tc_surname} || "unknown",
        tp_client_code_V => "unknown",
        tp_json_entry => "",
        tp_payroll_no_V => $timecard->{tc_payroll_no},
        tp_type_V => $timecard->{tc_or_type},
        tp_surname_V => $timecard->{tc_surname},
        tp_type => $timecard->{tc_or_type},
        tp_booking_no => $timecard->{tc_booking_no},
        tp_not_working => "0",
        tp_custref => $timecard->{tc_custref},
        tp_booking_no_V => $timecard->{tc_booking_no},
        tp_week_no => $timecard->{tc_workweek},
    );
    my $tp_json_entry = { 
                          week_rate_total_hours => $timecard->{tc_hour_total},
                          week_rate_total_units => 0,
                          week_rate_total_days => 0,
                          status_history => {
                                                entered => { amended_by => $timecard->{tc_entered_by},
                                                             amended_on => $timecard->{tc_enter_date} }
                                            },
                        };


    if (defined($lastrecord)) {
#        if (($timecard->{tc_workweek} - $lastrecord->{tc_workweek}) == 1) {
            $tp_json_entry->{has_lastweek} = 1;
            say Dumper { lastweek => $lastrecord };
            $tp_json_entry->{lastweek} = $lastrecord->{tp_json_entry}->{days};
        #}
        #else {
            #$tp_json_entry->{has_lastweek} = 0;
        #}
    }
    else {
        $tp_json_entry->{has_lastweek} = 0;
        $tp_json_entry->{lastweek} = {};
    }


    my $booking = $bookings{ $timecard->{tc_booking_no} };
    my %booking_ratecodes = ();
    for (my $rcno = 1; $rcno<9; $rcno++) {
        if (defined($booking->{"oa_payrate_no__${rcno}"}) and $booking->{"oa_payrate_no__${rcno}"} > 0) {
            $booking_ratecodes{ $booking->{"oa_payrate_no__${rcno}"} } = $booking->{"oa_rate_hours__${rcno}"};
        }
    }
    say Dumper { booking_rates_codes => \%booking_ratecodes };
    my @allowed_rates = ();
    for (my $rcno = 1; $rcno<9; $rcno++) {
        if ($timecard->{"tc_rate_code__${rcno}"} != 0) {
            my $ratecode = $ratecodes{ $timecard->{"tc_rate_code__${rcno}"} };
            next if $ratecode->{rc_hrs_day} = 0;
            my $limit = $booking_ratecodes{ $ratecode->{rc_payrate_no} };
            if ($limit == 0) {
                $limit = choose_one(7,8,9,10,11,12) if $ratecode->{rc_pay_type} eq 'hours';
                $limit = 1 if $ratecode->{rc_pay_type} eq 'days';
            }
            my %ar = ( 
                        payrate_no => $ratecode->{rc_payrate_no},
                        hours => $ratecode->{rc_hrs_day},
                        limit => $limit,
                        pay_type => $ratecode->{rc_pay_type},
                        pay_rate => $ratecode->{rc_pay_rate},
                        inv_rate => $ratecode->{rc_inv_rate},
                        rate_desc => $ratecode->{rc_rate_desc},
                        );
            push(@allowed_rates, { %ar });
        }
    }
    next if scalar(@allowed_rates) < 1;
    say Dumper { allowed => \@allowed_rates };
    $tp_json_entry->{allowed_rates} = [ @allowed_rates ];
    my $tc_workwkend = $timecard->{tc_workwkend};
#    say Dumper { tc_workwkend => $tc_workwkend };
    $timecard->{tc_workwkend} =~ m/^(\d{4})-(\d{2})-(\d{2})/;
    my ($year, $month, $day) = ($1, $2, $3);
    my $weekend = DateTime->new(year => $year, month => $month, day => $day);
    my $we2 = DateTime->new(year => $year, month => $month, day => $day);
#    say Dumper { weekend => $weekend->ymd('-') };
    my $weekstart = $we2->subtract(days => 6);
#    say Dumper { weekstart => $weekstart->ymd('-'),
#                 weekend => $weekend->ymd('-') };
    my $daysofweek = get_dates($weekstart, $weekend);
#    say Dumper { daysofweek => $daysofweek };

    my $total_hours = $timecard->{tc_hour_total};
    next if $total_hours < 1;
    my $hours_per_day = int($total_hours/7);
    my $hours_last_day = $total_hours - ($hours_per_day * 7) + $hours_per_day;
    say Dumper { total_hours => $total_hours,
                 hours_per_day => $hours_per_day,
                hours_last_day => $hours_last_day };
    my @days = ();
    for (my $dow=0; $dow<7; $dow++) {
        my %day = ( date => $daysofweek->[$dow] );
        my @rates = ();
        for (my $arno = 0; $arno< scalar(@allowed_rates); $arno++) {
            my $qty = $hours_per_day;
            $qty += $hours_last_day if $dow == 6;
            say Dumper { qty => $qty,
                        arno => $arno };

            push(@rates, { code => $allowed_rates[$arno]->{payrate_no},
                            quantity => $qty });
        }
#        say Dumper { rates => \@rates };
        $day{ rates} = [ @rates ];
#        say Dumper { day => \%day };
        push(@days, { %day });
#        say Dumper { days => \@days };
    }
    say Dumper { days => \@days };
    $tp_json_entry->{days} = [ @days ];
    @days = ();
    $lastrecord = { %record };
    $lastrecord->{tp_json_entry} = $tp_json_entry;
    $record{tp_json_entry} = $json_obj->to_json($tp_json_entry);
    warn Dumper { record => \%record };
    my($stmt, @bind) = $sql->insert('timepool',\%record );
    warn Dumper { statement => $stmt, params => scalar(@bind), bind => \@bind };
    insert_row($stmt, \@bind);
   
}
$sth->finish;

$sth = $dbh->prepare('select * from timehist') or die $DBI::errstr;
$sth->execute;

=pod

while ( my $timehist = $sth->fetchrow_hashref ) {

    #say Dumper $timehist;
    my %record = (
        tp_json_accept => "Y",
        tp_week_date => $timehist->{th_workwkend},
        tp_amend_by => "script",
        tp_amend_on => $today,
        tp_amend_at => $now,
        tp_xfer_date => $today,
        tp_cost_centre => "unknown",
        tp_branch => $timehist->{th_oa_branch},
        tp_source => "timehist",
        tp_extranet_status => "Entered",
        tp_week_no_V => $timehist->{th_workweek},
        tp_error => "none",
        tp_client_code => "unknown",
        tp_recvd_date => $timehist->{th_enter_date},
        tp_serial_code => $timehist->{th_in_serno} || 0,
        tp_hours_tot_V => $timehist->{th_hour_total} || 0,
        tp_process_level => "unknown",
        tp_batch_no => "unknown",
        tp_imago_id => $timehist->{th_image_no} || 0,
        tp_surname => $timehist->{th_surname},
        tp_client_code_V => "unknown",
        tp_json_entry => "",
        tp_payroll_no_V => $timehist->{th_payroll_no},
        tp_type_V => $timehist->{th_or_type},
        tp_surname_V => $timehist->{th_surname},
        tp_type => $timehist->{th_or_type},
        tp_booking_no => $timehist->{th_booking_no},
        tp_not_working => "0",
        tp_custref => $timehist->{th_custref} || 'unknown',
        tp_booking_no_V => $timehist->{th_booking_no},
        tp_week_no => $timehist->{th_workweek},
    );
    my $tp_json_entry = { 
                          week_rate_total_hours => $timehist->{th_hour_total},
                          week_rate_total_units => 0,
                          week_rate_total_days => 0,
                          loaded_previous_week => 0,
                          status_history => {
                                                entered => { amended_by => $timehist->{th_entered_by},
                                                             amended_on => $timehist->{th_enter_date} }
                                            },
                        };
    my $booking = $bookings{ $timehist->{th_booking_no} };
    my %booking_ratecodes = ();
    for (my $rcno = 1; $rcno<9; $rcno++) {
        if (defined($booking->{"oa_payrate_no__${rcno}"}) and $booking->{"oa_payrate_no__${rcno}"} > 0) {
            $booking_ratecodes{ $booking->{"oa_payrate_no__${rcno}"} } = $booking->{"oa_rate_hours__${rcno}"};
        }
    }
    say Dumper { booking_rates_codes => \%booking_ratecodes };
    my @allowed_rates = ();
    for (my $rcno = 1; $rcno<9; $rcno++) {
        if ($timehist->{"th_rate_code__${rcno}"} != 0) {
            my $ratecode = $ratecodes{ $timehist->{"th_rate_code__${rcno}"} };
            my $limit = $booking_ratecodes{ $ratecode->{rc_payrate_no} };
            if ($limit == 0) {
                $limit = choose_one(7,8,9,10,11,12) if $ratecode->{rc_pay_type} eq 'hours';
                $limit = 1 if $ratecode->{rc_pay_type} eq 'days';
            }
            my %ar = ( 
                        payrate_no => $ratecode->{rc_payrate_no},
                        hours => $ratecode->{rc_hrs_day},
                        limit => $limit,
                        pay_type => $ratecode->{rc_pay_type},
                        pay_rate => $ratecode->{rc_pay_rate},
                        inv_rate => $ratecode->{rc_inv_rate},
                        rate_desc => $ratecode->{rc_rate_desc},
                        );
    say Dumper { allowed_rate => \%ar, ratecode => $ratecode };
            push(@allowed_rates, { %ar });
        }
    }
    say Dumper { allowed => \@allowed_rates };
    $tp_json_entry->{allowed_rates} = [ @allowed_rates ];
    my $th_workwkend = $timehist->{th_workwkend};
#    say Dumper { th_workwkend => $th_workwkend };
    $timehist->{th_workwkend} =~ m/^(\d{4})-(\d{2})-(\d{2})/;
    my ($year, $month, $day) = ($1, $2, $3);
    my $weekend = DateTime->new(year => $year, month => $month, day => $day);
    my $we2 = DateTime->new(year => $year, month => $month, day => $day);
    say Dumper { weekend => $weekend->ymd('-') };
    my $weekstart = $we2->subtract(days => 6);
#    say Dumper { weekstart => $weekstart->ymd('-'),
#                 weekend => $weekend->ymd('-') };
    my $daysofweek = get_dates($weekstart, $weekend);
#    say Dumper { daysofweek => $daysofweek };
    my $total_hours = $timehist->{th_hour_total};
    $total_hours ||= 0;
    my $hours_per_day = int($total_hours/7);
    my $hours_last_day = $total_hours - ($hours_per_day * 7) + $hours_per_day;
#    say Dumper { total_hours => $total_hours,
#                 hours_per_day => $hours_per_day,
#                hours_last_day => $hours_last_day };
    my @days = ();
    for (my $dow=0; $dow<7; $dow++) {
        my %day = ( date => $daysofweek->[$dow] );
        my @rates = ();
        for (my $arno = 0; $arno< scalar(@allowed_rates); $arno++) {
            my $qty = $hours_per_day;
            $qty += $hours_last_day if $dow == 6;
#            say Dumper { qty => $qty,
#                        arno => $arno };

            push(@rates, { code => $allowed_rates[$arno]->{payrate_no},
                            quantity => $qty });
        }
#        say Dumper { rates => \@rates };
        $day{ rates} = [ @rates ];
#        say Dumper { day => \%day };
        push(@days, { %day });
#        say Dumper { days => \@days };
    }
#    say Dumper { days => \@days };
    $tp_json_entry->{days} = [ @days ];
    @days = ();
    $record{tp_json_entry} = $json_obj->to_json($tp_json_entry);
    $record{tp_surname} ||= "unknown";
    $record{tp_surname_V} ||= "unknown";
    $record{tp_type} ||= "unknown";
    $record{tp_type_V} ||= "unknown";
    my($stmt, @bind) = $sql->insert('timepool',\%record );
    say Dumper { statement => $stmt, bind => \@bind };
    insert_row($stmt, \@bind) or die $! ;
   
}
$sth->finish;
#my($stmt, @bind) = $sql->insert('timepool',\@fields );
#say Dumper $stmt;

=cut

sub insert_row {
    my ($sql, $bind, $sth) = @_;
    $sth ||= $dbh->prepare($sql) or die $DBI::errstr;
    $sth->execute(@{ $bind }) or die $DBI::errstr;

}

sub get_columns {
    my ($table) = @_;
    my $sth = $dbh->prepare("SHOW FULL COLUMNS IN $table") or die $DBI::errstr;
    $sth->execute() or die $DBI::errstr;
    while (my $row = $sth->fetchrow_hashref) {
        my $field = $row->{Field};
        $field =~ m/^([^_]+)_(.*$)/;
        my $prefix = $1;
        my $fieldname = $2;

        $columns{ $fieldname }{ $table } = $prefix;
        $tables{ $table }{ $field } = $row;
    }
    $sth->finish;
}
sub get_dates {
    my ($dt_start, $dt_end) = @_;
    my $der = DateTime::Event::Recurrence->daily;
    my @dates = ();
    push(@dates, $_->ymd('-')) for $der->as_list( start => $dt_start, end => $dt_end );
    return \@dates;
}
sub choose_one {
    my @choices = @_;
    my $no = scalar(@choices);
    return $choices[ int(rand($no)) ];
}
