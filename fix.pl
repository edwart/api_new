#!/usr/bin/env perl
use feature 'say';
use strict;
use warnings;
use Data::Dumper;
use JSON::DWIW;
use DBI;
my $database = 'Talisman_APITest2';
my $hostname = 'localhost';
my $port = 3306;
my $user = 'root';
my $password = 'gemini2';
my $dsn = "DBI:mysql:database=$database;host=$hostname;port=$port";
my $dbh = DBI->connect($dsn, $user, $password, { RaiseError => 1, AutoCommit => 1 } );

my $sth = $dbh->prepare('SELECT * from timepool') or die $DBI::errstr;
my $sth2 = $dbh->prepare('UPDATE timepool set tp_json_entry = ? WHERE tp_timesheet_no = ?') or die $DBI::errstr; 
$sth->execute or die $DBI::errstr;
my $json_obj = JSON::DWIW->new;
while (my $row = $sth->fetchrow_hashref) {
    my $data = $json_obj->from_json($row->{tp_json_entry});
    $data->{week_rate_total_days} ||= 0;
    $data->{week_rate_total_hours} ||= 0;
    $data->{week_rate_total_units} ||= 0;
    $row->{tp_json_entry} = $json_obj->to_json($data);
    say Dumper { row => $row, data => $data };
    $sth2->execute($row->{tp_json_entry}, $row->{tp_timesheet_no}) or die $DBI::errstr;
    $sth2->finish;
}
$sth->finish;
