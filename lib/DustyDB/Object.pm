package DustyDB::Object;
use Moose;
use Moose::Util;
use Moose::Util::MetaRole;

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

    Moose::Util::apply_all_roles($options{for_class}, 'DustyDB::Record');
    $options{for_class}->does('DustyDB::Record')
        or die "WTF?\n";
    Moose::Util::MetaRole::apply_metaclass_roles(
        for_class                 => $options{for_class},
        metaclass_roles           => [ 'DustyDB::Meta::Class' ],
        attribute_metaclass_roles => [ 'DustyDB::Meta::Attribute' ],
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
