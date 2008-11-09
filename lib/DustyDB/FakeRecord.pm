package DustyDB::FakeRecord;
use Moose;

has model => (
    is => 'rw',
    isa => 'DustyDB::Model',
    required => 1,
);

has class_name => (
    is => 'rw',
    isa => 'ClassName',
    required => 1,
);

has key => (
    is => 'rw',
    isa => 'HashRef',
    required => 1,
);

sub isa {
    my ($self, $other_class_name) = @_;

    if (ref $self) {
        return $self->class_name->isa($other_class_name);
    }
    else {
        return $self->SUPER::isa($other_class_name);
    }
}

sub vivify {
    my $self = shift;
    return $self->model->load( %{ $self->key } );
}

1;
