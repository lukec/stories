#!perl
use lib 'lib';
use Plack::Builder;
use Plack::App::Directory;
use Plack::App::File;
use MakeYourOwnAdventure::Stories;

builder {
    mount "/static" => 
        Plack::App::Directory->new({ root => "static" })->to_app;
    mount "/" => 
        Plack::App::File->new(file => "static/index.html")->to_app;
    mount "/stories" =>
        MakeYourOwnAdventure::Stories->new()->to_app;
};
