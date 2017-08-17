package Dancer2::Plugin::OpenAPI;

use Dancer2::Plugin;
use Dancer2::Plugin::OpenAPI::Core;
use Data::Dumper;
use SQL::Library;
use Carp qw/ confess /;

our $VERSION = '0.01';
 
register OpenAPI => sub {
    my $self = shift;
    my $conf = plugin_setting();
    my $conf2 = $self->config();
    if ($self->config->{apiconfigfile}) {
        $conf = $self->config->{apiconfigfile}
    }
    my $app = $self->app;
    my $conf3 = $app->config;
    warn Dumper { pluginconf => $conf, conf2 => $conf2, conf3 => $conf3 };
    my $apiconfigfile = $conf->{apiconfigfile} || "doc/tal-002.yml";;
    warn Dumper { apiconfigfile => $apiconfigfile };
    my $obj = Dancer2::Plugin::OpenAPI::Core->new({ url => $apiconfigfile });
    my $apiconfig = $obj->get_apiconfig;


    foreach my $path (sort keys %{ $apiconfig->{paths} } ) {
        my $config = $apiconfig->{paths}->{$path};
        foreach my $http_method (keys %{ $config }) {
            unless ($config->{$http_method }->{operationId}) {
                warn "ERROR: no operationId specified in spec for ".Dumper $config->{path};
            }
            my $class = $app->{calling_class} || $app->{name};
            my $callback = join('::', $class, 'process_query');
            $path =~ s/\{([^\}]+)\}/:$1/g;
            warn "add_route(method => $http_method, regexp => $path, callback => $callback)";
            $self->app->add_route(
                        method =>  $http_method,
                        regexp => $path,
                        code => sub { $callback->({apiconfig =>$apiconfig,
                                                   operationId => $config->{$http_method }->{operationId},
                                                   pathconfig => $config,
                                                   method => $http_method,
                                                   path => $path}); },

                        );
        }
    }

    return $obj;
};

register_plugin;
1;

__END__
