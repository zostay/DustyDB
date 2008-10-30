package DustyDB;
use Moose;
use MooseX::Types::Path::Class;

use DBM::Deep;

use DustyDB::Key;
use DustyDB::Model;
use DustyDB::Record;
use DustyDB::Collection;

=head1 SYNOPSIS

  # Declare a model
  package Book;
  use Moose -traits => 'DustyDB::Record';

  has title  => ( is => 'rw', isa => 'Str',   traits => [ 'DustyDB::Key' ] );
  has author => ( is => 'rw', isa => 'Author' );

  # Declare another model
  package Author;
  use Moose -traits => 'DustyDB::Record';

  has name => ( is => 'rw', isa => 'Str',     traits => [ 'DustyDB::Key' ] );

  # Get down to business
  package main;
  use DustyDB;

  # Create/connect to the database
  my $db = DustyDB->new( path => 'foo.db' );

  # Get the model classes used to work with records
  my $author = $db->model('Author');
  my $book   = $db->model('Book');

  {
      # Create a couple records
      my $the_damian = $author->new( name => 'Damian Conway' );
      my $pbp        = $book->new( 
          title  => 'Perl Best Practices', 
          author => $the_damian,
      );

      # Save them to the database
      $the_damian->save;
      $pbp->save;
  }

  {
      # Load some records
      my $the_damian = Author->load( 'Damian Conway' );
      my $pbp        = Book->load( 'Perl Best Practicies' );

      # Retrieve some information
      print "TheDamian is ", $the_damian->name, "\n";
      print "His book is ", $pbp->title, "\n";

      # Delete them
      $the_damian->delete;
      $pbp->delete;
  }

=head1 DESCRIPTION

Sometimes, I need to store an eeny-weeny bit of data, but I want it nicely structured with Moose, but I don't want to mess with a bunch of setup and bootstrapping and blah blah blah. I just want to write my script. This provides a mechanism to do that with very little overhead. There are very few frills either, so if you want something nicer, you'll have to build on or look into something else.

All the data is stored using L<DBM::Deep>, so if you want to dig deeper into what's going on here, you can open the database using that library without going through L<DustyDB>.

=head1 ATTRIBUTES

=head2 dbm

If you want to initialize the L<DBM::Deep> database used yourself, please supply a "dbm" argument to the C<new> constructor. You can also use this attribute to fetch the underlying L<DBM::Deep> object being used. All data used by DustyDB is stored in this as a hash. The only key of that hash that is used is "models". If you want to store additional information in the database, please avoid that key. 

Other keys might be used in the future, I suppose, but I can't know what that would be now so I'm not going to worry about it at the moment.

=cut

has dbm => (
    is       => 'rw',
    isa      => 'DBM::Deep',
    lazy     => 1,
    default  => sub {
        my $self = shift;
        return DBM::Deep->new( $self->path );
    },
);

=head2 path

This is the path to the L<DBM::Deep> database file. This must be supplied to the constructor, even if you supply your own "dbm" parameter.

=cut

has path => (
    is       => 'rw',
    isa      => 'Path::Class::File',
    required => 1,
    coerce   => 1,
);

=head1 METHODS

=head2 model

  my $model = $db->model( $model_class_name );

Given a model class name, this returns a L<DustyDB::Model>, which can be used to create model object and immediately save them to the database or load models stored in the database.

=cut

sub model {
    my $self       = shift;
    my $class_name = shift;
    return DustyDB::Model->new( db => $self, class_name => $class_name );
}

=head1 INTERNAL METHODS

=head2 table

Do not use this method unless you really need to. The regular interface is provided through L</model>. This provides access to the table of records in the database.

=cut

sub table {
    my ($self, $table) = @_;
    return $self->dbm->{'models'}{$table};
}

=head2 init_table

Do not use this method unless you really need to. This is used to perform some bootstrapping of the table in the database.

=cut

sub init_table {
    my ($self, $table) = @_;

    # Make sure the database and table are initialized
    $self->dbm->{'models'} = {} 
        unless defined $self->dbm->{'models'};
    $self->dbm->{'models'}{$table} = {}
        unless defined $self->dbm->{'models'}{$table};
}

=head1 MODULE NAME

Why DustyDB? Well, I wanted a "dead simple database." DSD. D-S-D. Dusty. DustyDB. Lame or not, it was it is.

=cut

1;
