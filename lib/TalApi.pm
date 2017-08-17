package TalApi;
use strict;
use warnings;

use Dancer2;
use Dancer2::Plugin::OpenAPI;
use Dancer2::Plugin::Database;
use YAML::XS 'LoadFile';
use FindBin qw/ $Bin /;
use File::Basename qw/ dirname /;
use SQL::Library;
use Template;
set serializer => 'JSON';

my $config              = config;
my $methods             = __get_list_of_methods();
my $database_handles    = __get_db_handles();
my $queries             = __get_queries();
my $sql_sources         = __get_sql_sources();
my $apiconfig           = OpenAPI->get_apiconfig;
my $tt = new Template;

our $VERSION = '0.1';

sub process_query {
    my @passed = @_;

    my %params = params;
    my $route_parameters = route_parameters;
    my $body_parameters = body_parameters;
    my $query = $passed[0]{ operationId };
    my $sql_source = $sql_sources->{ $query } || $sql_sources->{ default };

    unless (exists( $queries->{ $sql_source }->{ $query })) {
        return '{
                    "error": "unknown query $query"
                }';
    }
    my $sql = undef;
    my $preprocessed = $queries->{ $sql_source }->{ $query };
    $tt->process(\$preprocessed, \%params, \$sql) or die $tt->error;
    debug to_dumper { preprocessed => $preprocessed, params => \%params, sql => $sql, passed => \@passed, query => $query };
    Log::Log4perl->get_logger('SQL')->info($sql);

    Log::Log4perl->get_logger('SQL')->info($sql);
    return __run_query( query => $query,
                        sql => $sql,
                        params => \%params,
                        route_params => $route_parameters->get_all,
                        body_params => $body_parameters->get_all );

}
sub __get_list_of_methods {
    my %methods = ();
    foreach my $name (keys %TalApi::) {
        next if $name =~ m/^__/;
        my $sub = TalApi->can( $name );
        next unless defined $sub;
        my $proto = prototype $sub;
        next if defined $proto and length($proto) == 0;
        $methods{$name} = 1;
    }
    debug to_dumper { methods => \%methods };
    return \%methods;
}
sub __get_db_handles {
    my %database_handles = ();
    foreach my $db (keys %{ $config->{plugins}->{Database}->{connections} }) {
        $database_handles{$db} = database($db);
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
    my $sth = $database_handles->{ mysql }->prepare($params{sql});
    my $ret = $sth->execute or debug "execute failed";
    my $result = { rows => $sth->rows,
                 sql => $params{sql},
                 status => defined $ret ? 0 : $sth->errstr,
                 data => [] };
    while (my $row = $sth->fetchrow_hashref) {
        push(@{ $result->{data } }, $row);
    }
    return $result;
}

true;
