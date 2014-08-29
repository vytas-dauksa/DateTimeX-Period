#!/usr/bin/perl
# Copyright 2014 Smoothwall Ltd.

use strict;
use warnings;

use Test::More;
use Test::Exception;

my ( $dt, $keys );

my $minute = 60;
my $hour   = 60 * 60;
my $day    = 60 * 60 * 24;

# Following epoch is special in UTC, as it is start of the month, week, day,
# hour and 10 minutes
my $start = 1409529600; # Monday 01/09/2014 00:00:00

sub test_start
{
	my ( $epoch, $period, $comment ) = @_;
	my $dt = DateTimeX::Period->from_epoch( epoch => $epoch);

	is( $dt->get_start($period)->epoch(), $start, $comment );
}

sub test_end
{
	my ( $expectation, $period, $comment ) = @_;
	my $dt = DateTimeX::Period->from_epoch( epoch => $start);

	is( $dt->get_end($period)->epoch(), $expectation, $comment );
}

use_ok('DateTimeX::Period');

# Test that DateTime returns something
lives_ok { DateTimeX::Period->from_epoch( epoch => $start )}
	'Lives ok on good parameter';

# add random number of seconds and try to get the start of the period
test_start($start +  9 * $minute, '10 minutes', 'Get the start of 10 minutes');
test_start($start + 59 * $minute, 'hour',       'Get the start of hour');
test_start($start + 23 * $hour,   'day',        'Get the start of day');
test_start($start +  6 * $day,    'week',       'Get the start of week');
test_start($start + 29 * $day,    'month',      'Get the start of month');

# Try to get the start of the interval, when it matches the start
test_start($start,                '10 minutes', '10 minutes boundary test');
test_start($start,                'hour',       'hour boundary test');
test_start($start,                'day',        'day boundary test');
test_start($start,                'week',       'week boundary test');
test_start($start,                'month',      'month boundary test');

test_end($start + 10 * $minute, '10 minutes', 'Get the end of 10 minutes');
test_end($start +  1 * $hour,   'hour',       'Get the end of hour');
test_end($start +  1 * $day,    'day',        'Get the end of day');
test_end($start +  7 * $day,    'week',       'Get the end of week');
test_end($start + 30 * $day,    'month',      'Get the end of month');

# Test that library works in year > 2038
my $friday = 4126032000; # Friday 01/10/2100 00:00:00

lives_ok {
	$dt = DateTimeX::Period->from_epoch( epoch => $friday + 8 * $day )
} 'Lives ok on year > 2038';

# Checking that start of October for year 2100 is Friday 01/10/2100 00:00:00
is(
	$dt->get_start('month')->epoch(),
	$friday,
	'Checking that module works correctly in year 2100'
);

# Test week boundary, which crosses month boundary, i.e. end of the week is
# after the 1st of month, but start of the week is before the 1st.
$dt = DateTimeX::Period->new(
	year => 2014,
	month => 2,
	day   => 2,
);

is (
	$dt->get_start('week')->ymd(),
	'2014-01-27',
	'can get start of the week that passes month boundary during the week.'
);

is (
	$dt->get_end('week')->ymd(),
	'2014-02-03',
	'can get end of the week that passes month boundary during the week.'
);

# DateTime default time zone is UTC, which does not have daylight saving,
# hence testing in America/Chicago time zone.
# test that due to daylight saving a day was 23 hours.
$dt = DateTimeX::Period->new(
	year      => 2003,
	month     => 4,
	day       => 6,
	hour      => 3,
	minute    => 59,
	second    => 59,
	time_zone => 'America/Chicago',
);

is(
	$dt->get_start('day')->epoch(),
	$dt->get_end('day')->epoch() - 23 * $hour,
	'06/04/2003 in America/Chicago timezone had only 23 hours'
);

# Time zone in Chatham Islands is special because daylight saving does not
# occur on explicit hour, but in fact it changes at 02:45 <-> 03:45.
# on 07/04/2019 DST ends in Chatham Island, and 02:45 - 03:45 happens twice.
$dt = DateTimeX::Period->new(
		year      => 2019,
		month     => 4,
		day       => 7,
		hour      => 2,
		minute    => 44,
		time_zone => 'Pacific/Chatham',
);

is(
	$dt->get_start('day')->epoch(),
	$dt->get_end('day')->epoch() - 25 * $hour,
	'07/04/2019 in Pacific/Chatham America/Chicago timezone has 25 hours'
);

is(
	$dt->get_end('hour')->hms,
	'03:00:00',
	'3AM occurs first time'
);

is(
	$dt->get_end('hour')->get_end('hour')->hms,
	'03:00:00',
	'3AM occurs second time'
);

