package DustyDB::Index::PrimaryKey;
use Moose;

use Carp ();
use List::Util qw( max );
use Scalar::Util qw( reftype );

with qw( DustyDB::Index );

has '+name' => (
    default => 'primary_key',
);

my $x = 1;
sub BUILD {
    my $self = shift;
    
    for my $field (@{ $self->fields }) {
        Moose::Util::apply_all_roles($field, 'DustyDB::Key');
    }
}

sub build_que {
    my $self = shift;
    my $keys = shift;

    # Setup the lookup que
    my @que;
    QUE: for my $key (@{ $self->fields }) {
        last QUE if not defined $keys->{ $key->name };
        push @que, $keys->{ $key->name };
    }

    return \@que;
}

sub find_by_que {
    my ($self, $object, $que) = @_;

    for my $que_entry (@$que) {
        return unless ref $object and reftype $object eq 'HASH';

        if (defined $object->{$que_entry}) {
            $object = $object->{$que_entry};
        }

        else {
            return;
        }
    }

    return $object;
}

sub lookup_keys {
    my $self   = shift;
    my $meta   = $self->record_meta;
    my %params = @_;
    my $db     = $params{db};
    my $key    = $params{key};

    # If the query is complete, we will return just that key
    return [ $key ] if $self->complete_key(keys %$key);

    # Find the incomplete keys and try to find all possible completions
    my $incomplete_key = $self->build_key(%$key);
    my $incomplete_que = $self->build_que($incomplete_key);

    # Load the key up to the point we've been given
    my $table  = $db->table( $meta->name );
    my $object = $self->find_by_que($table, $incomplete_que);

    # If nothing is found there, we match an empty set
    return [] unless defined $object;

    # Tells us how deep we need to go to complete the keys we have
    my @field_indexes = max(0, scalar(@{ $incomplete_que }) - 1)
                     .. scalar(@{ $self->fields }) - 1;

    # Iterate over the remaining fields to create complete keys
    my @incomplete_pairs = ([ $incomplete_key, $object ]);
    for my $field (@{ $self->fields }[@field_indexes]) {
        my @next_incomplete_pairs;

        # Find all the keys we know about so far and add on to them
        for my $incomplete_pair (@incomplete_pairs) {
            my ($incomplete_key, $object) = @$incomplete_pair;

            # By breadth first search expand the list of keys we know about
            while (my ($next_key_value, $next_object) = each %$object) {
                my %next_key = %$incomplete_key;
                $next_key{ $field->name } = $next_key_value;

                push @next_incomplete_pairs, [ \%next_key, $next_object ];
            }
        }

        # Replace the open list with the upcoming (possibly complete) iteration
        @incomplete_pairs = @next_incomplete_pairs;
    }

    # Return just the (now complete) keys
    return [ map { $_->[0] } @incomplete_pairs ];
}

sub load_record {
    my $self   = shift;
    my $meta   = $self->record_meta;
    my %params = @_;
    my $db     = $params{db};
    my $key    = $params{key};

    my $keys = $self->build_key(@$key);
    Carp::croak('Incomplete key on primary key lookup.')
        unless $self->complete_key(keys %$keys);

    my $que  = $self->build_que($keys);
    
    # Fetch the record from the database
    my $table  = $db->table( $meta->name );
    my $object = $self->find_by_que($table, $que);

    return unless defined $object;
    return $object->export;
}

1;
