package MakeYourOwnAdventure::Stories;
use Moose;
use JSON qw/decode_json encode_json/;
use Plack::Request;
use Digest::SHA1 qw/sha1_hex/;
use AnyEvent;
use namespace::clean -except => 'meta';

with 'MakeYourOwnAdventure::Controller';

sub to_app {
    my $self = shift;

    return sub {
        my $env = shift;
        my $req = Plack::Request->new($env);
        return $self->do_resp($req,$env);
    };
}

sub do_resp {
    my ($self,$req,$env) = @_;

    my $path = $req->path;
    my $content;
    # GET or PUT?
    if ($req->method eq 'GET') {
        if ($path eq '/') {
            $content = encode_json($self->get_stories);
        }
        else {
            $path =~ s{^/}{};
            $content = $self->get_story($path);
        }
    }
    elsif ($req->method eq 'POST') {
        if ($path eq '/') {
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
                hash => sha1_hex($story_so_far),
            };
            $self->put_story($name, $story);
            return [201, ['Location' => "/stories/$name", 'Content-Type' => 'application/json'], [encode_json($story)]];
        }
        elsif ($path =~ m{^/([^/]+)/candidate$}) {
            my $name = $1;
            my $c_hash = $req->param('hash');
            my $c_line = $req->param('storyline');
            if ($c_hash and $c_line) {
                my $story = $self->get_story($name);
                if ($story->{hash} eq $c_hash) {
                    my $id = $self->add_candidate($name, $c_line);
                    $content = encode_json($self->get_story($name));

                    if ($id == 1) {
                        my $t; $t = AE::timer 20, 0, sub {
                            $self->finalize_candidates($name);
                            undef $t;
                        };
                    }
                }
            }
        }
    }
    elsif ($req->method eq 'PUT') {
        if ($path =~ m{^/([^/]+)/candidate/([^/]+)/vote$}) {
            $self->vote_on_candidate($1,$2);
            return [202, ['Content-Type' => 'application/json'], ["Thanks for voting"]];
        }

    }

    unless ($content) {
        return [404, ['Content-Type' => 'text/plain'], ['{"wadr":"gfy"}']];
    }

    return [200, ['Content-Type' => 'application/json'], [\$content]];
}


__PACKAGE__->meta->make_immutable;

