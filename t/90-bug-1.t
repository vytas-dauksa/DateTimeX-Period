#!/usr/bin/env perl

use warnings;
use strict;

use Test::More;
use Test::Exception;
use DateTimeX::Period qw();

# At the end of Thursday, 29 December 2011, Samoa continued directly to
# Saturday, 31 December 2011, skipping the entire calendar day of Friday
# 30 December 2011 ( source: http://en.wikipedia.org/wiki/Time_in_Samoa )

my $dt = DateTimeX::Period->from_epoch(
	epoch => 1325152800, # 2011-12-29T00:00:00
	time_zone => 'Pacific/Apia'
);

TODO: {
	local $TODO = "Bug #1 - should not throw runtime error";

	lives_ok{
		$dt->get_end('day')
	} "The end of 29/11/2011 is start of 31/11/2011";
};

done_testing();
