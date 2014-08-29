package DateTimeX::Period;
use parent DateTime;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Carp;
use Try::Tiny;

=head1 NAME

DateTimeX::Period - simple subclass of DateTime, which provides simple methods
to work in period context such as a day.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

	use DateTime::TimeZone qw();
	use DateTimeX::Period qw();

	my $dt = DateTimeX::Period->from_epoch(
		epoch => time(),
		time_zone => DateTime::TimeZone->new( name => 'local' )->name()
	);
	my $interval_start = $dt->get_start('month');
	my $interval_end   = $dt->get_end('month');

=cut

# Valid period keys and labels in preserved order
my @period_lookup = (
    '10 minutes', '10 minutes',
    'hour'      , 'Hour'      ,
    'day'       , 'Day'       ,
    'week'      , 'Week'      ,
    'month'     , 'Month'
);
my ( @ordered_periods, %period_labels );
while (@period_lookup) {
    my $key = shift @period_lookup;
    my $name = shift @period_lookup;
    push(@ordered_periods, $key);
    $period_labels{$key} = $name;
}

=head1 METHODS

=head2 get_start($period)

Returns DateTime object with the start of the given period.

The start date/time depends in which context period is provided:
- if it's a day, than midnight of that day
- if it's a week, than Monday at midnight of that week
- if it's a month, than 1st day at midnight of that month
- and etc.

=cut

sub get_start
{
	my ( $self, $period ) = @_;

	# Unfortunately by design DateTime mutates original object, hence cloning it
	my $dt = $self->clone();

	if ( $period eq '10 minutes' )
	{
		$dt->truncate( to => 'minute')->subtract(minutes => $dt->minute % 10);
		# Perl DateTime library always returns later date, when date occurs
		# twice despite it has ability not to do that. Following while loop
		# checks that start of the 10 minutes period would not be later then
		# orifinal object.
		while ( $dt->epoch > $self->epoch )
		{
			$dt->subtract( minutes => 10 );
		}
		return $dt;
	} elsif ( $period eq 'hour') {
		# truncate to hours is not safe too!!! think of this test case:
		# DateTime->from_epoch(epoch => 1268539500,time_zone => 'America/Goose_Bay')
		# 	->truncate( to => 'hour' );
		#
		# This initialises DateTime object from epoch 1268539500, which
		# corresponds to 2010-03-14 01:05:00, then tries to truncate to hours,
		# but fails/dies, because in some locations such as Newfoundland and
		# Labrador, i.e. ( America/St_Johns ) ( America/Goose_Bay ) on
		# 2010-03-14 clocks moved from 00:01 to 01:01.
		# This library fixes it, by getting start of hour as 00:00 and the end
		# of period 'hour' as 02:00, because 00:01 - 01:01 did not exist.
		try {
			$dt->truncate( to => 'hour' );
		} catch {
			$dt->subtract( minutes => $dt->minute );
		};
		# same reason as with minutes.
		while ($dt->epoch > $self->epoch )
		{
			$dt->subtract( hours => 1 );
		}
		return $dt;
	} elsif ( $period eq 'day') {
		try {
			$dt->truncate( to => 'day' );
		} catch {
			$dt = _get_start_of_the_day($dt);
		};
		return $dt;
	} elsif ( $period eq 'week') {
		try {
			$dt->truncate( to => 'week' );
		} catch {
			my $day_of_week = $dt->day_of_week;

			# set to monday, so that we would be on the right day
			if ( $day_of_week > 1 ) {
				$dt->set_hour(12)->subtract( days => $day_of_week - 1 );
			}
			$dt = _get_start_of_the_day($dt);
		};
		return $dt;
	} elsif ( $period eq 'month') {
		try {
			$dt->truncate( to => 'month' );
		} catch {
			$dt->set_hour(12)->set_day(1);
			$dt = _get_start_of_the_day($dt);
		};
		return $dt;
	} else {
		croak "found unknown period '$period'";
	}
}

=head2 get_end($period)

Returns DateTime object with end of the given period, which is same as start
of the next period.

