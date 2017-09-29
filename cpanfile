requires "Dancer2" => "0.204001";
requires "Plack"   => "0";
requires "Dancer2::Plugin::Database" => "0";
requires "DBD::SQLite" => "0";
requires "HTTP::Server::Simple" => "0";
requires "Plack::Handler::HTTP::Server::Simple" => "0";
requires "Server::Starter" => "0";
requires "Starman" => "0";
requires "Net::Server::SS::PreFork" => "0";
requires "MooseX::DataModel" => "0";
requires "SQL::Library" => "0";
requires "OpenAPI" => "0";
requires "JSON::Validator::OpenAPI" => "0";
requires "YAML::XS" => "0";
requires "JSON::DWIW" => "0";
requires "Server::Starter" => "0";
requires "App::Ack" => "0";
requires "HTTP::Tiny" => "0";
requires "SQL::Beautify" => "0";
requires "Plack::Middleware::CrossOrigin" => "0";
requires "DateTime::Event::Recurrence" => "0";

recommends "YAML"             => "0";
recommends "URL::Encode::XS"  => "0";
recommends "CGI::Deurl::XS"   => "0";
recommends "HTTP::Parser::XS" => "0";

on "test" => sub {
    requires "Test::More"            => "0";
    requires "HTTP::Request::Common" => "0";
    requires "Plack::Test"           => "0";
    requires "Test::utf8"            => "0";
    requires "Fatal"                 => "0";
    requires "Test::Perl::Critic"    => "0";
};
