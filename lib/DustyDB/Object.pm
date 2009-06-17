package DustyDB::Object;
use Moose;
use Moose::Util;
use Moose::Util::MetaRole;

use Carp ();

use DustyDB::Index::PrimaryKey;
use DustyDB::Record;
use DustyDB::Meta::Class;
use DustyDB::Meta::Attribute;
use DustyDB::Meta::Instance;

use Moose::Exporter;

Moose::Exporter->setup_import_methods(
    as_is => [ 'primary_key', 'key' ],
    also  => 'Moose',
);

=head1 NAME

DustyDB::Object - use this class to declare a model to store

=head1 SYNOPSIS

  package Song;
  use DustyDB::Object;

  has key title => ( is => 'rw', isa => 'Str', required => 1 );
  has artist => ( is => 'rw', isa => 'Str' );

=head1 DESCRIPTION

This is a special L<Moose> extension that causes any module that uses it to become a model that may be stored in DustyDB. The class will automatically be given the methods and attributes of the L<DustyDB::Record> role. The meta-class will gain an additional meta-class role, L<DustyDB::Meta::Class>, containing the low-level storage routines. Finally, all the attributes will have additional features added through L<DustyDB::Meta::Attribute>, such as the ability to assign an encoder and decoder subroutine.

=begin Pod::Coverage

  init_meta

=end Pod::Coverage

=cut

sub init_meta {
    my ($class, %options) = @_;

    Moose->init_meta(%options);

    Moose::Util::MetaRole::apply_metaclass_roles(
        for_class                 => $options{for_class},
        metaclass_roles           => [ 'DustyDB::Meta::Class' ],
        attribute_metaclass_roles => [ 'DustyDB::Meta::Attribute' ],
        instance_metaclass_roles  => [ 'DustyDB::Meta::Instance' ],
    );

    Moose::Util::apply_all_roles($options{for_class}, 'DustyDB::Record');

    return $options{for_class}->meta;
}

=head1 METHODS

=head2 primary_key

TODO Add documentation

=cut

sub primary_key(@) {
    my (@columns) = @_;

    my $package = caller;
    my @fields = map { 
        $package->meta->get_attribute($_) 
            or Carp::croak(qq{Could not find attribute named "$_" for primary key.})
    } @columns;

    my $primary_key = DustyDB::Index::PrimaryKey->new( 
        record_meta => $package->meta,
        fields      => \@fields,
    );
    push @{ $package->meta->indexes }, $primary_key;
    return $primary_key;
}

=head2 key

B<REMOVED.> See L</primary_key>. At one time you could:

  has key foo => ( is => 'rw', isa => 'Str' );

But now you:

  has foo => ( is => 'rw', isa => 'Str' );
  primary_key qw( foo );

=cut

sub key($%) {
    Carp::croak('The "key" subroutine has been removed. Use "primary_key" instead.');
}

1;
