#!/usr/bin/env perl

use strict;
use warnings;
use 5.012;
use POSIX;

use Cwd;
use Text::CSV;
use Data::Dumper;

use constant e => 2.718281828459;

sub trim;
sub add_game;
sub process_file;
sub generate_rankings;
sub calculate_sos;
sub display_rankings;
sub process_matchups;
sub output_rankings;
sub _win_loss_record;
sub _win_percentage;

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

my $output_csv;
{
	no warnings;
	$output_csv = !!(shift eq "csv");
}

my $teams = {};
my $dir = "data2019";
my $cwd = cwd();

opendir(DIR, $dir) or die $!;
chdir $dir;

while (my $file = readdir(DIR)) {
	next unless !($file eq "." || $file eq "..");
	#say "Processing " . $file . "...";
	process_file $file;
	#say "Done.\n";
}

chdir $cwd;

my $sos = calculate_sos $teams;

my $rankings = generate_rankings $teams, $sos;

#say Dumper $teams;

display_rankings $teams, $rankings unless $output_csv;
output_rankings $teams, $rankings if $output_csv;

chdir $cwd;

sub trim {
	my $string = $_[0];
	$string =~ s/^\s+|\s+$//g;
	return $string;
}

#$teams is the data structure for all of the games
#$game is the structure for an individual team's game

sub add_game {
	my $teams = shift;
	foreach my $game (@_) {
		$teams->{$game->{team}} = [] unless ($teams->{$game->{team}});
		push @{$teams->{$game->{team}}}, {
			opponent => $game->{opponent},
			win => $game->{win},
			score => $game->{score},
			diff => $game->{diff},
			x_factor => $game->{x_factor},
		};
	}
	return $teams;

}

sub process_file {
	my $input = shift;
	open my $fh, "<", $input or die "$input: $!";
	my $csv = Text::CSV->new({
		binary    => 1,
		auto_diag => 1,
	});

	#column names
	$csv->getline($fh);

	while (my $row = $csv->getline($fh)) {
		#say trim $row->[$columns->{visitor}] . " at " . trim $row->[$columns->{home}];

	        my $v_rushing_ypc = $row->[$columns->{visitor_rushing_yards}] / $row->[$columns->{visitor_rushing_attempts}];
	        my $v_passing_ypa = $row->[$columns->{visitor_passing_yards}] / $row->[$columns->{visitor_passing_attempts}];
	        #To avoid division by zero
	        $v_rushing_ypc += .0000001;
	        $v_passing_ypa += .0000001;
	        my $v_total_yards = $row->[$columns->{visitor_rushing_yards}] + $row->[$columns->{visitor_passing_yards}];
	        my $v_o_factor = (($v_rushing_ypc * e**e) + ($v_passing_ypa * e**2)) * atan2($v_total_yards, 1);
	        #say "\tO-Factor for visitor: " . $v_o_factor;

	        my $h_rushing_ypc = $row->[$columns->{home_rushing_yards}] / ($row->[$columns->{home_rushing_attempts}] + .0000001);
	        my $h_passing_ypa = $row->[$columns->{home_passing_yards}] / ($row->[$columns->{home_passing_attempts}] + .0000001);
	        #To avoid division by zero
	        $h_rushing_ypc += .0000001;
	        $h_passing_ypa += .0000001;
	        my $h_total_yards = $row->[$columns->{home_rushing_yards}] + $row->[$columns->{home_passing_yards}];
	        my $h_o_factor = (($h_rushing_ypc * e**e) + ($h_passing_ypa * e**2)) * atan2($h_total_yards, 1);
	        #say "\tO-Factor for home: " . $h_o_factor;

	        my $v_third_down_rate = $row->[$columns->{visitor_third_down_conversions}] / ($row->[$columns->{visitor_third_down_attempts}] + .0000001);
	        my $h_third_down_rate = $row->[$columns->{home_third_down_conversions}] / ($row->[$columns->{home_third_down_attempts}] + .0000001);
		$v_third_down_rate += .0000001;
		$h_third_down_rate += .0000001;

	        my $v_3_factor = (e**atan2(1 - $h_third_down_rate, 1)) - (1/e);
	        my $h_3_factor = (e**atan2(1 - $v_third_down_rate, 1)) - (1/e);

	        my $v_d_factor = ((e + 1) * ((1 / $h_rushing_ypc) + 1) + (e ** 2) * ((1 / $h_passing_ypa) + (e / 3))) * $v_3_factor * e**e;
	        my $h_d_factor = ((e + 1) * ((1 / $v_rushing_ypc) + 1) + (e ** 2) * ((1 / $v_passing_ypa) + (e / 3))) * $h_3_factor * e**e;

	        #say "\tD-Factor for visitor: " . $v_d_factor;
	        #say "\tD-Factor for home: " . $h_d_factor;

	        #Calculate the x factor (reward teams for being balanced between o and d)

	        my $h_x_factor = ((1 / e) * e**(-((1 / 100) * (abs($h_o_factor - $h_d_factor)))**2) + 1) / 2;
	        my $v_x_factor = ((1 / e) * e**(-((1 / 100) * (abs($v_o_factor - $v_d_factor)))**2) + 1) / 2;

	        #say "\tX-Factor for visitor: " . $v_x_factor;
	        #say "\tX-Factor for home: " . $h_x_factor;

	        #Calculate the win factor

	        my $h_margin = $row->[$columns->{home_score}] - $row->[$columns->{visitor_score}];
	        my $v_margin = -1 * $h_margin;

	        my $h_win_factor = ((e ** atan2($h_margin / e**e, 1)) + 1);
	        my $v_win_factor = ((e ** atan2($v_margin / e**e, 1)) + 1);

	        #say "\tWin Factor for visitor: " . $v_win_factor;
	        #say "\tWin Factor for home: " . $h_win_factor;

	        my $h_game_score = ($h_o_factor + $h_d_factor) * $h_x_factor * $h_win_factor;
	        my $v_game_score = ($v_o_factor + $v_d_factor) * $v_x_factor * $v_win_factor;
		$h_game_score = abs($h_game_score);
		$v_game_score = abs($v_game_score);


	        #say "\tGame Score for visitor: " . $v_game_score;
	        #say "\tGame Score for home: " . $h_game_score;

		my $v_game = {
			team => trim ($row->[$columns->{visitor}]),
			opponent => trim ($row->[$columns->{home}]),
			win => $v_margin > 0,
			score => $v_game_score,
			diff => $v_game_score / $h_game_score,
			x_factor => $v_x_factor,
		};

		my $h_game = {
			team => trim ($row->[$columns->{home}]),
			opponent => trim ($row->[$columns->{visitor}]),
			win => $v_margin < 0,
			score => $h_game_score,
			diff => $h_game_score / $v_game_score,
			x_factor => $h_x_factor,
		};

		# say Dumper $v_game;
		# say Dumper $h_game;

		$teams = add_game $teams, $v_game, $h_game;
	}

	close $fh;

}

