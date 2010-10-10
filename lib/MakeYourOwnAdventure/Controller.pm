package MakeYourOwnAdventure::Controller;
use Moose::Role;
use TokyoCabinet;
use Guard;
use JSON qw/decode_json encode_json/;

has 'db' => (is => 'ro', isa => 'Object', lazy_build => 1);

sub _build_db {
    my $self = shift;
    my $db = TokyoCabinet::HDB->new;
    return $db;
}

sub read_db {
    my $self = shift;
    my $db = $self->db;
    if(!$db->open("data/casket.tch", $db->OREADER | $db->OCREAT)){
        my $ecode = $db->ecode();
        printf STDERR ("open error: %s\n", $db->errmsg($ecode));
    }
    return $db, guard { $db->close; $self->clear_db };
}

sub write_db {
    my $self = shift;
    my $db = $self->db;
    if(!$db->open("data/casket.tch", $db->OWRITER | $db->OCREAT)){
        my $ecode = $db->ecode();
        die "open error: ".$db->errmsg($ecode);
    }
    return $db, guard { $db->close; $self->clear_db };
}

sub get_stories {
    my $self = shift;
    my ($db,$g) = $self->read_db;
    $db->iterinit();
    my @stories;
    while (defined(my $key = $db->iternext())) {
        my $value = $db->get($key);
        next unless (defined($value));
        push @stories, json_decode($value);
    }
    return \@stories;
}

sub get_story {
    my ($self, $key) = @_;
    my ($db,$g) = $self->read_db;
    my $value = $db->get($key);
    return unless defined($value);
    return json_decode($value);
}

sub put_story {
    my ($self, $key, $hash) = @_;
    my ($db,$g) = $self->write_db;
    my $value = json_encode($hash);
    unless ($db->put($key,$value)) {
        my $ecode = $db->ecode();
        die "put error: ".$db->errmsg($ecode);
    }
}

1;
