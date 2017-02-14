requires "Dancer2" => "0.204001";
requires "Plack"   => "0";
requires "Dancer2::Plugin::Database" => "0";
requires "DBD::SQLite" => "0";
requires "HTTP::Server::Simple" => "0";
requires "Plack::Handler::HTTP::Server::Simple" => "0";

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
