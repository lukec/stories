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

sub _try_open {
    my ($self, $mode) = @_;
    my $tries = 0;
    my $db = $self->db;
    while (!$db->open("data/casket.tch", $mode | $db->OLCKNB)){
        my $ecode = $db->ecode();
        die "open error: ".$db->errmsg($ecode);
    }
    return $db;
}

sub read_db {
    my $self = shift;
    my $db = $self->db;
    $self->_try_open($db->OREADER);
    return $db, guard { $db->close; $self->clear_db };
}

sub write_db {
    my $self = shift;
    my $db = $self->db;
    $self->_try_open($db->OWRITER);
    return $db, guard { $db->close; $self->clear_db };
}

sub get_stories {
    my $self = shift;
    my ($db,$g) = $self->read_db;
    $db->iterinit();
    my @stories;
    while (defined(my $story_key = $db->iternext())) {
        my $value = $db->get($story_key);
        next unless (defined($value));
        push @stories, json_decode($value);
    }
    return \@stories;
}

sub get_story {
    my ($self, $story_key) = @_;
    my ($db,$g) = $self->read_db;
    my $value = $db->get($story_key);
    return unless defined($value);
    return $value;
}

sub put_story {
    my ($self, $story_key, $hash) = @_;
    my ($db,$g) = $self->write_db;

    use Data::Dumper; warn "put_story: ".Dumper($hash),$/;
    my $value = encode_json($hash);
    unless ($db->put($story_key,$value)) {
        my $ecode = $db->ecode();
        die "put error: ".$db->errmsg($ecode);
    }
}

sub add_candidate {
    my ($self, $story_key, $candidate) = @_;
    my ($db,$g) = $self->write_db;
    my $value = $db->get($story_key);
    return unless $value;
    my $hash = decode_json($value);
    $hash->{candidates} ||= [];
    push @{$hash->{candidates}}, [$candidate, 0];
    my $candidate_id = $#{$hash->{candidates}} + 1;
    use Data::Dumper; warn "created candidate $candidate_id for story $story_key : ".Dumper($hash),$/;
    $value = encode_json($hash);
    unless ($db->put($story_key,$value)) {
        my $ecode = $db->ecode();
        die "put error: ".$db->errmsg($ecode);
    }
    return $candidate_id;
}

sub vote_on_candidate {
    my ($self, $story_key, $candidate_id) = @_;
    $candidate_id--;
    my ($db,$g) = $self->write_db;
    my $value = $db->get($story_key);
    return unless $value;
    my $hash = decode_json($value);
    my $candidate = $hash->{candidates}[$candidate_id];
    return unless $candidate;
    $candidate->[1]++;
    use Data::Dumper; warn "VOTED on candidate $candidate_id for story $story_key : ".Dumper($hash),$/;
    $value = encode_json($hash);
    unless ($db->put($story_key,$value)) {
        my $ecode = $db->ecode();
        die "put error: ".$db->errmsg($ecode);
    }
    return $candidate->[1];
}

sub finalize_candidates {
    my ($self, $story_key) = @_;
    my ($db,$g) = $self->write_db;
    my $value = $db->get($story_key);
    return unless $value;
    my $hash = decode_json($value);
    use Data::Dumper; warn "FINALIZE on story $story_key : ".Dumper($hash),$/;
    my $top;
    ($top,undef) = sort { $b->[1] <=> $a->[1] } @{$hash->{candidates}};

    chomp $top;
    $top = ucfirst($top);
    $top =~ s/\.//;
    $top .= ".\n";

    $hash->{story} .= $top;
    $hash->{candidates} = [];
    $value = encode_json($hash);
    unless ($db->put($story_key,$value)) {
        my $ecode = $db->ecode();
        die "put error: ".$db->errmsg($ecode);
    }
}

1;
