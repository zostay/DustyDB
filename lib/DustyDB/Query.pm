package DustyDB::Query;
use Moose;

use Carp ();
use List::MoreUtils qw( natatime );

=head1 SYNOPSIS

  my $query = DustyDB::Query->new( model => $db->model('Person') );
  $query->where(    last_name => '=' => 'Anderson' );
  $query->or_where( last_name => '=' => 'Smith' );

  # TODO Boy, I sure would like to do this...
  # $query->or_where( 
  #     [ events => 'start_time' ] => '<=' => DateTime->now,
  #     [ events => 'end_time'   ] => '>'  => DateTime->now,
  # );

=cut

has model => (
    is       => 'ro',
    isa      => 'DustyDB::Model',
    required => 1,
    handles  => [ qw( db record_meta ) ],
);

has disjunctions => (
    is       => 'ro',
    isa      => 'ArrayRef',
    default  => sub { [] },
);

sub where {
    my ($self, @clause) = @_;

    # if we aren't given any limits, this is a no-op
    return unless @clause;

    my $iter = natatime(3, @clause);
    while (my ($field, $op, $value) = $iter->()) {
        if ($op ne '=') {
            Carp::croak(
                'Sorry, the "=" operator is the only supported operator '
                . 'at this time.'
            );
        }

        if (not $self->record_meta->has_attribute($field)) {
            my $class = $self->record_meta->name;
            Carp::croak(
                qq{The "$class" class does not have a "$field" field.}
            );
        }

        my $attr = $self->record_meta->get_attribute($field);
        eval {
            $attr->verify_against_type_constraint($value);
        };

        if ($@) {
            Carp::croak(
                qq{Sorry, "$value" is not valid for comparison with "$field": $@}
            );
        }
    }

    push @{ $self->disjunctions }, \@clause;
}

*or_where = *where;

sub explain {
    my $self = shift;

    # What are the indexes we can pull from?
    my $indexes = $self->record_meta->indexes;

    # This is a helpful subroutine for comparing how valuable indexes are for
    # this particular query
    my $collapse_fields = sub {
        join ':', 
        map  { s/:/::/g; $_ }
        sort @_;
    };

    # Start building the explanation with one "sub-explanation" per clause
    my @explanation;
    for my $clause (@{ $self->disjunctions }) {
        my $i = 0;
        my @field_op_clause = grep { $i++ % 3 != 2 } @$clause;

        # Determine which indexes are suitable
        my %indexes_by_fields;
        INDEX: for my $index (@$indexes) {
            # Which fields can this index lookup for us for this query:
            my $indexed_fields = $index->indexes_fields(\@field_op_clause);

            # If none, skip it
            next INDEX unless @$indexed_fields;

            # Create a string representation of that list and remember it
            my $largest_fields_key = $collapse_fields->(@$indexed_fields);
            unless (defined $indexes_by_fields{ $largest_fields_key }) {

                # The "1" indexes are ones we want to use and remember
                $indexes_by_fields{ $largest_fields_key } 
                    = [ 1, $index, $indexed_fields ];

                # Assume that subsets of these index are also useful
                if (@$indexed_fields > 1) {
                    for my $max_index (0 .. (@$indexed_fields - 2)) {
                        my $fields_key = $collapse_fields->(
                            @{ $indexed_fields }[0 .. $max_index]
                        );

                        # The "0" just marks that we can do this already in
                        # case a short index comes up later, we can easily
                        # ignore it
                        $indexes_by_fields{ $fields_key }
                            = [ 0, $index, $indexed_fields ];
                    }
                }
            }
        }

        # Match field names up with sub-clauses
        my %fields;
        my $iter = natatime 3, @$clause;
        while (my (@subclause) = $iter->()) {
            $fields{ $subclause[0] } = [ 1, @subclause ];
        }

        # Bring the sub-clauses into the matching indexes
        my %search;
        for my $index_info (grep { $_->[0] } values %indexes_by_fields) {
            my ($index, $indexed_fields) = @{ $index_info }[1, 2];

            my @fields;
            for my $field (@$indexed_fields) {

                # Mark this as a search field
                $fields{$field}[0] = 0;

                # Put it into the search on this index
                push @fields, @{ $fields{$field} }[1 .. 3];
            }

            # Rmember the index with the search
            $search{ $index->name } = \@fields;
        }

        # Anything left needs to be stuck into the post-search filter
        my @filter = map    { @{$_}[1 .. 3] }       # only the clause
                     sort   { $a->[1] cmp $b->[1] } # sort by field name
                     grep   { $_->[0] }             # only those unused
                     values %fields;

        # There could be additional filters tacked on, so remember this one as
        # the first filter to be applied to this clause
        my $filters = [];
        push @{ $filters }, \@filter if @filter;

        # Add the search and filter info to the explanation
        push @explanation => {
            search => \%search,
            filter => $filters,
        };
    }

    # If there's not explanation, we want everything, which is explained as...
    if (!@explanation) {
        push @explanation => {
            search => { primary_key => [] },
            filter => [],
        };
    }

    return \@explanation;
}

sub execute {
    my $self = shift;
    my $meta = $self->record_meta;
    my $db   = $self->db;

    # TODO This is highly inefficient. We should be able to grab keys in
    # small sections rather than nabbing them all at once.
    my @objects;

    my $explanations = $self->explain;
    for my $explain_clause (@$explanations) {
        my $search = $explain_clause->{search};

        my @keys;
        while (my ($index_name, $query) = each %$search) {
            my $index = $meta->get_index($index_name);

            # TODO We should be passing the query, but I'm taking the
            # conversion to the query "style" one step at a time
            my $i = 0;
            my %key = grep { $i++ % 3 != 1 } @$query;

            # TODO This needs some protection against duplicates
            @keys = @{ $index->lookup_keys(
                db  => $db,
                key => \%key,
            ) };
        }

        my $i;
        my $filter = $explain_clause->{filter};
        my @filter_keys = map { $i = 0; { grep { $i++ % 3 != 1 } @$_ } } 
                              @$filter;

        KEY: for my $key (@keys) {
            my $object = $meta->load_object( db => $db, key => [ %$key ]);
            
            for my $filter_key (@filter_keys) {
                while (my ($field, $value) = each %$filter_key) {
                    next KEY unless $object->$field eq $value;        
                }
            }

            push @objects, $object;
        }
    }

    return DustyDB::Collection->new(
        model   => $self->model,
        records => \@objects,
    )->contextual;
}

1;
