package DustyDB::Collection;
use Moose;

use Carp ();

use Scalar::Util qw( reftype );

=head1 NAME

DustyDB::Collection - collections of records

=head1 SYNOPSIS

  package WhatsIt;
  use DustyDB::Object;

  has key bobble => ( is => 'rw', isa => 'Str' );
  has bits   => ( is => 'rw', isa => 'Str', predicate => 'has_bits' );

  package main;
  use DustyDB;

  my $db = DustyDB->new( path => 'foo.db' );
  my $model = DustyDB->model('WhatsIt');

  # All whatsits with a bobble containing fluff
  my $iter = $model->all( bobble => qr/fluff/ ); 
  while (my $whatsit = $iter->next) {
      print "Your fluff has bits of ", $whatsit->bits, " in it.\n";
  }

  # Iterate through those that actually have bits
  $iter->filter( 'has_bits' );
  for my $whatsit ($iter->records) {
      print "Whatsit ", $whatsit->bobble, " has bits.\n";
  }

  # and so on...

=head1 DESCRIPTION

This class encapsulates a collection of records stored in DustyDB and provides tools to iterate over those records.

=head1 GUTS

Here's some extra information on how this works. You don't need this knowledge to make use of collections, but it helps to explain how to improve performance.

A collection first collects a selection of records from the database using a searcher subroutine. This is a query of objects from the database based upon the available indexes and primary key. If no index is available to be used for search, then all records will be selected for placement within the collection. They aren't actually pulled until we begin to iterate.

Each record that is pulled from the database may then be filtered. If a filter subroutine is needed to finish selection, the object will be constructed and the filter will be run on the object to determine if it should be a part of the collection. Any object that matches the filter is kept. Anything else is thrown away.

=head2 GUTS EXAMPLE 1: SEARCHER ONLY

  package Person;
  use DustyDB::Object;

  has key last_name => ( is => 'rw', isa => 'Str' );
  has key first_name => ( is => 'rw', isa => 'Str' );
  has age => ( is => 'rw', isa => 'Int' );

  package main;
  use DustyDB;

  my $db = DustyDB->new(...);
  my $model = $db->model('Person');

  my $collection = $model->all( last_name => 'Dent' );

In this case, the collection will load all the C<Person> objects using the primary key since the C<last_name> is the first part of the primary key.

=head2 GUTS EXAMPLE 2: SEARCHER AND FILTER

  # Using the same model as in Example 1
  my $collection = $model->all( last_name => 'Dent', age => 42 );

This time, the collection will pull all the records based upon the primary key as before, but will then have to filter every object returned to see if the C<age> attribute is set to 42.

=head2 GUTS EXAMPLE 3: FILTER ONLY

  # Using the same model as in Example 
  my $collection = $model->all( age => 42 );

There's no primary key or index that will help here, so every Person will be pulled from the database, constructed, and then filtered. This will be the most costly search of these examples.

=head2 EXPLAIN

If you aren't sure what's going on, the collection class does provide a tool to help you figure it out. It is provided in the L</explain> method.

For example,

  # Assuming the same model as in example 1 above
  use Data::Dumper;
  my $collection = $model->all( 
      first_name => 'Arthur',
      last_name  => 'Dent', 
      age        => 42,
  );
  print Dumper( $collection->explain );

This will output:

  $VAR1 = {
            'filter' => [
                          'age'
                        ],
            'search' => {
                          'primary_key' => [
                                             'last_name',
                                             'first_name'
                                           ]
                        }
          };

This tells you that the searcher will use the primary key to lookup the C<last_name> and C<first_name> as part of the search phase and then filter on C<age>.

# =head1 ATTRIBUTES
# 
# =head2 model
# 
# This is the L<DustyDB::Model> used to construct objects within 
# this collection.
# 
# =head2 db
# 
# This is a link back to the L<DustyDB> object.
# 
# =head2 record_meta
# 
# This is the meta class for the L<DustyDB::Record>.
 
=cut

has model => (
    is       => 'rw',
    isa      => 'DustyDB::Model',
    required => 1,
    handles  => [ qw( db record_meta ) ],
);

# =head2 searcher_subroutine
#
# This contains a reference to the subroutine that is used to find records to
# place within the 

# =head2 filter_subroutine
# 
# This contains a reference to the subroutine that is used to 
# filter the records (if any). This is a read-only accessor.
# 
# =head2 has_filter_subroutine
# 
# This is a predicate that returns true if L</filter_subroutine> 
# is set.
# 
# =cut

has filter_subroutine => (
    is        => 'ro',
    isa       => 'CodeRef',
    predicate => 'has_filter_subroutine',
);

# =head2 records
# 
# This is the cached list of records that have been found to 
# belong to this collection. This list is built as we iterate 
# through the collection (or possibly all at once if 
# L</contextual> is called). As such, this isn't realy a very 
# useful accessor, see L</contextual> instead.
# 
# =cut

has records => (
    is => 'ro',
    isa => 'ArrayRef',
    required => 1,
    default => sub { [] },
);

# =head2 iterator_index
# 
# Do B<not> use this directly. See L</next> instead. This is the 
# internal pointer into the L</records> array.
# 
# =cut

has iterator_index => (
    is => 'rw',
    isa => 'Int',
    default => 0,
);

=head1 METHODS

=head2 filter

  $collection->filter( %params );
  $collection->filter( $method_name );
  $collection->filter( $code_ref );

