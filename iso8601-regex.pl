#!/usr/bin/env perl

# Builder of regex for iso8601 full date time values on a given year range
# Leap/non-leap years are handled.
# License: Apache 2.0
# Author: Olivier Mengué <dolmen@cpan.org>

use 5.010;
use strict;
use warnings;
use Regexp::Assemble;

use Getopt::Long;

my $year_min = 1600;
my $year_max = 2200;
my ($date_sep, $time_sep) = ('', '');
my $with_leap_seconds;

GetOptions(
    "year-min=i" => \$year_min,
    "year-max=i" => \$year_max,
    "date-separator=s" => sub { $date_sep = quotemeta $_[1] },
    "time-separator=s" => sub { $time_sep = quotemeta $_[1] },
    # Not yet implemented
    #"with-leap-second" => \$with_leap_seconds,
    #"with-millis=s"  # 'req'/'opt'
) or die;



sub fix_regexp
{
    if (defined wantarray) {
	# Make a copy
	fix_regexp(my $re = shift);
	$re
    } else {
	# Modify in place
	$_[0] =~ s/\(\?\^:/(?:/g;
	$_[0] =~ s/\|1\\d\|2\\d\)/|[12][0-9]\)/g;
	$_[0] =~ s/\[123456789\]/[1-9]/g;
	$_[0] =~ s/\(\?:1\[01345789\]\|3\[01345789\]\|5\[01345789\]\|7\[01345789\]\|9\[01345789\]\|0\[1235679\]\|2\[1235679\]\|4\[1235679\]\|6\[1235679\]\|8\[1235679\]\)/(?:[02468][1235679]|[13579][01345789])/g;
	$_[0] =~ s/\(\?:0\[01235679\]\|1\[01345789\]\|3\[01345789\]\|5\[01345789\]\|7\[01345789\]\|9\[01345789\]\|2\[1235679\]\|4\[1235679\]\|6\[1235679\]\|8\[1235679\]\)/(?:0[0-35679]|[13579][01345789]|[2468][1235679])/g;
	$_[0] =~ s/\(\?:0\[048\]\|2\[048\]\|4\[048\]\|6\[048\]\|8\[048\]\|1\[26\]\|3\[26\]\|5\[26\]\|7\[26\]\|9\[26\]\)/(?:[02468][048]|[1357][26])/g;
	# \\d can match Unicode non-Latin1 digits
	$_[0] =~ s/\\d/[0-9]/g;
    }
}

sub build_regexp (&)
{
    my $ra = Regexp::Assemble->new->reduce(1);
    local $_ = $ra;
    $_[0]->();
    fix_regexp(my $re = $ra->as_string);
    $re
}


my ($re_years_leap, $re_years_nonleap) = do {
    my $ra_years_leap = Regexp::Assemble->new->reduce(1);
    my $ra_years_nonleap = Regexp::Assemble->new->reduce(1);

    for(my $y=$year_min; $y <= $year_max; $y++) {
	if ($y % 400 == 0 || ($y % 4 == 0 && $y % 100 != 0)) {
	    $ra_years_leap->add("$y");
	} else {
	    $ra_years_nonleap->add("$y");
	}
    }
    map { fix_regexp($_) } ($ra_years_leap->re, $ra_years_nonleap->re)
};

my @DAYS_LEAP    = ( 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 );
my @DAYS_NONLEAP = ( 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 );

sub days_re
{
    my $days = shift;
    build_regexp {
	for(my $m = 1; $m <= scalar @$days; $m++) {
	    for(my $d = $days->[$m-1]; $d >= 1; $d--) {
		$_->add(sprintf("%02d%s%02d", $m, $date_sep, $d));
	    }
	}
    }
}


#my $DAYS_LEAP    = days_re(\@DAYS_LEAP);
#my $DAYS_NONLEAP = days_re(\@DAYS_NONLEAP);

my $DAYS_COMMON = "(?:0[13578]|1[02])$date_sep(?:0[1-9]|[12][0-9]|3[01])|(?:0[469]|11)$date_sep(?:0[1-9]|[12][0-9]|30)";
my $DAYS_LEAP    = '(?:' . $DAYS_COMMON . "|02$date_sep(?:[02][1-9]|1[0-9]))";
my $DAYS_NONLEAP = '(?:' . $DAYS_COMMON . "|02$date_sep(?:0[1-9]|1[0-9]|2[0-8]))";


#say $DAYS_LEAP;
#say $re_years_leap;
#exit;


my $re =
    '^(?:' . $re_years_nonleap . $date_sep . $DAYS_NONLEAP . '|'
           . $re_years_leap    . $date_sep . $DAYS_LEAP    . ')'
    . 'T'
    # Hours
    . '(?:[01][0-9]|2[0-3])'
    . $time_sep
    # Minutes
    # TODO leap second
    . '[0-5][0-9]'
    . $time_sep
    # Seconds
    . '[0-5][0-9]'
    # TODO Milli-seconds
    # TODO Offset
    . '$'
    ;


say $re;

