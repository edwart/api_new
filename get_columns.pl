#!/usr/bin/env perl

use strict;
use warnings;
use feature 'say';
use DBI;
use JSON::DWIW;
use Data::Dumper;
my %db = (
            driver => 'mysql',
            database => 'Talisman_APItest',
            host => 'localhost',
            port => 3306,
            username => 'root',
            password =>'gemini2',
        );
my $table = shift or die "Usage: $0 <table_name>";
 
my $dsn = "DBI:mysql:database=$db{database};host=$db{host};port=$db{port}";
my $dbh = DBI->connect($dsn, $db{username}, $db{password}, {ShowErrorStatement => 1, 'RaiseError' => 1}) or die $DBI::errstr;
my $sql = qq!SELECT table_schema, column_name, column_default, is_nullable, data_type
             FROM INFORMATION_SCHEMA.COLUMNS 
             WHERE table_name = '$table'
             AND table_schema = 'Talisman_APITest2'!;

my $sth = $dbh->prepare($sql) or die DBI::errstr;
$sth->execute;
my %columns = ();
my %datatypes = ( 
                  smallint => { type => "integer", format => "int32", default => 0 },
                  int => { type => "integer", format => "int64", default => 0 },
                  tinyint => { type => "integer", format => "int32", default => 0 },
                  varchar => { type => "string", default => '""' },
                  mediumblob => { type => "string", default => '""'  },
                  blob => { type => "string", default => '""'  },
                  varchar => { type => "string", default => '""'  },
                  char => { type => "string", default => '""'  },
                  date => { type => "string", default => 'curdate()'  },
                  datetime => { type => "string", default => 'now()'  },
                  double =>  { type => "number", default => 0.0  },
                  enum =>  { type => "string", default => '""' },
                  decimal => { type => "number", default => 0.0 },
                  );
my @columns = ();
my @values = ();
while (my $row = $sth->fetchrow_hashref) {
    next if defined $row->{column_default};
    next if $row->{is_nullable} ne 'NO';
    push(@columns, $row->{column_name});
    push(@values, "<% params.$row->{column_name} %>");

    $columns{ $row->{column_name} } = { %{ $datatypes{ $row->{ data_type } } } };
}
my $string = "INSERT INTO timepool (";
my $joinon = ",\n". ' ' x length($string);
say 'INSERT INTO timepool (', join($joinon, @columns), ")\nVALUES\n(\n", join($joinon, @values), ")\n";
my $json_obj = JSON::DWIW->new( { pretty => 1 });
my $json =  $json_obj->to_json( \%columns );
#say "$json,";
=pod

foreach my $col (sort keys %columns) {
    my %data = ( $col => $columns{$col} );
    my $json =  $json_obj->to_json( \%data ) or warn JSON::DWIW::get_error_string();
    say "$json,";
}

=cut

 
