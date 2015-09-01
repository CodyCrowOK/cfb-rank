#!/usr/bin/env perl

use strict;
use warnings;
use feature ":5.10";

use Text::CSV;

use constant e => 2.718281828459;

my $input = "input.csv";
my $output = "output.csv";

my $columns = {
	date => 0,
	visitor => 1,
	visitor_rushing_yards => 2,
	visitor_rushing_attempts => 3,
	visitor_passing_yards => 4,
	visitor_passing_attempts => 5,
	visitor_passing_completions => 6,
	visitor_penalties => 7,
	visitor_penalty_yards => 8,
	visitor_fumbles_lost => 9,
	visitor_picks_thrown => 10,
	visitor_first_down => 11,
	visitor_third_down_attempts => 12,
	visitor_third_down_conversions => 13,
	visitor_fourth_down_attempts => 14,
	visitor_fourth_down_conversions => 15,
	visitor_time_of_possesion => 16,
	visitor_score => 17,
	home => 18,
	home_rushing_yards => 19,
	home_rushing_attempts => 20,
	home_passing_yards => 21,
	home_passing_attempts => 22,
	home_passing_completions => 23,
	home_penalties => 24,
	home_penalty_yards => 25,
	home_fumbles_lost => 26,
	home_picks_thrown => 27,
	home_first_down => 28,
	home_third_down_attempts => 29,
	home_third_down_conversions => 30,
	home_fourth_down_attempts => 31,
	home_fourth_down_conversions => 32,
	home_time_of_possesion => 33,
	home_score => 34,
};

open my $fh, "<", $input or die "$input: $!";
my $csv = Text::CSV->new({
	binary    => 1, # Allow special character. Always set this
	auto_diag => 1, # Report irregularities immediately
});

#column names
$csv->getline($fh);

while (my $row = $csv->getline($fh)) {
	say $row->[$columns->{visitor}] . " at " . $row->[$columns->{home}];

        my $rushing_ypc = $row->[$columns->{visitor_rushing_yards}] / $row->[$columns->{visitor_rushing_attempts}];
        my $passing_ypa = $row->[$columns->{visitor_passing_yards}] / $row->[$columns->{visitor_passing_attempts}];
        my $total_yards = $row->[$columns->{visitor_rushing_yards}] + $row->[$columns->{visitor_passing_yards}] - $row->[$columns->{visitor_penalty_yards}];
        my $o_factor = (($rushing_ypc * e**e) + ($passing_ypa * e**2)) * atan2($total_yards, 1);
        say "\tO-Factor for visitor: " . $o_factor;

        my $h_rushing_ypc = $row->[$columns->{home_rushing_yards}] / $row->[$columns->{home_rushing_attempts}];
        my $h_passing_ypa = $row->[$columns->{home_passing_yards}] / $row->[$columns->{home_passing_attempts}];
        my $h_total_yards = $row->[$columns->{home_rushing_yards}] + $row->[$columns->{home_passing_yards}] - $row->[$columns->{home_penalty_yards}];
        my $h_o_factor = (($h_rushing_ypc * e**e) + ($h_passing_ypa * e**2)) * atan2($h_total_yards, 1);
        say "\tO-Factor for home: " . $h_o_factor;
}

close $fh;