The end date/time depends in which context period is provided:
- if it's a day, than midnight of the next day
- if it's a week, than Monday at midnight of the following week
- if it's a month, than 1st day at midnight of the following month
- and etc.

In cases where midnight does not exist, the start of those periods are not at
midnight, but this should not affect the end of the period, which is the same
as the start of the next period. if it happens to be not at midnight, which
might happen in case of 'day', 'week' or 'month' try to truncate, if it fails
gracefully fallback to another algorithm.

=cut

sub get_end
{
	my ( $self, $period ) = @_;

	# Get the start of the period
	my $dt = $self->get_start($period);

	# Return start of the period + its duration
	if ( $period eq '10 minutes' )
	{
		return $dt->add( minutes => 10 );
	} elsif ( $period eq 'hour') {
		return $dt->add( hours => 1 );
	} elsif ( $period eq 'day') {
		try {
			$dt->add( days => 1 );
			if ($dt->hour() + $dt->minute() + $dt->second > 0)
			{
				$dt->truncate( to => 'day' );
			}
		} catch {
			$dt->set_hour(12)->add( days => 1 );
			$dt = _get_start_of_the_day($dt);
		};
		return $dt;
	} elsif ( $period eq 'week') {
		try {
			$dt->add( weeks => 1 );
			if ($dt->hour() + $dt->minute() + $dt->second > 0)
			{
				$dt->truncate( to => 'week' );
			}
		} catch {
			$dt->set_hour(12)->add( weeks => 1 );
			$dt = _get_start_of_the_day($dt);
		};
		return $dt;
	} elsif ( $period eq 'month') {
		try {
			$dt->add( months => 1 );
			if ($dt->hour() + $dt->minute() + $dt->second > 0)
			{
				$dt->truncate( to => 'month' );
			}
		} catch {
			$dt->set_hour(12)->add( months => 1 );
			$dt = _get_start_of_the_day($dt);
		};
		return $dt;
	} else {
		croak "found unknown period '$period'";
	}
}

=head2 get_period_keys()

Returns all period keys in preserved order.

=cut

sub get_period_keys
{
	my ( $self ) = @_;

	return \@ordered_periods;
}

=head2 get_period_label($key)

Returns period label.

=cut

sub get_period_label
{
	my ( $self, $key ) = @_;
	croak "found unknown key '$key'" if (not exists $period_labels{$key} );

	return $period_labels{$key};
}

# _get_start_of_the_day($dt)
#
# internal subroutine to get the start of the day. This assumes DST does not
# happen at 12 midday.
#

sub _get_start_of_the_day
{
	my ( $dt ) = @_;

	# save the current day
	my $date = $dt->day();

	# to be on the safe side, set clock to 12:00:00, so we would not need to
	# deal with minutes or seconds
	$dt->set_hour(12)->set_minute(0)->set_second(0);

	# it should be safe now to get the previous day.
	my $newdate = $dt->clone()->subtract(days => 1)->day();

	# keep subtracting by 1 hour, until you reach previous day
	while ( $date != $newdate )
	{
		$dt->subtract( hours => 1 );
		$date = $dt->day();
	}
	# now add 1 hour back, so we know we are in correct day
	$dt->add( hours => 1 );

	return $dt;
}

=head1 CAVEATS

In timezones such as America/Sao_Paulo, Asia/Beirut, Asia/Damascus etc. etc.
DST happens at midnight. For these occassions, library falls back to another
algorithm for calculating start/end of interval. On these occasions assumption
is made that in those timezones DST will never happen at 12am and again at 12pm
( see _get_start_of_the_day subroutine ).

Start of the week is always Monday.


=head1 AUTHOR

Vytas Dauksa, C<< <vytas.dauksa at smoothwall.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-datetimex-period at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DateTimeX-Period>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DateTimeX::Period


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=DateTimeX-Period>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/DateTimeX-Period>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/DateTimeX-Period>

=item * Search CPAN

L<http://search.cpan.org/dist/DateTimeX-Period/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014 Smoothwall.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of DateTimeX::Period
