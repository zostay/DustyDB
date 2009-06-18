package DustyDB::Index;
use Moose::Role;

use Moose::Util qw( apply_all_roles );

has name => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has record_meta => (
    is       => 'ro',
    does     => 'DustyDB::Meta::Class',
#    isa      => 'DustyDB::Meta::Class',
    required => 1,
    weak_ref => 1,
);

has fields => (
    is       => 'ro',
    isa      => 'ArrayRef',
    required => 1,
);

requires qw( lookup_keys );

sub complete_key {
    my ($self, @wanted_fields) = @_;
    my $indexed_fields = $self->fields;
    
    my $found = scalar @{ $indexed_fields };
    my %indexed_fields = map { $_->name => 1 } @{ $indexed_fields };

    for my $wanted_field (@wanted_fields) {
        $found-- if $indexed_fields{ $wanted_field };
    }

    return $found == 0;
}

sub indexes_fields {
    my ($self, $wanted_fields) = @_;
    my %wanted_fields = @$wanted_fields;

    my $indexed_fields = $self->fields;
    
    my @indexes_fields;
    for my $index_field (@$indexed_fields) {
        last unless defined $wanted_fields{ $index_field->name };
        push @indexes_fields, $index_field->name;
    }

    return \@indexes_fields;
}

sub build_key {
    my $self = shift;
    my $meta = $self->record_meta;
    my %keys;

    # We have a record that needs to be decomposed
    if (blessed $_[0] and $_[0]->isa($meta->name)) {
        for my $key (@{ $self->fields }) {
            $keys{ $key->name } 
                = $key->perform_stringify($key->get_value($_[0]));
        }
    }

    # A single argument and a single column key
    elsif (@_ == 1 and @{ $self->fields } == 1) {
        my $key = $self->fields->[0];
        $keys{ $key->name } = $key->perform_stringify($_[0]);
    }
    
    # A multi-column key must be given with a hashref
    else {
        my %params = @_;
        for my $key (@{ $self->fields }) {
            if (exists $params{ $key->name }) {
                $keys{ $key->name } 
                    = $key->perform_stringify($params{ $key->name });
            }
        }
    }

    return \%keys;
}

1;
