package TalApi;
use strict;
use warnings;

use Dancer2;
use Dancer2::Plugin::OpenAPI;
use Dancer2::Plugin::Database;
use Data::Dumper;
use YAML::XS 'LoadFile';
use Path::Tiny;
use FindBin qw/ $Bin /;
use File::Basename qw/ dirname /;
use SQL::Library;
use SQL::Beautify;
use Template;
#set serializer => 'JSON';

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

    template 'timesheet.tt', { timesheets => $data };
};
=pod
post '/createtimesheet' => sub {
    debug 'In createtimesheet post';
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
    return to_json __run_query( query => 'createtimesheet,
                        sql => $sql,
                        query_params => \%query_parameters,
                        route_params => \%route_parameters,
                        body_params => \%body_parameters,
                        query_modifiers=> \%query_modifiers,
                        );
                     
    
};
=cut
sub GetApiVersionInfo {
    debug to_dumper $apiconfig;
    return to_json $apiconfig->{info};
}
sub GetBookingTimesheets {
    my @passed = @_;
    my %query_parameters = query_parameters->flatten;
    my %route_parameters = route_parameters->flatten;
    my %body_parameters = body_parameters->flatten;
    my %query_modifiers = ();
    $query_parameters{candId} ||= 10240;
    my $ratecodes = __run_query( query => 'GetBookingRateCodes',
                        query_params => \%query_parameters,
                        route_params => \%route_parameters,
                        body_params => \%body_parameters,
                        query_modifiers=> \%query_modifiers,
                        );
    return to_json $ratecodes;
}
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
                "OK": "It wiorked !"
            }';

}
sub process_query {
    my @passed = @_;

    my %query_parameters = query_parameters->flatten;
    my %route_parameters = route_parameters->flatten;
    my %body_parameters = body_parameters->flatten;
    my $query = $passed[0]{ operationId };
    my $sql_source = $sql_sources->{ $query } || $sql_sources->{ default };
    my $dbh = $database_handles->{ $sql_source };

    unless (exists( $queries->{ $sql_source }->{ $query })) {
        if (exists( $methods->{$query} )) {
            my $sub = TalApi->can( $query );

            return &$sub(@_);
        }
        else {
            return '{
                        "error": "unknown query $query"
                    }';
        }
    }
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
=pod

    if ($query_modifiers{page} and !$query_modifiers{limit} )  {
        return '{
                    "error": "you must supply a limit if you suppply a page"
                }';
    }   

=cut
        

    debug to_dumper { query_modifiers=> \%query_modifiers };
    my $quoted_pars = __quote_params({ %route_parameters, %query_parameters, %body_parameters });
    debug to_dumper { params=> $quoted_pars  };
    $tt->process(\$preprocessed, { params => $quoted_pars,
                                   modifiers => \%query_modifiers}, \$sql) or die $tt->error;
    $sql =~ s/\s*$//;
    debug to_dumper {postprocessed => $sql };
    my $beautified = $sql_beautifier->query($sql);
    my $nice_sql = $sql_beautifier->beautify;

    debug to_dumper { nice_sql =>$nice_sql, preprocessed => $preprocessed, params => \%query_parameters, modifiers => \%query_modifiers, sql => $sql, passed => \@passed, query => $query };
    

    return to_json __run_query( query => $query,
                        sql => $sql,
                        nice_sql => $nice_sql,
                        query_params => \%query_parameters,
                        route_params => \%route_parameters,
                        body_params => \%body_parameters,
                        query_modifiers=> \%query_modifiers,
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
    my $calc_rows_sql = $params{sql};
    $calc_rows_sql =~ s/select\s+/select SQL_CALC_FOUND_ROWS /mi;
    debug to_dumper { sql => $params{sql},
                      calc_rows_sql => $calc_rows_sql };
    my $sth1 = $database_handles->{ mysql }->prepare($calc_rows_sql) or warn $DBI::errstr;
    $sth1->execute() or debug "execute failed";
    my $row_count = $database_handles->{ mysql }->selectrow_array('SELECT FOUND_ROWS()');
    
    my $limit = $params{query_modifiers}{limit} || 5;
    my $page = $params{query_modifiers}{page} || 1;
    my $limit_offset = ($page * $limit) - $limit + 1;
    my $last_row = $limit_offset + $limit;

    my $limit_clause = " LIMIT $limit_offset, $limit";
    $params{sql} .= " $limit_clause";
    debug to_dumper { sql => $params{sql} };
    my $sth = $database_handles->{ mysql }->prepare($params{sql} );
    my $ret = $sth->execute() or debug "execute failed";
    debug to_dumper { sql => $params{sql},
                      rows => $row_count,
                      calc_rows_sql => $calc_rows_sql };

    my %result = (  
                    debug => { sql => $params{sql} },
                    pagination => { total => $row_count },
                    status => defined $ret ? 0 : $sth->errstr,
                    data => [],
                    );
    my $pages = int($sth->rows / $limit);
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
true;
