use strict;
use warnings;

=head1 NAME

collection.t - test of collections of records

=cut

use Test::More tests => 34;
use Test::Moose;
use_ok('DustyDB');

# Declare a model
package Thing;
use Moose;
with 'DustyDB::Record';

has name        => ( is => 'rw', isa => 'Str', traits    => [ 'DustyDB::Key' ] );
has description => ( is => 'rw', isa => 'Str', predicate => 'has_description' );

package main;

my $db = DustyDB->new( path => 't/collection.db' );
ok($db, 'Loaded the database object');
isa_ok($db, 'DustyDB');

my $thing = $db->model('Thing');
ok($thing, 'Loaded the thing model object');
isa_ok($thing, 'DustyDB::Model');

# Create some things
{
    $thing->create( name => 'test1', description => 'a thing' );
    $thing->create( name => 'test2', description => 'another thing' );
    $thing->create( name => 'test3' );
}

# Get a list of things
{
    my @things = $thing->all;
    is(scalar @things, 3, 'we got 3 things');

    for my $one_thing (@things) {
        isa_ok($one_thing, 'Thing');
    }
    
    is($things[0]->name, 'test1', 'thing 1 is test1');
    is($things[1]->name, 'test2', 'thing 2 is test2');
    is($things[2]->name, 'test3', 'thing 3 is test3');
}

# Get a iterator of things
{
    my $things = $thing->all;
    ok($things, 'we got an iterator');
    isa_ok($things, 'DustyDB::Collection');
    is($things->count, 3, 'got 3 things again');
    is($things->first->name, 'test1', 'first thing is test1');
    is($things->last->name, 'test3', 'last thing is test3');
    
    is($things->next->name, 'test1', 'next thing is test1');
    is($things->next->name, 'test2', 'next thing is test2');
    is($things->next->name, 'test3', 'next thing is test3');
}

# Try a filter in all()
{
    my $things = $thing->all( name => qr/[23]$/ );
    ok($things, 'we got an iterator');
    isa_ok($things, 'DustyDB::Collection');
    is($things->count, 2, 'got 2 things this time');
    is($things->next->name, 'test2', 'next thing is test2');
    is($things->next->name, 'test3', 'next thing is test3');
}

# Try a filter with all->filter()
{
    my $things = $thing->all->filter( 'has_description' );
    ok($things, 'we got an iterator');
    isa_ok($things, 'DustyDB::Collection');
    is($things->count, 2, 'got 2 things this time');
    is($things->next->name, 'test1', 'next thing is test1');
    is($things->next->name, 'test2', 'next thing is test2');
}

# Try a third filter with all_where()
{
    my $all_things = $thing->all;
    my $things = $all_things->filter( sub { $_->name eq 'test3' } );
    ok($things, 'we got an iterator');
    isa_ok($things, 'DustyDB::Collection');
    is($things->count, 1, 'got 1 things this time');
    is($things->next->name, 'test3', 'next thing is test3');
}

unlink 't/collection.db';
