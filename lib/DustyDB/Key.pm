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

=cut

1;
