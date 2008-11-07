package DustyDB::Object;
use Moose;

use DustyDB::Record;
use DustyDB::Meta::Class;
use DustyDB::Meta::Attribute;

use Moose::Exporter;

Moose::Exporter->setup_import_methods(
    as_is => [ 'key' ],
    also  => 'Moose',
);

sub init_meta {
    my ($class, %options) = @_;

    Moose->init_meta(%options);

    Moose::Util::MetaRole::apply_base_class_roles(
        for_class       => $options{for_class},
        roles           => [ 'DustyDB::Record' ],
        metaclass_roles => [ 'DustyDB::Meta::Class' ],
        attribute_roles => [ 'DustyDB::Meta::Attribute' ],
    );

    return $options{for_class}->meta;
}

sub key($%) {
    my ($column, %params) = @_;
    if ($params{traits}) {
        push @{ $params{traits} }, 'DustyDB::Key';
    }
    else {
        $params{traits} = [ 'DustyDB::Key' ];
    }
    return ($column, %params);
}

1;
