package Dancer2::Plugin::OpenAPI::Core;
 
use Moo;
use JSON::Validator::OpenAPI;
    
has 'apiconfig' => (
    is => 'rw',
    reader => 'get_apiconfig',
    writer => 'set_apiconfig'
);

sub BUILD {
    my $self = shift;
    my $config = shift;
    my $val = JSON::Validator::OpenAPI->new;
    my $url = $config->{url};
    my $spec = $val->load_and_validate_schema($url);
    $self->set_apiconfig($val->schema->data);

    return $self;

}
1;


