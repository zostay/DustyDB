package DustyDB::Model;
use Moose;

use Scalar::Util qw( blessed reftype );

=head1 NAME

DustyDB::Model - model classes represent the tables in your database

=head1 SYNOPSIS

  use DustyDB;
  my $db = DustyDB->new( path => 'foo.db' );
  my $author = $db->model( 'Author' );

  # Create a record
  my $schwartz = $author->create( name => 'Randall Schwartz' );

  # New record that hasn't been saved yet
  my $chromatic = $author->construct( name => 'chromatic' );

  # Load a record from the disk
  my $the_damian = $author->load( 'Damian Conway' );

  # Delete the record
  $schwartz->delete;

=head1 DESCRIPTION

This class is the bridge between the storage database and the records in it. Normally, you won't need to create this object yourself, but use the C<model> method of L<DustyDB> to create it for you.

=head1 ATTRIBUTES

=head2 class_name

This is the record package.

=cut

has class_name => (
    is       => 'rw',
    isa      => 'ClassName',
    required => 1,
);

=head2 db

This is the L<DustyDB> that owns this model instance.

=cut

has db => (
    is       => 'rw',
    isa      => 'DustyDB',
    required => 1,
    handles  => [ qw( model table init_table ) ],
);

=head1 METHODS

=cut

sub _primary_key {
    my $model = shift;
    my $self  = shift;
    my @attr = values %{ $self->meta->get_attribute_map };
    return [ grep { $_->does('DustyDB::Key') } @attr ];
}

=head2 construct

Create a new record object in memory only. You need to call L<DustyDB::Record/save> on the record to store it. The parameters are passed directly to the constructor for the record.

=cut

sub construct {
    my $self = shift;

    my %params = ( @_, model => $self );
    return $self->class_name->new( %params );
}

=head2 create

Create a new record object and save it. The parameters are passed to the constructor for the record.

=cut

sub create {
    my $self = shift;

    my $object = $self->construct(@_);
    $object->save;

    return $object;
}

=head2 load

Load a record object from the disk.

=cut

sub load {
    my $self = shift;

    $self->init_table($self->class_name);
    my $keys = $self->_build_key(@_);
    my $que  = $self->_build_que($keys);
    
    # Fetch the record from the database
    my $object = $self->table( $self->class_name );
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
    my %params = ( %$object, model => $self );
    for my $attr (values %{ $self->class_name->meta->get_attribute_map }) {
        next if $attr->name eq 'model';

        # If this is another record, load it first
        if (ref $params{ $attr->name} 
                and reftype $params{ $attr->name } eq 'HASH'
                and defined $params{ $attr->name }{'class_name'}) {

            my $class_name = $params{ $attr->name }{'class_name'};
            my $other_model = $self->model( $class_name );
            my $object = $other_model->load( %{ $params{ $attr->name } } );
            $params{ $attr->name } = $object;
        }
    }

    # ... and serve
    return $self->class_name->new( %params );
}

sub _build_key {
    my $self = shift;
    my %keys;

    # We have a record that needs to be decomposed
    if (blessed $_[0] and $_[0]->isa($self->class_name)) {
        for my $key (@{ $self->_primary_key($_[0]) }) {
            $keys{ $key->name } = $key->get_value($_[0]);
        }
    }

    # A single argument and a single column key
    elsif (@_ == 1 and @{ $self->_primary_key($self->class_name) } == 1) {
        $keys{ $self->_primary_key($self->class_name)->[0]->name } = $_[0];
    }
    
    # A multi-column key must be given with a hashref
    else {
        %keys = @_;
    }

    return \%keys;
}

sub _build_que {
    my $self = shift;
    my $keys = shift;

    # Setup the lookup que
    my @que;
    for my $key (@{ $self->_primary_key($self->class_name) }) {
        confess qq(cannot store when column "@{[ $key->name ]}" is undefined.\n)
            if not defined $keys->{ $key->name };
        push @que, $keys->{ $key->name };
    }

    return \@que;
}

sub save {
    my $self   = shift;
    my $record = shift;

    $self->init_table($self->class_name);
    my $keys   = $self->_build_key($record);
    my $que    = $self->_build_que($keys);

    my $last_que = pop @$que;
    my $que_remaining = scalar @$que;

    my $object = $self->table( $self->class_name );
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

    my $hash = {};
    for my $attr (values %{ $record->meta->get_attribute_map }) {
        next if $attr->name eq 'model';
        my $value = $attr->get_value($record);

        # If this is another record, just store the key
        if (blessed $value and $value->can('does') and $value->does('DustyDB::Record')) {
            $hash->{ $attr->name } = $value->save;
        }

        # Otherwise, store the thingy
        else {
            $hash->{ $attr->name } = $value;
        }
    }

    $object->{$last_que} = $hash;
    
    $keys->{class_name} = $self->class_name;
    return $keys;
}

sub delete {
    my $self = shift;

    $self->init_table($self->class_name);
    my $keys = $self->_build_key(@_);
    my $que  = $self->_build_que($keys);
    
    my $last_que = pop @$que;

    my $object = $self->table( $self->class_name );
    for my $que_entry (@$que) {
        if (defined $object->{$que_entry}) {
            $object = $object->{$que_entry};
        }
        else {
            return;
        }
    }

    delete $object->{$last_que};
}

=begin Pod::Coverage

  save
  delete

=end Pod::Coverage

=cut

1;
