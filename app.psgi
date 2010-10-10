#!perl
use Plack::Builder;
use Plack::App::Directory;
use Plack::App::File;

builder {
    mount "/static" => builder {
        $app = Plack::App::Directory->new({ root => "static" })->to_app;
    };
    mount "/" => builder {
        $app = Plack::App::File->new(file => "static/index.html");
    }
};
