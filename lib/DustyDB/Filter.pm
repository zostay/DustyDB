package DustyDB::Filter;
use Moose::Role;

=head1 NAME

DustyDB::Serialized - translate complex data into serial form for storage

=head2 SYNOPSIS

  package BlogPost;
  use Moose;
  use DateTime;

  with 'DustyDB::Record';

  has slug => ( is => 'rw', isa => 'Str', traits => [ 'DustyDB::Key' ] );
  has title => ( is => 'rw', isa => 'Str' );
  has body => ( is => 'rw', isa => 'Str' );
  has posted_on => (
      is => 'rw',
      isa => 'DateTime',
      traits => [ 'DustyDB::Filter' ],
      encode => sub { $_->iso8601 },
      decode => sub { DateTime::Format::ISO8601->parse_datetime($_) },
  );

=head1 DESCRIPTION

This provides your class with the ability to use a customized serialization scheme in the database. In case you have some data in your model that doesn't store well as is, you can use this to encode the data for storage and decode it later when loading.

=head1 ATTRIBUTES

=head2 encode

This is a subroutine used to transform a Perl object into a something else you want to store. Since we use L<DBM::Deep> to store the objects, this can be much more flexible than just a scalar.

This subroutine should expect the decoded value in C<$_> and return whatever value should be stored.

=cut

has encode => (
    is => 'rw',
    isa => 'CodeRef',
    required => 1,
    default => sub { sub { $_ } },
);

=head2 decode

This is a subroutine used to transform the previously encoded and stored "thing" into the object that is stored in the column.

This subroutine should expect the encoded value in C<$_> and return whatever value should be loaded into the model attribute.

=cut

has decode => (
    is => 'rw',
    isa => 'CodeRef',
    required => 1,
    default => sub { sub { $_ } },
);

=head1 METHODS

=head2 perform_encode

This is a helper method to make sure that encoding is performed properly.

=cut

sub perform_encode {
    my ($self, $value) = @_;

    local $_ = $value;
    return $self->encode->($value);
}

=head2 perform_decode

This is a helper method to make sure that decoding is performed properly.

=cut

sub perform_decode {
    my ($self, $value) = @_;

    local $_ = $value;
    return $self->decode->($value);
}

1;