Given a description of a filter, this method will filter the records accordingly. There are three kinds of arguments that may be passed:

=over

=item 1.

C<%params>. If you pass a hash of parameters, the keys are expected to be column names in the model object and the vlaues are expected to be values to match. These values may either be a scalar for an exact match or a regular expression to perform a pattern match.

=item 2.

C<$method_name>. If a string is given that matches a method defined on the model object, that method will be called (with no arguments) on every object. Any time a true value is returned by that method, it will be included in the collection.

=item 3.

C<$code_ref>. If a code reference is passed, this code reference is called for each object with C<$_> set to the object being evaluated. If the subroutine returns a true value, the object evaluated will be included in the collection.

=back

=cut

# FIXME This implementation goes ahead and grabs all the data up front.  This
# could be a VeryBadThing(tm). That is, if we have a bazillion records and we
# dump every one of them into this array: bad stuff. This is especially bad
# since we pre-construct each of these too. Very Bad.
#
# However, it's easy, which is, in my book, a good thing for 0.01 versions.

sub _build_records {
    my $self = shift;

    my @originals = $self->record_meta->list_all_objects( db => $self->db );

    # If we have a filter
    if ($self->has_filter_subroutine) {
        my @records;
        local $_;

        for (@originals) {
            if ($self->filter_subroutine->()) {
                push @records, $_;
            }
        }

        return \@records;
    }

    # Without a filter
    else {
        return \@originals;
    }
}

sub filter {
    my $self = shift;

    # Handle the single argument call varieties
    if (@_ == 1) {

        # Did we get a subroutine?
        if (ref $_[0] and reftype $_[0] eq 'CODE') {
            my $sub = $_[0];

            # We need to wrap it to construct a real object for the sub
            $self->filter_subroutine( sub {
                return $sub->();
            } );
        }

        # Is it a hash reference?
        elsif (ref $_[0] and reftype $_[0] eq 'HASH') {
            $self->filter_subroutine( $self->_hash_to_filter( %{ $_[0] } ) );
        }

        # Did we get a method name?
        elsif ($self->record_meta->has_method($_[0])) {
            my $method = $_[0];

            $self->filter_subroutine( sub {
                return $_->$method();
            } );
        }

        # I don't know what this is
        else {
            Carp::croak "not sure what to do with that kind of filter";
        }
    }

    # Assume it's a hash
    else {
        $self->filter_subroutine( $self->_hash_to_filter( @_ ) );
    }

    $self->records( $self->_build_records );

    return $self->contextual;
}

sub _hash_to_filter {
    my $self   = shift;
    my %params = @_;
    my $attrs  = $self->record_meta->get_attribute_map;

    # First, a sanity check 
    for my $name (keys %params) {

        # Don't filter if we can't filter
        Carp::croak "$name is not an attribute of ", $self->record_meta->name
            unless defined $attrs->{ $name };
    }

    # Second, build the checker routine 
    return sub {
        my $result = 1;
        while (my ($name, $match) = each %params) {

            # TODO It would be lovely to have the smart match operator here, but
            # I want this to work on 5.8 still. Perhaps have this for 5.8, but
            # switch on ~~ if the compiler is 5.10?

            # Handle a regex
            if (ref $match and ref $match eq 'Regexp') {
                $result &&= $_->{$name} =~ /$match/;
            }

            # Handle a number
            elsif ($attrs->{ $name }->type_constraint->is_a_type_of('Num')) {
                $result &&= $_->{$name} == $match;
            }

            # Handle any other scalar
            else {
                $result &&= $_->{$name} eq $match;
            }
        }

        return $result;
    };
}

=head2 count

  my $count = $collection->count;

Returns the number of records matched by the filter (or number of records total if there is no filter).

=cut

sub count {
    my $self = shift;
    my @records = $self->records;
    return scalar @records;
}

=head2 first

  my $record = $collection->first;

Returns the first record matched or C<undef>.

=cut

sub first {
    my $self = shift;
    return $self->count > 0 ? $self->records->[0] : undef;
}

=head2 last

  my $record = $collection->last;

Returns the last record matched or C<undef>.

=cut

sub last {
    my $self = shift;
    return $self->count > 0 ? $self->records->[-1] : undef;
}

=head2 next

  my $record = $collection->next;

Returns the next record in the collection. On the first call, it returns the first record. On the second, it returns the second. This continues until it reaches the last record and then it returns C<undef>. This sequence will repeat immediately after returning C<undef> if called again.

=cut

sub next {
    my $self = shift;

    # Get the index
    my $index = $self->iterator_index;
    $self->iterator_index( $index + 1);

    # Get the object
    my $next;
    if (defined $self->records->[ $index ]) {
        $next = $self->records->[ $index ];
    }

    # On undef we need to reset the iterator
    else {
        $self->reset;
    }

    return $next;
}

=head2 reset

  $collection->reset;

Resets the record pointer used by L</next> so that the next call to that method will return the first record.

=cut

sub reset {
    my $self = shift;
    $self->iterator_index(0);
}

=head2 contextual

  my @records = $collection->contextual;
  my $iter    = $collection->contextual;

You probably won't need to call this yourself. It basically makes the switch between the array and this collection class.

=cut

sub contextual {
    my $self = shift;
    return wantarray ? @{ $self->records } : $self;
}

1;