sub calculate_sos {
	my $teams = shift;
	my $teams_sos = {};

	foreach my $team (keys %{$teams}) {
		#say $team;

		my @games = @{$teams->{$team}};
		my @opponents;
		my $opponent_wins = 0;
		my $opponent_losses = 0;

		my $opp_opp_wins = 0;
		my $opp_opp_losses = 0;

		#say Dumper @games;

		foreach my $game (@games) {
			#say Dumper $team;
			#say Dumper $game;
			push @opponents, $game->{opponent};
		}

		foreach my $opp (@opponents) {
			#say "\t" . $opp;

			my @opp_games = @{$teams->{$opp}};
			my $wins = 0;
			my $losses = 0;
			for my $opp_game (@opp_games) {
				#say "Opp: " . Dumper $opp;
				#say "Team: " . Dumper $team;
				#say Dumper $opp_game;
				if ($opp_game->{opponent} eq $team) { next; }

				if ($opp_game->{win}) {
					$wins += 1;
				} else {
					$losses += 1;
				}
			}

			#say "\t\t" . $wins . "-" . $losses;

			$opponent_wins += $wins;
			$opponent_losses += $losses;
		}

		#figure up the opp opp w%
		foreach my $opp (@opponents) {
			my @opp_games = @{$teams->{$opp}};
			my @opp_opponents;

			foreach my $game (@opp_games) {
				push @opp_opponents, $game->{opponent};
			}

			foreach my $opp_opp (@opp_opponents) {
				my @opp_opp_games = @{$teams->{$opp}};
				foreach my $opp_opp_game (@opp_opp_games) {
					if ($opp_opp_game->{win}) {
						$opp_opp_wins++;
					} else {
						$opp_opp_losses++;
					}
				}
			}

		}


		#say "Opp W-L: " . $opponent_wins . "-" . $opponent_losses;
		#say "Opp W%: " . $opponent_wins / ($opponent_losses + $opponent_wins) . "\n";

		my $wpercent = $opponent_wins / ($opponent_losses + $opponent_wins + .0000001);

		my $opp_opp_wpercent = $opp_opp_wins / ($opp_opp_wins + $opp_opp_losses);

		my $adjusted_percent = ($wpercent + $opp_opp_wpercent) / 3;

		my $sos = atan2(5 * ($adjusted_percent - .2), 1) + 1/2;
		$sos = 2 if $sos > 2;
		$sos = .25 if $sos < .25;

	#say $team . "," . $sos;

		$teams_sos->{$team} = $sos;
	}

	return $teams_sos;
}

