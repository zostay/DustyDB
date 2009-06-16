#!/usr/bin/perl
use strict;
use warnings;

=head1 NAME

explain.t - make sure query explaination works

=cut

use Test::More tests => 10;
use Test::Moose;
use_ok('DustyDB');

package Person;
use DustyDB::Object;

# has key last_name  => ( is => 'rw', isa => 'Str' );
# has key first_name => ( is => 'rw', isa => 'Str' );
has last_name      => ( is => 'rw', isa => 'Str' );
has first_name     => ( is => 'rw', isa => 'Str' );
has favorite_color => ( is => 'rw', isa => 'Str' );
has age            => ( is => 'rw', isa => 'Int' );

primary_key qw( last_name first_name );

package main;

my $db = DustyDB->new( path => 't/explain.db' );
ok($db, 'Loaded the database object');
isa_ok($db, 'DustyDB');

my $person = $db->model('Person');

{
    my $query = DustyDB::Query->new( model => $person );
    my $explanation = $query->explain;

    is_deeply($explanation, [], 'explanation is empty');
}

{
    my $query = DustyDB::Query->new( model => $person );
    $query->where( 'last_name', '=', 'Johnson' );
    my $explanation = $query->explain;

    is_deeply($explanation, [{
        filter => [],
        search => { 
            primary_key => [
                'last_name', '=', 'Johnson',
            ],
        },
    }], 'search primary key for last_name');
}

{
    my $query = DustyDB::Query->new( model => $person );
    $query->where( 'first_name', '=', 'Dilbert' );
    my $explanation = $query->explain;

    is_deeply($explanation, [{
        filter => [
            [ 'first_name', '=', 'Dilbert' ],
        ],
        search => {},
    }], 'filter on first_name');
}

{
    my $query = DustyDB::Query->new( model => $person );
    $query->where( 
        'first_name', '=', 'Dilbert', 
        'last_name',  '=', 'Johnson',
    );
    my $explanation = $query->explain;

    is_deeply($explanation, [{
        filter => [],
        search => {
            primary_key => [
                'last_name',  '=', 'Johnson',
                'first_name', '=', 'Dilbert',
            ],
        },
    }], 'search on first_name and last_name');
}

{
    my $query = DustyDB::Query->new( model => $person );
    $query->where( 
        'age', '=', 90, 
    );
    my $explanation = $query->explain;

    is_deeply($explanation, [{
        filter => [
            [ 'age', '=', 90 ],
        ],
        search => {},
    }], 'filter on age');
}

{
    my $query = DustyDB::Query->new( model => $person );
    $query->where( 
        'first_name',     '=', 'Dilbert',
        'age',            '=', 90, 
        'favorite_color', '=', 'red',
    );
    my $explanation = $query->explain;

    is_deeply($explanation, [{
        filter => [
            [
                'age',            '=', 90,
                'favorite_color', '=', 'red',
                'first_name',     '=', 'Dilbert',
            ],
        ],
        search => {},
    }], 'filter on first_name, age, and favorite_color');
}

{
    my $query = DustyDB::Query->new( model => $person );
    $query->where( 
        'first_name',     '=', 'Dilbert',
        'last_name',      '=', 'Johnson',
        'age',            '=', 90, 
        'favorite_color', '=', 'red',
    );
    my $explanation = $query->explain;

    is_deeply($explanation, [{
        filter => [
            [
                'age',            '=', 90,
                'favorite_color', '=', 'red',
            ],
        ],
        search => {
            primary_key => [
                'last_name',  '=', 'Johnson',
                'first_name', '=', 'Dilbert',
            ],
        },
    }], 'search on first_name and last_name and filter on age and favorite_color');
}
