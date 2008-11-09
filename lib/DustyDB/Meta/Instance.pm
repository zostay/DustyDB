package DustyDB::Meta::Instance;
use Moose::Role;

use Scalar::Util qw( reftype );

=head2 get_slot_value

This is enhanced to perform deferred loading of FK objects.

=cut

override get_slot_value => sub {
    my ($instance, $struct, $name) = @_;
    my $value = super($struct, $name);

    if (blessed $value and blessed($value)->isa('DustyDB::FakeRecord')) {
        $value = $value->vivify;
        $instance->set_slot_value($struct, $name, $value);
    }

    return $value;
};

override inline_get_slot_value => sub {
    my ($instance, $struct, $name) = @_;
    my $super = super($struct, $name);

    return q#do {
        my $value = # . $super . q#;

        if (Scalar::Util::blessed($value) and Scalar::Util::blessed($value)->isa('DustyDB::FakeRecord')) {
            $value = $value->vivify;
        }

        $value;
    }#;
};

1;
