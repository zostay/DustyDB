package DustyDB::Meta::Class;
use Moose::Role;

use Scalar::Util qw( blessed reftype );

=head1 ATTRIBUTES

=head2 primary_key

This is currently implemented as an attribute. This might change in the future. This assumes that the primary key will not change at runtime (which is probably a pretty good assumption).

=cut

has primary_key => (
    is       => 'rw',
    isa      => 'ArrayRef',
    lazy     => 1,
    required => 1,
    default  => sub {
        my $self  = shift;
        my @attr = values %{ $self->get_attribute_map };
        return [ grep { $_->does('DustyDB::Key') } @attr ];
    },
);

=head1 METHODS

=head2 load_instance

  my $record = $meta->load_instance( db => $db, %key );

Load a record object from the given L<DustyDB> with the given key parameters.

=cut

sub load_instance {
    my $meta   = shift;
    my %params = @_;
    my $db     = $params{db};

    $db->init_table($meta->name);
    my $keys = $meta->_build_key(%params);
    my $que  = $meta->_build_que($keys);
    
    # Fetch the record from the database
    my $object = $db->table( $meta->name );
    for my $que_entry (@$que) {
        return unless ref $object and reftype $object eq 'HASH';

        if (defined $object->{$que_entry}) {
            $object = $object->{$que_entry};
        }

        else {
            return;
        }
    }

    # Bake the model
    my %params = ( %$object, db => $db );
    for my $attr (values %{ $meta->get_attribute_map }) {
        # TODO use a non-saved marker role instead of this crass hack
        next if $attr->name eq 'db';

        # If this is another record, load it first
        if (defined $params{ $attr->name }
                and ref $params{ $attr->name } 
                and reftype $params{ $attr->name } eq 'HASH'
                and defined $params{ $attr->name }{'class_name'}) {

            my $class_name = $params{ $attr->name }{'class_name'};
            my $other_model = $db->model( $class_name );
            my $object = $other_model->load( %{ $params{ $attr->name } } );
            $params{ $attr->name } = $object;
        }

        # Otherwise try to decode if needed
        elsif (defined $params{ $attr->name }) {
            $params{ $attr->name } 
                = $attr->perform_decode( $params{ $attr->name } );
        }
    }

    # ... and serve
    return $meta->create_instance( %params );
}

sub _build_key {
    my $meta = shift;
    my %keys;

    # We have a record that needs to be decomposed
    if (blessed $_[0] and $_[0]->isa($meta->name)) {
        for my $key (@{ $_[0]->meta->primary_key }) {
            $keys{ $key->name } 
                = $key->perform_stringify($key->get_value($_[0]));
        }
    }

    # A single argument and a single column key
    elsif (@_ == 1 and @{ $meta->primary_key } == 1) {
        my $key = $meta->primary_key->[0];
        $keys{ $key->name } = $key->perform_stringify($_[0]);
    }
    
    # A multi-column key must be given with a hashref
    else {
        my %params = @_;
        for my $key (@{ $meta->primary_key }) {
            $keys{ $key->name } 
                = $key->perform_stringify($params{ $key->name });
        }
    }

    return \%keys;
}

sub _build_que {
    my $meta = shift;
    my $keys = shift;

    # Setup the lookup que
    my @que;
    for my $key (@{ $meta->primary_key }) {
        confess qq(cannot store when column "@{[ $key->name ]}" is undefined.\n)
            if not defined $keys->{ $key->name };
        push @que, $keys->{ $key->name };
    }

    return \@que;
}

=head2 save_instance

  my $key = $meta->save_instance( db => $db, record => $record );

This saves the given record (an object that does L<DustyDB::Record>) to the given L<DustyDB> database. This method returns a hash referece representing a key that can be used to retrieve the object later via:

  my $record = $meta->load_instance( db => $db, %$key );

=cut

sub save_instance {
    my $meta   = shift;
    my %params = shift;
    my $db     = $params{db};
    my $record = $params{record};

    # Bootstrap if we need to and setup the que
    $db->init_table($meta->name);
    my $keys = $self->_build_key($record);
    my $que  = $self->_build_que($keys);

    # Separate the last que for final work
    my $last_que = pop @$que;
    my $que_remaining = scalar @$que;

    # Locate the hash containing the last que
    my $object = $db->table( $meta->name );
    for my $que_entry (@$que) {
        if (defined $object->{$que_entry}) {

            if ($que_remaining == 0 
                    or (ref $object->{$que_entry} 
                        and reftype $object->{$que_entry} eq 'HASH')) {
                $object = $object->{$que_entry};
            }
            
            # overwrite previous non-hash fact with something more agreeable
            else {
                $object = $object->{$que_entry} = {}
            }
        }

        else {
            $object = $object->{$que_entry} = {};
        }

        $que_remaining--;
    }

    # Build a hash representing the data in the object
    my $hash = {};
    for my $attr (values %{ $meta->get_attribute_map }) {
        # TODO use a non-saved marker role instead of this crass hack
        next if $attr->name eq 'db';

        # Load the value itself
        my $value = $attr->perform_encode( $attr->get_value($record) );

        # Skip on undef since this can cause things to go amuck at load
        next unless defined $value;

        # If this is another record, just store the key
        if (blessed $value and $value->can('does') and $value->does('DustyDB::Record')) {
            $hash->{ $attr->name } = $value->save;
        }

        # Otherwise, store the thingy
        else {
            $hash->{ $attr->name } = $value;
        }
    }

    # Save to the last que location
    $object->{$last_que} = $hash;
    
    # Set the class name in the key, and return
    $keys->{class_name} = $self->class_name;
    return $keys;
}

=head2 delete_instance

  $meta->delete_instance( db => $db, record => $record );

Delete the record instance from the database.

=cut

sub delete_instance {
    my $self = shift;

    # Bootstrap and setup the que
    $self->init_table($self->class_name);
    my $keys = $self->_build_key(@_);
    my $que  = $self->_build_que($keys);
    
    # This is the final bit to delete
    my $last_que = pop @$que;

    # Find the place to delete from
    my $object = $self->table( $self->class_name );
    for my $que_entry (@$que) {
        if (defined $object->{$que_entry}) {
            $object = $object->{$que_entry};
        }
        else {
            return; # didn't find it, skip it
        }
    }

    # Delete the record
    delete $object->{$last_que};

    # TODO This may leave a partial key dangling empty, some more clean-up
    # here might be a good idea.
}

1;
