package Dancer2::Plugin::OpenAPI;

use Dancer2::Plugin;
use Dancer2::Plugin::OpenAPI::Core;
use Data::Dumper;

our $VERSION = '0.01';
 
register openapi => sub {
	my $dsl = shift;
     my $conf = plugin_setting;
    my $apiconfig =  Dancer2::Plugin::OpenAPI::Core->new({ url => "/home/tony/tal-api/doc/tal-002.yml" })->get_apiconfig;
        warn Dumper { conf => $conf, 
                      dsl => $dsl,
                        api => $apiconfig };
    foreach my $path (sort keys %{ $apiconfig->{paths} } ) {
        my $dancer2_path = $path;
 
        $basePath and $dancer2_path = $basePath . $dancer2_path;
 
        # adapt Swagger2 syntax for URL path arguments to Dancer2 syntax
        # '/path/{argument}' -> '/path/:argument'
        $dancer2_path =~ s/\{([^{}]+?)\}/:$1/g;
        warn Dumper { $path => $apiconfig->{paths}->{$path} };

    }
};

=pod
plugin_keywords 'openapi';
=cut

register_plugin;

1;

__END__

=pod

sub BUILD {
   debug to_dumper { params => \@_ };
    my $plugin = shift;
 
    $plugin->app->add_hook( Dancer2::Core::Hook->new(
        name => 'after',
        code => sub { $_[0]->content( $_[0]->content . " ... please?" ) }
    ));
 
    $plugin->app->add_route(
        method => 'get',
        regexp => '/goodbye',
        code   => sub {
            my $app = shift;
            'farewell, ' . $app->request->params->{name};
        },
    );
 
}


sub openapi {
	debug to_dumper { params => \@_ };
    my ($dsl, %args );
    my $conf = plugin_setting;

    my $val = JSON::Validator::OpenAPI->new;
    my $spec = $val->load_and_validate_schema($url)->data;
debug to_dumper $spec;

    if ( $validate_spec or $validate_requests or $validate_responses ) {
        if ( my @errors = $spec->validate ) {
            if ($validate_spec) {
                die join "\n" => "OpenAPI Invalid spec:", @errors;
            }
            else {
                warn "Spec contains errors but"
                  . " request/response validation is enabled!";
            }
        }
    }

    my $basePath = $spec->api_spec->get('/basePath');
    my $paths    = $spec->api_spec->get('/paths');    # TODO might be undef?

    while ( my ( $path => $path_spec ) = each %$paths ) {
        debug to_dumper { path => $path };
        my $dancer2_path = $path;

        $basePath and $dancer2_path = $basePath . $dancer2_path;

        # adapt Swagger2 syntax for URL path arguments to Dancer2 syntax
        # '/path/{argument}' -> '/path/:argument'
        $dancer2_path =~ s/\{([^{}]+?)\}/:$1/g;

        while ( my ( $http_method => $method_spec ) = each %$path_spec ) {
            my $coderef = $controller_factory->(
                $method_spec, $http_method, $path, $dsl, $conf, \%args
            ) or next;

            #DEBUG and warn "Add route $http_method $dancer2_path";

            my $params = $method_spec->{parameters};

            # Dancer2 DSL keyword is different from HTTP method
            $http_method eq 'delete' and $http_method = 'del';

            $dsl->$http_method(
                $dancer2_path => sub {
                    if ($validate_requests) {
                        my @errors =
                          _validate_request( $method_spec, $dsl->request );

                        if (@errors) {
                            #DEBUG and warn "Invalid request: @errors\n";
                            $dsl->status(400);
                            return { errors => [ map { "$_" } @errors ] };
                        }
                    }

                    my $result = $coderef->();

                    if ($validate_responses) {
                        my @errors =
                          _validate_response( $method_spec, $dsl->response,
                            $result );

                        if (@errors) {
                            #DEBUG and warn "Invalid response: @errors\n";
                            $dsl->status(500);

                            # TODO hide details of server-side errors?
                            return { errors => [ map { "$_" } @errors ] };
                        }
                    }

                    return $result;
                }
            );
        }
    }

};

=cut 

register_plugin;

1;