sub generate_rankings {
	my $teams = shift;
	my $teams_sos = shift;

	my $ballot = {};

	foreach my $team (keys %{$teams}) {
		my $total_score = 0;
		my $game_count = 0;
		my $total_diff = 0;

		my @games = @{$teams->{$team}};
		foreach my $game (@games) {
			if ($game->{score} > 100000) {
				next;
			}
			$game_count++;
			$total_score += $game->{score};
			$total_diff += $game->{diff};
		}

		my $avg_score = $total_score / ($game_count + .0000001);
		my $avg_diff = $total_diff / ($game_count + .0000001);

		my $votes_quarter = $avg_score * $teams_sos->{$team};
		my $votes = (2 * $votes_quarter + 2 * ($votes_quarter * _win_percentage $teams->{$team})) / 4;

		# $ballot->{$team} = ceil($votes);
		$ballot->{$team} = ceil(100 * $avg_diff);
	}

	return $ballot;
}

sub _win_percentage {
	my $team = shift;

	my @games = @{$team};
	my $wins = 0;
	my $losses = 0;

	foreach my $game (@games) {
		if ($game->{win}) {
			$wins += 1;
		} else {
			$losses += 1;
		}
	}
	$losses = $losses * e ** ($losses);

	return $wins / ($wins + $losses);
}

sub _win_loss_record {
	my $team = shift;

	my @games = @{$team};
	my $wins = 0;
	my $losses = 0;

	foreach my $game (@games) {
		if ($game->{win}) {
			$wins += 1;
		} else {
			$losses += 1;
		}
	}

	return $wins . "-" . $losses;
}

sub _games {
	my $team = shift;

	my @games = @{$team};
	my $wins = 0;
	my $losses = 0;

	foreach my $game (@games) {
		if ($game->{win}) {
			$wins += 1;
		} else {
			$losses += 1;
		}
	}

	return $wins + $losses;
}

sub output_rankings {
	my $teams = shift;
	my $hashref = shift;
	my %rankings = %{$hashref};

	my $i = 0;
	my $hi = 0;

	say "Team,Rank,Record,Score";

	foreach my $team (sort { abs($rankings{$b}) <=> abs($rankings{$a}) } keys %rankings) {
		if (_games($teams->{$team}) > $hi) {
			$hi = _games($teams->{$team});
		}
		my $diff = abs(_games($teams->{$team}) - $hi);
		if (!($diff == _games($teams->{$team}) || $diff < 5)) {
			next;
		}

		$i++;

		my $wlstring = _win_loss_record $teams->{$team};

		printf "%s,%d,%s,%s\n", $team, $i, $wlstring, abs($rankings{$team});
	}
}

sub display_rankings {
	say "\nRankings\n";

	my $teams = shift;
	my $hashref = shift;
	my %rankings = %{$hashref};

	my $i = 0;
	my $hi = 0;

	#say Dumper $teams;

	foreach my $team (sort { abs($rankings{$b}) <=> abs($rankings{$a}) } keys %rankings) {
#		next unless _games($teams->{$team})
		if (_games($teams->{$team}) > $hi) {
			$hi = _games($teams->{$team});
		}
		my $diff = abs(_games($teams->{$team}) - $hi);
		if (!($diff == _games($teams->{$team}) || $diff < 5)) {
			next;
		}

		#next unless $rankings{$team} < 100000;

		$i++;

		my $wlstring = _win_loss_record $teams->{$team};

		printf "    %3d. %-30s %6s %5s\n", $i, $team, $wlstring, abs($rankings{$team});
	}
}

sub process_matchups {
	my $input = shift;
	my $rankings = shift;



	open my $fh, "<", $input or die "$input: $!";
	my $csv = Text::CSV->new({
		binary    => 1,
		auto_diag => 1,
	});

	while (my $row = $csv->getline($fh)) {
		my $A = trim $row->[0];
		my $B = trim $row->[1];
		say $A . " vs " . $B;
	}

}
