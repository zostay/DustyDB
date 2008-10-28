package DustyDB::Record;
use Moose::Role;
use Moose::Util::MetaRole;

use Scalar::Util qw( blessed );

=head1 NAME

DustyDB::Record - role for DustyDB models

=head1 SYNOPSIS

  package MyModel;
  use Moose;

  with 'DustyDB::Record';

  has name => ( is => 'rw', isa => 'Str', traits => [ 'DustyDB::Key' ] );
  has description => ( is => 'rw', isa => 'Str' );

=head1 DESCRIPTION

Use this role on any model object you want to store in the database.

=head1 ATTRIBUTES

=head2 model

This is a required attribute that must be set to a L<DustyDB::Model> object that will be used to save this. In general, you will never need to set this yourself.

=cut

has model => (
    is        => 'rw',
    isa       => 'DustyDB::Model',
    required  => 1,
);

=head1 METHODS

=head2 save

  my $key = $self->save;

This method saves the object into the database and returns a key identifying the object. The key is a hash reference created using the attributes that have the L<DustyDB::Key> trait set.

=cut

sub save {
    my $self = shift;
    $self->model->save($self, @_);
}

=head2 delete

  $self->delete;

This method delets the object from the database. This does not invalidate the object in memory or alter it in any other way.

=cut

sub delete {
    my $self = shift;
    $self->model->delete($self, @_);
}

=head1 CAVEATS

When creating your models you cannot have an attribute named C<model> or an attribute named C<class_name>. The C<model> name is already taken and C<class_name> may be used when storing the data in some cases.

=cut

1;
