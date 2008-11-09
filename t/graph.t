use strict;
use warnings;

=head1 NAME

graph.t - create a graph of records

=head1 DESCRIPTION

This is a more thorough testing of foreign object relationships.

=cut

use Test::More tests => 1402;
use_ok('DustyDB');

# Declare a model
package Square;
use Moose;

with 'DustyDB::Record';

use overload 
    'bool' => sub { defined $a },
    '=='   => sub { $a->x == $b->x and $a->y == $b->y };

has x => (
    is => 'rw',
    isa => 'Int',
    traits => [ 'DustyDB::Key' ],
);

has y => (
    is => 'rw',
    isa => 'Int',
    traits => [ 'DustyDB::Key' ],
);

has north => (
    is => 'rw',
    isa => 'Square',
);

has east => (
    is => 'rw',
    isa => 'Square',
);

has south => (
    is => 'rw',
    isa => 'Square',
);

has west => (
    is => 'rw',
    isa => 'Square',
);

package main;

my $db = DustyDB->new( path => 't/graph.db' );
ok($db, 'Loaded the database object');
isa_ok($db, 'DustyDB');

my $square = $db->model('Square');
for my $x (0 .. 9) {
    for my $y (0 .. 9) {
        my $this_square = $square->create( x => $x, y => $y );

        is($this_square->x, $x, "this square.x = $x");
        is($this_square->y, $y, "this square.y = $y");
    }
}

for my $x (0 .. 9) {
    for my $y (0 .. 9) {
        my $this_square = $square->load( x => $x, y => $y );

        my $north_x = ($x + 9) % 10;
        my $east_y  = ($y + 1) % 10;
        my $south_x = ($x + 1) % 10;
        my $west_y  = ($y + 9) % 10;

        my $north_square = $square->load( x => $north_x, y => $y );
        my $east_square  = $square->load( x => $x, y => $east_y );
        my $south_square = $square->load( x => $south_x, y => $y );
        my $west_square  = $square->load( x => $x, y => $west_y );

        ok($north_square, "got a north square for ($x, $y)");
        ok($east_square,  "got an east square for ($x, $y)");
        ok($west_square,  "got a west square for ($x, $y)");
        ok($south_square, "got a south square for ($x, $y)");

        $this_square->north( $north_square );
        $this_square->east( $east_square );
        $this_square->south( $south_square );
        $this_square->west( $west_square );
        $this_square->save;
    }
}

for my $x (0 .. 9) {
    for my $y (0 .. 9) {
        my $this_square = $square->load( x => $x, y => $y );

        my $north_x = ($x + 9) % 10;
        my $east_y  = ($y + 1) % 10;
        my $south_x = ($x + 1) % 10;
        my $west_y  = ($y + 9) % 10;

        my $north_square = $square->load( x => $north_x, y => $y );
        my $east_square  = $square->load( x => $x, y => $east_y );
        my $south_square = $square->load( x => $south_x, y => $y );
        my $west_square  = $square->load( x => $x, y => $west_y );

        ok($north_square, "got a north square for ($x, $y)");
        ok($east_square,  "got an east square for ($x, $y)");
        ok($west_square,  "got a west square for ($x, $y)");
        ok($south_square, "got a south square for ($x, $y)");

        is($this_square->north, $north_square, "north is north ($x, $y)");
        is($this_square->east,  $east_square,  "east is east ($x, $y)");
        is($this_square->south, $south_square, "south is south ($x, $y)");
        is($this_square->west,  $west_square,  "west is west ($x, $y)");
    }
}