sub _validate_request {
    my ( $method_spec, $request ) = @_;

    my @errors;

    for my $parameter_spec ( @{ $method_spec->{parameters} } ) {
        my $in       = $parameter_spec->{in};
        my $name     = $parameter_spec->{name};
        my $required = $parameter_spec->{required};

        if ( $in eq 'body' ) {    # complex data structure in HTTP body
            my $input  = $request->data;
            my $schema = $parameter_spec->{schema};

            push @errors, _validator()->validate_input( $input, $schema );
        }
        else {    # simple key-value-pair in HTTP header/query/path/form
            my $type = $parameter_spec->{type};
            my @values;

            if ( $in eq 'header' ) {
                @values = $request->header($name);
            }
            elsif ( $in eq 'query' ) {
                @values = $request->query_parameters->get_all($name);
            }
            elsif ( $in eq 'path' ) {
                @values = $request->route_parameters->get_all($name);
            }
            elsif ( $in eq 'formData' ) {
                @values = $request->body_parameters->get_all($name);
            }
            else { die "Unknown value for property 'in' of parameter '$name'" }

            # TODO align error messages to output style of SchemaValidator
            if ( @values == 0 and $required ) {
                $required and push @errors, "No value for parameter '$name'";
                next;
            }
            elsif ( @values > 1 ) {
                push @errors, "Multiple values for parameter '$name'";
                next;
            }

            my $value  = $values[0];
            my %input  = ( $name => $value );
            my %schema = ( properties => { $name => $parameter_spec } );

            $required and $schema{required} = [$name];

            push @errors, _validator()->validate_input( \%input, \%schema );
        }
    }

    return @errors;
}

sub _validate_response {
    my ( $method_spec, $response, $result ) = @_;

    my $responses = $method_spec->{responses};
    my $status    = $response->status;

    my @errors;

    if ( my $response_spec = $responses->{$status} || $responses->{default} ) {

        my $headers = $response_spec->{headers};

        while ( my ( $name => $header_spec ) = each %$headers ) {
            my @values = $response->header($name);

            if ( $header_spec->{type} eq 'array' ) {
                push @errors,
                  _validator()->validate_input( \@values, $header_spec );
            }
            else {
                if ( @values == 0 ) {
                    next;    # you can't make a header 'required' in OpenAPI
                }
                elsif ( @values > 1 ) {

                   # TODO align error message to output style of SchemaValidator
                    push @errors, "header '$name' has multiple values";
                    next;
                }

                push @errors,
                  _validator()->validate_input( $values[0], $header_spec );
            }
        }

        if ( my $schema = $response_spec->{schema} ) {
            push @errors, _validator()->validate_input( $result, $schema );
        }
    }
    else {
        # TODO Call validate_input($response, {}) like
        #      in Mojolicious::Plugin::OpenAPI?
        # OpenAPI-0.71/lib/Mojolicious/Plugin/OpenAPI.pm line L315
    }

    return @errors;
}


sub _default_controller_factory {
    # TODO simplify argument list
    my ( $method_spec, $http_method, $path, $dsl, $conf, $args, ) = @_;

    # from Dancer2 app
    my $namespace = $args->{controller} || $conf->{controller};
    my $app = $dsl->app->name;

    # from OpenAPI file
    my $module;
    my $method = $method_spec->{operationId};
    if ( $method =~ s/^(.+)::// ) {    # looks like Perl module
        $module = $1;
    }

    # different candidates possibly reflecting operationId
    my @controller_candidates = do {
        if ($namespace) {
            if ($module) { $namespace . '::' . $module, $module }
            else         { $namespace }
        }
        else {
            if ($module) {
                (                      # parens for better layout by Perl::Tidy
                    $app . '::' . $module,
                    $app . '::Controller::' . $module,
                    $module,           # maybe a top level module name?
                );
            }
            else { $app, $app . '::Controller' }
        }
    };

    # check candidates
    for my $controller (@controller_candidates) {
        local $@;
        eval { load $controller };
        if ($@) {
            if ( $@ =~ m/^Can't locate / ) {    # module doesn't exist
                #DEBUG and warn "Can't load '$controller'";

                # don't do `next` here because controller could be
                # defined in other package ...
            }
            else {    # module doesn't compile
                die $@;
            }
        }

        if ( my $cb = $controller->can($method) ) {
            return $cb;    # confirmed candidate
        }
        else {
            #DEBUG and warn "Controller '$controller' can't '$method'";
        }
    }

    # none found
    warn "Can't find any handler for operationId '$method_spec->{operationId}'";
    return;
}

my $validator;
    
sub _validator { $validator ||= JSON::Validator::OpenAPI->new };

=cut


1;
