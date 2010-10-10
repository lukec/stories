package MakeYourOwnAdventure::Stories;
use Moose;
use JSON qw/decode_json encode_json/;
use Plack::Request;
use namespace::clean -except => 'meta';

with 'MakeYourOwnAdventure::Controller';

sub to_app {
    my $self = shift;

    return sub {
        my $env = shift;
        my $req = Plack::Request->new($env);

        # GET or PUT?
        if ($req->method eq 'GET') {
            my $content = encode_json($self->get_stories);
            return [200, ['Content-Type' => 'application/json'], [\$content]];
        }
        elsif ($req->method eq 'POST') {
            my $title = $req->param('title');
            my $story_so_far = $req->param('story_so_far');

            unless ($title and $story_so_far) {
                return [400, ['Content-Type' => 'text/plain'], ["Bad params"]];
            }

            (my $name = $title) =~ s/[^\w]+/_/g;
            my $story = {
                name => $name,
                title => $title,
                story => $story_so_far,
            };
            $self->put_story($name, $story);
            return [201, ['Location' => "/stories/$name", 'Content-Type' => 'application/json'], [encode_json($story)]];
        }
    };
}


__PACKAGE__->meta->make_immutable;

