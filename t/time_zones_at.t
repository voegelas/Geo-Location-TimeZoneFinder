#!perl

# SPDX-License-Identifier: Artistic-1.0-Perl OR GPL-1.0-or-later

use 5.016;
use warnings;
use utf8;

use Test::More;

use File::Spec::Functions qw(catfile);

BEGIN {
    use_ok 'Geo::Location::TimeZoneFinder';
}

my $file_base = catfile(qw(shapereader tests data polygon));

ok !eval { Geo::Location::TimeZoneFinder->new },
    'constructor without "file_base" parameter dies';

ok !eval { Geo::Location::TimeZoneFinder->new(file_base => 'nonexistent') },
    'constructor with non-existing files dies';

# Ensure that the module is subclassable by using an empty subclass.
@Geo::Location::TimeZoneFinder::Subclass::ISA
    = qw(Geo::Location::TimeZoneFinder);

my $finder = new_ok 'Geo::Location::TimeZoneFinder::Subclass' =>
    [file_base => $file_base];

can_ok $finder, qw(time_zones_at time_zone_at index);

subtest 'mandatory' => sub {
    ok !eval { $finder->time_zones_at(longitude => 0) },
        'time_zones_at without latitude dies';
    like $@, qr/mandatory/, 'missing mandatory latitude argument';

    ok !eval { $finder->time_zones_at(latitude => 0) },
        'time_zones_at without longitude dies';
    like $@, qr/mandatory/, 'missing mandatory longitude argument';
};

subtest 'non-numerics' => sub {
    ok !eval { $finder->time_zones_at(lat => 'y', lon => 0) },
        'time_zones_at with non-numeric latitude dies';
    like $@, qr/not numeric/, 'non-numeric latitude argument';

    ok !eval { $finder->time_zones_at(lat => 0, lon => 'x') },
        'time_zones_at with non-numeric longitude dies';
    like $@, qr/not numeric/, 'non-numeric longitude argument';
};

subtest 'out of range' => sub {
    ok !eval { $finder->time_zones_at(lat => -90.0001, lon => 0) },
        'time_zones_at with too small latitude dies';
    like $@, qr/not a number between/, 'out of range lat argument warning matches';

    ok !eval { $finder->time_zones_at(lat => 90.0001, lon => 0) },
        'time_zones_at with too big latitude dies';
    like $@, qr/not a number between/, 'out of range lat argument warning matches';

    ok !eval { $finder->time_zones_at(lat => "nan", lon => 0) },
        'time_zones_at with undefined latitude dies';
    like $@, qr/not a number between/, 'out of range lat argument warning matches';

    ok !eval { $finder->time_zones_at(lat => 0, lon => -180.0001) },
        'time_zones_at with too small longitude dies';
    like $@, qr/not a number between/, 'out of range lon argument warning matches';

    ok !eval { $finder->time_zones_at(lat => 0, lon => 180.0001) },
        'time_zones_at with too big longitude dies';
    like $@, qr/not a number between/, 'out of range lon argument warning matches';

    ok !eval { $finder->time_zones_at(lat => 0, lon => "nan") },
        'time_zones_at with undefined longitude dies';
    like $@, qr/not a number between/, 'out of range lon argument warning matches';
};

my @tuples = (
    [   47.650499, -122.35007,  'America/Los_Angeles', 'both numbers' ],
    [qw(47.650499  -122.35007), 'America/Los_Angeles', 'both strings' ],
);

foreach my $tuple (@tuples) {
    my($lat, $lon, $tz, $label) = @$tuple;
    subtest $label => sub {
        my %short = (lat => $lat, lon => $lon);
        my %long  = (latitude => $short{lat}, longitude => $short{lon});

        my $ok = grep { $_->{time_zone} eq $tz } @{$finder->index};
        ok $ok, 'time zone exists in index';

        is_deeply [$finder->time_zones_at(%short)], [$tz],
            'find time zone with abbreviated location parameters';

        is_deeply [$finder->time_zones_at(%long)], [$tz],
            'find time zone with long location parameters';
    };
}

subtest 'time_zone_at' => sub {
    is $finder->time_zone_at(lat => 0, lon => 0), 'Etc/GMT',
        'find time zone at sea';

    is_deeply [sort $finder->time_zones_at(lat => 9.5, lon => 28.0)],
        ['Africa/Juba', 'Africa/Khartoum'], 'two time zones in disputed area';

    is_deeply [sort $finder->time_zones_at(lat => 40, lon => 180)],
        ['Etc/GMT+12', 'Etc/GMT-12'], 'two time zones at +180 longitude';

    is_deeply [sort $finder->time_zones_at(lat => 40, lon => -180)],
        ['Etc/GMT+12', 'Etc/GMT-12'], 'two time zones at -180 longitude';

    is_deeply [$finder->time_zones_at(lat => 40, lon => 179.9999)],
        ['Etc/GMT-12'], 'only one time zone at +179.9999 longitude';

    is_deeply [$finder->time_zones_at(lat => 40, lon => -179.9999)],
        ['Etc/GMT+12'], 'only one time zone at -179.9999 longitude';

    is_deeply [sort $finder->time_zones_at(lat => 40, lon => -157.5)],
        ['Etc/GMT+10', 'Etc/GMT+11'], 'two time zones at boundary';

    my @ocean_zones = $finder->time_zones_at(lat => 90, lon => 0);
    cmp_ok @ocean_zones, '==', 25, 'all ocean time zones at north pole';
};

done_testing;