# 'America/Goose_Bay' time zone is interesting, because in 2010/03/14 clock
# moved forward from 00:01 to 01:01, hence the start of the hour is 00:00, but
# the end of the hour is 02:00.
$dt = DateTimeX::Period->new(
	year   => 2010,
	month  => 3,
	day    => 14,
	hour   => 1,
	minute => 5,
	time_zone => 'America/Goose_Bay'
);

is(
	$dt->get_start('hour')->hms,
	'00:00:00',
	'start of hour for America/Goose_Bay at 01:05 is 00:00 due to DST'
);

is(
	$dt->get_end('hour')->hms,
	'02:00:00',
	'end of hour for America/Goose_Bay at 01:05 is 01:10'
);

is(
	$dt->get_start('10 minutes')->hms,
	'00:00:00',
	'start of 10 minutes for America/Goose_Bay at 01:05 is 00:00 due to DST'
);

is(
	$dt->get_end('10 minutes')->hms,
	'01:10:00',
	'end of 10 minutes for America/Goose_Bay at 01:05 is 01:10'
);

# In 'Asia/Tehran' on 2010-03-22 time moved forward at midnight (
# 00:00 -> 01:00 ). It is interesting timezone, because DST often happens at
# the beginning of the week at midnight.
$dt = DateTimeX::Period->new(
	year      => 2010,
	month     => 3,
	day       => 22,
	hour      => 1,
	minute    => 5,
	time_zone => 'Asia/Tehran'
);

is (
	$dt->get_start('week')->iso8601(),
	'2010-03-22T01:00:00',
	'start on Monday and get start of the week, on which DST is at midnight'
);

is (
	$dt->get_end('week')->iso8601(),
	'2010-03-29T00:00:00',
	'start on Monday and get end of the week, on which DST is at midnight'
);

is (
	$dt->clone()->add(days => 3)->get_start('week')->iso8601(),
	'2010-03-22T01:00:00',
	'start in the middle of the week and get beginning of it, when DST occurs'
);

is (
	$dt->clone()->subtract(weeks => 1)->get_end('week')->iso8601(),
	'2010-03-22T01:00:00',
	'get end of the week, after which DST happens at midnight'
);

is (
	$dt->get_start('day')->iso8601(),
	'2010-03-22T01:00:00',
	'get start of the day, on which DST happened at midnight'
);

is (
	$dt->get_end('day')->iso8601(),
	'2010-03-23T00:00:00',
	'get end of the day, on which DST happened at midnight'
);

is (
	$dt->clone()->subtract(days => 1)->get_end('day')->iso8601(),
	'2010-03-22T01:00:00',
	'get end of the day, after which DST happens at midnight'
);

# In 'Asia/Amman' on 2011-04-01 time moved forward ( 00:00 -> 01:00 ). It is
# interesting timezone, because DST often happens at the beginning of the month
# at midnight
$dt = DateTimeX::Period->new(
	year   => 2011,
	month  => 4,
	day    => 1,
	hour   => 1,
	minute => 5,
	time_zone => 'Asia/Amman'
);

is(
	$dt->get_start('month')->iso8601(),
	'2011-04-01T01:00:00',
	'get start of the month, on which DST happened at midnight'
);

is(
	$dt->get_end('month')->iso8601(),
	'2011-05-01T00:00:00',
	'get end of the month, on which DST happened at midnight'
);

is(
	$dt->clone()->subtract(months => 1)->get_end('month')->iso8601(),
	'2011-04-01T01:00:00',
	'get end of the month, after which DST happens at midnight'
);

# Perl DateTime library always returns later date, when something happens
# twice, for instance due to DST.
# Such case happens in 'Atlantic/Azores' on 2013-10-27, when clocks moves back
# to midnight ( 01:00 -> 00:00 ),
$dt = DateTimeX::Period->new(
	year   => 2013,
	month  => 10,
	day    => 26,
	hour   => 23,
	minute => 50,
	time_zone => 'Atlantic/Azores'
);

is(
	$dt->get_end('10 minutes')->get_end('10 minutes')->epoch(),
	$dt->epoch() + 20 * $minute,
	'Check that library returns correct epoch, i.e. earlier epoch in this case'
);

dies_ok {
	$dt->get_start('doesnotexist')
} 'get_start() dies on unknown period';

dies_ok {
	$dt->get_end('doesnotexist')
} 'get_end() dies on unknown period';

lives_ok {
	$keys = $dt->get_period_keys()
} 'Can get ordered list of keys';

ok( !grep(!defined $dt->get_period_label($_), @{$keys} ),
	'all defined keys has value corresponding');

dies_ok {
	$dt->get_period_label('doesnotexist')
} 'get_period_label() dies on undefined key';

done_testing();
