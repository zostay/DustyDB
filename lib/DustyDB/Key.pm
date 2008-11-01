package DustyDB::Key;
use Moose::Role;

=head1 NAME

DustyDB::Key - mark an attribute as being part of the primary key

=head1 SYNOPSIS

  package MyModel;
  use Moose;

  with 'DustyDB::Record';

  has name => ( is => 'rw', isa => 'Str', traits => [ 'DustyDB::Key' ] );
  has description => ( is => 'rw', isa => 'Str' );

=head1 DESCRIPTION

This is a basic marker role that just notifies DustyDB that the attribute should be used to define the primary key (one of the attributes that uniquely identifies it) for the object.

=head1 ATTRIBUTES

=head2 stringify

This may be defined as a reference to a subroutine to be used to translate a non-scalar attribute into a scalar key value. For example, if you want to use a date via L<DateTime> as a key, you could do:

  has timestamp => (
     is => 'rw',
     isa => 'DateTime',
     traits => [ 'DustyDB::Key' ],
     stringify => sub { $_->iso8601 },
  );

You may also want to use this in combination with L<DustyDB::Filter> to provide encoders and decoders for your object.

=cut

has stringify => (
    is => 'rw',
    isa => 'CodeRef',
    default => sub { sub { $_ } },
);

=head1 METHODS

=head2 perform_stringify

This is a helper for executing the code reference in the L</stringify> attribute correctly.

=cut

sub perform_stringify {
    my ($self, $value) = @_;

    local $_ = $value;
    return $self->stringify->($value);
}

1;
