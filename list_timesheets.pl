#!/usr/bin/env perl
use feature 'say';
use strict;
use warnings;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use JSON::DWIW;
use DBI;
our $json_obj = JSON::DWIW->new;
my $database = 'Talisman_APITest4';
my $hostname = 'localhost';
my $port = 3306;
my $user = 'root';
my $password = 'gemini2';
my $dsn = "DBI:mysql:database=$database;host=$hostname;port=$port";
my $dbh = DBI->connect($dsn, $user, $password, { RaiseError => 1, AutoCommit => 1 } );

my $sth_timepool = $dbh->prepare('SELECT * from timepool') or die $DBI::errstr;
$sth_timepool->execute();
my @existing = ();
while (my $row = $sth_timepool->fetchrow_hashref) {
    my $tp_json_entry = $json_obj->from_json($row->{tp_json_entry});
    $row->{tp_json_entry} = $tp_json_entry;
    say Dumper { timesheet => $row };
}
$sth_timepool->finish;
