#!/usr/bin/perl

package Correlation;

use strict;
use warnings;
use List::Util qw(shuffle min);


#print user define display
print "*******************************************************************************\n";
print "**                       Welcome to correlation scan (v0.01).                **\n";
print "**---------------------------------------------------------------------------**\n";
print "**       This script is developed by Tunde Olasege for research use only     **\n"; 
print "**---------------------------------------------------------------------------**\n";
print "**                If any question, please contact b.olasege\@uq.net.au        **\n";
print "*******************************************************************************\n\n";

our $SQRT2PI = 2.506628274631;

sub new {
    my ($class, $args) = @_;

    my $self = {
        file    => $args->{file},
        chrset  => $args->{chrset},
        chr     => $args->{chr},
        slide   => $args->{slide},
        size    => $args->{size},
        shuffle => $args->{shuffle},
		out => $args->{out},

        _rows        => undef,
        _data        => undef,
        _mean        => undef,
        _windows     => undef,
        _correlation => undef,
        _shuffle_correlation => undef,
        _windows_per_chr     => undef,
        _windows_pos         => undef,
    };

    bless $self, $class;

    $self->_populate_data;

    die "ERROR: Mismatch chromosome counts in the file.\n"
        unless ($self->{chrset} == keys %{$self->{_data}});

    $self->_create_windows;

    return $self;
}

sub _populate_data {
    my ($self) = @_;

    print STDOUT "Loading data ... ";

    my $file = $self->{file};
    my $data = {};

    open(my $IN, '<', $file) or die "ERROR: Unable to open $file: $!\n";

    # skip header
    my $header = <$IN>;

    while (my $row = <$IN>) {
        chomp $row;
        my ($chr, $position, $x, $y) = split /\s+/, $row, 4;
        $data->{$chr}->{$position} = [$x, $y];
    }

    close($IN);

    $self->{_data} = $data;

    print STDOUT "done.\n";
}

sub _create_windows {
    my ($self) = @_;

    print STDOUT "Creating windows ... ";

    my $windows = {};
    my $index   = 1;
    my $rows    = 0;
    my $size    = $self->{size};
    my $slide   = $self->{slide};

    foreach my $chr (@{$self->{chr}}) {
        my $data   = [];
        foreach my $pos (sort { $a <=> $b } keys %{$self->{_data}->{$chr}}) {
            push @$data, [ $chr, $pos, @{$self->{_data}->{$chr}->{$pos}} ];
        }

        my $i = 0;
        my $j = $size;
        my $windows_per_chr = 0;
        while ($j - 1 <= $#$data) {
            my $window = [];
            foreach my $k ($i .. $j - 1) {
                $rows++;
                push @$window, $data->[$k];
            }

            $windows->{$index+0} = $window;
            $self->{_windows_pos}->{$index+0} = {
                chr   => $window->[0]->[0],
                start => $window->[0]->[1],
                end   => $window->[-1]->[1],
            };

            $index++;
            $windows_per_chr++;
            $i += $slide;
            $j += $slide;
        }

        $self->{_windows_per_chr}->{$chr} = $windows_per_chr;
    }

    $self->{_windows} = $windows;
    $self->{_rows}    = $rows;

    print STDOUT "done.\n";
}

sub _mean {
    my ($self) = @_;

    #print STDOUT "Calculating mean ... ";

    my $mean_x = {};
    my $mean_y = {};

    foreach my $window (sort { $a <=> $b } keys %{$self->{_windows}}) {
        my $sum_x = 0;
        my $sum_y = 0;
        foreach my $entry (@{$self->{_windows}->{$window}}) {
            $sum_x += $entry->[2];
            $sum_y += $entry->[3];
        }

        $mean_x->{$window} = $sum_x / $self->{size};
        $mean_y->{$window} = $sum_y / $self->{size};
    }

    $self->{_mean} = [$mean_x, $mean_y];

   # print STDOUT "done.\n";
}

sub evaluate {
    my ($self) = @_;

    # evaluate mean first.
    $self->_mean;

    my $correlation = {};
    my $entries     = {};
    my $shuffle     = $self->{shuffle};
    my $w_total     = keys %{$self->{_windows}};
    my $w_index     = 1;

    foreach my $window (sort { $a <=> $b } keys %{$self->{_windows}}) {
        print sprintf("\rProcessing window %d of %d (%.1f",
              $w_index, $w_total, ($w_index/$w_total)*100) . '%).';

        my $_entries  = [];
        my $x_entries = [];
        my $y_entries = [];

        foreach my $entry (@{$self->{_windows}->{$window}}) {
            if (defined $shuffle && ($shuffle >= 1)) {
                push @$x_entries, $entry->[2];
                push @$y_entries, $entry->[3];
            }
            push @$_entries, [ $entry->[2], $entry->[3] ];
        }

        my $_correlation = $self->_eval_correlation($window, $_entries);
        $correlation->{$window+0} = $_correlation;

        my $shuffle_correlation = [];
        foreach my $i (1 .. $shuffle) {
            my $shuffle_x = [ shuffle @$x_entries ];
            my $shuffle_y = [ shuffle @$y_entries ];

            my $shuffle_entry = [];
            foreach my $j (0 .. $#$shuffle_x) {
                push @$shuffle_entry, [ $shuffle_x->[$j], $shuffle_y->[$j] ];
            }

            push @{$shuffle_correlation},
            $self->_eval_correlation($window, $shuffle_entry);
        }

        $self->{_shuffle_correlation}->{$window} = $shuffle_correlation;

        $w_index++;
    }

    $self->{_correlation} = $correlation;
}

sub _eval_correlation {
    my ($self, $window, $entries) = @_;

    my $mean_x = $self->{_mean}->[0];
    my $mean_y = $self->{_mean}->[1];

    my $sum_x  = 0;
    my $sum_y  = 0;
    my $sum_xy = 0;
    foreach my $entry (@$entries) {
        my $x = $entry->[0] - $mean_x->{$window};
        my $y = $entry->[1] - $mean_y->{$window};

        $sum_x  += $x ** 2;
        $sum_y  += $y ** 2;
        $sum_xy += $x * $y;
    }

    return sprintf("%.3f", $sum_xy / sqrt($sum_x * $sum_y));
}

# create res file with pvalue and adjusted pvalue.
sub create_res_file {
    my ($self, $file) = @_;

    open(my $OUT, '>', $file) or die "ERROR: Unable to open $file: $!\n";

    my $header  = "Window\tChr\tStart\tEnd\tr";
    my $shuffle = $self->{shuffle};
    my $size    = $self->{size};

    if ($shuffle) {
        $header .= "\tpvalue\tperm_avg";
    }

    print $OUT $header, "\n";

    my $correlation = $self->{_correlation};
    my $windows_pos = $self->{_windows_pos};
    my $contents    = [];
    my $pvalues     = [];
    my $pavg        = [];
    foreach my $window (sort { $a <=> $b } keys %{$correlation}) {
        my $start = $windows_pos->{$window}->{start};
        my $end   = $windows_pos->{$window}->{end};
        my $chr   = $windows_pos->{$window}->{chr};
        my $correlation = $correlation->{$window};

        my @row  = ("w$window\t$chr\t$start\t$end\t$correlation");
        if ($shuffle) {
            my @perm_cor = @{$self->{_shuffle_correlation}->{$window}};
            my $sum_cor  = 0;
            $sum_cor    += $_ for @perm_cor;
            my $avg_cor  = sprintf("%.3f", $sum_cor / @perm_cor);
            push @$pavg, [ $avg_cor ];
            push @$pvalues, _pvalue($size, $correlation, $avg_cor);
        }

        push @$contents, \@row;
    }

    my $adjusted_pvalues = _adjusted_pvalues($pvalues);
    for (my $i = 0; $i < @$contents; $i++) {
        my $_adj_pvalue = $adjusted_pvalues->[$i];
        my $_pavg       = $pavg->[$i];
        print $OUT join("\t", (@{$contents->[$i]}, $_adj_pvalue, @$_pavg)), "\n";
    }

    close($OUT);
}

sub create_chc_file {
    my ($self, $file) = @_;

    open(my $OUT, '>', $file) or die "ERROR: Unable to open $file: $!\n";
    print $OUT "Chr\tNo_of_SNP\tNo_of_window\n";

    my $windows_per_chr = $self->{_windows_per_chr};
    foreach my $chr (sort { $a <=> $b } keys %{$self->{_data}}) {
        my $chr_sample_count = keys %{$self->{_data}->{$chr}};
        my $count = $windows_per_chr->{$chr};
        print $OUT "$chr\t$chr_sample_count\t$count\n";
    }

    close($OUT);
}

sub show {
    my ($self) = @_;

    my $correlation = $self->{_correlation};
    foreach my $window (sort { $a <=> $b } keys %{$correlation}) {
        print sprintf("Window #%d: %s\n", $window, $correlation->{$window});
    }
}

sub _pvalue {
    my ($size, $r, $pavg) = @_;

    die "ERROR: _pvalue() size has to be 4 or more.\n"
        if ($size < 4);

    my $zi    = 0.5 * log((1 + $r) / (1 - $r));
    my $zr    = 0.5 * log((1 + $pavg) / (1 - $pavg));
    my $num   = $zi - $zr;
    my $denum = sqrt(1 / ($size + 3) + 1 / ($size - 3));
    my $zd    = $num / $denum;

    return 2 * _cdf($zd);
}

sub _adjusted_pvalues {
    my ($pvalues) = @_;

    return _bonferroni_adjusted_pvalues($pvalues);
}

sub _bonferroni_adjusted_pvalues {
    my ($pvalues) = @_;

    my $lp = @$pvalues;
    my $n  = $lp;
    my @qvalues;
    for (my $index = 0; $index < $n; $index++) {
        my $q = $pvalues->[$index] * $n;
        if ((0 <= $q) && ($q < 1)) {
            $qvalues[$index] = $q;
        } elsif ($q >= 1) {
            $qvalues[$index] = 1.0;
        }
    }

    return \@qvalues
}

sub _cdf {
    my ($x, $m, $s) = @_;

    $x //= 0;
    $m //= 0;
    $s //= 1;

    # Abramowitz & Stegun, 26.2.17
    # absolute error less than 7.5e-8 for all x

    die "ERROR: Can't evaluate cdf for \$s=$s not strictly positive"
        if ($s <= 0);

    my $z = ($x - $m) / $s;
    my $t = 1.0 / (1.0 + 0.2316419 * abs($z));
    my $y = $t * (0.319381530
                  + $t * (-0.356563782
                          + $t * (1.781477937
                                  + $t * (-1.821255978
                                          + $t * 1.330274429
                                         )
                                 )
                         )
                 );

    if ($z > 0) {
        return 1.0 - _pdf($z) * $y;
    } else {
        return _pdf($z) * $y;
    }
}

sub _pdf {
    my ($x, $m, $s) = @_;

    $x //= 0;
    $m //= 0;
    $s //= 1;

    die "ERROR: Can't evaluate cdf for \$s=$s not strictly positive"
        if ($s <= 0);

    my $z = ($x - $m) / $s;

    return exp(-0.5 * $z * $z) / ($SQRT2PI * $s);
}

package main;

use strict;
use warnings;
use Getopt::Long;

$|=1;

#
#
# Process command line arguments

my ($file, $chrset, $chr, $size, $slide, $shuffle, $out, $help);
GetOptions(
    "file=s"    => \$file,
    "chrset=i"  => \$chrset,
    "chr=s"     => \$chr,
    "size=i"    => \$size,
    "slide=i"   => \$slide,
    "shuffle=i" => \$shuffle,
	"out=s"		=> \$out,
    "help"      => \$help,
) or die_and_exit("ERROR: Invalid command line arguments.");

die_and_exit() if $help;
die_and_exit("ERROR: Missing input file.") unless defined $file;
die_and_exit("ERROR: Invalid input file.") unless (-e -f -r $file);

die_and_exit("ERROR: Missing total chromosome counts in the file.")
    unless defined $chrset;
die_and_exit("ERROR: Invalid chromosome count [$chrset].")
    unless ($chrset =~ /^\d+$/);

die_and_exit("ERROR: Missing chromosomes to analyse.")
    unless defined $chr;
die_and_exit("ERROR: Invalid chromosomes [$chr].")
    unless ($chr =~ /^[\d\,\-]+$/);
die_and_exit("ERROR: Missing output file.")
    unless defined $out;	

$size    //= 500;
$slide   //= 100;
$shuffle //= 1;

#
#
# Process data

my $correlation = Correlation->new({
    file    => $file,
    chrset  => $chrset,
    chr     => expand($chr),
    slide   => $slide,
    size    => $size,
    shuffle => $shuffle,
});

#
#
# Evaluate and show result

$correlation->evaluate;
#$correlation->show;
$correlation->create_res_file("$out.res");
$correlation->create_chc_file("$out.chc");

print "\n\nOutput files created as \"$out.res and $out.chc ... done ";

exit;

#
#
# METHODS

sub expand {
    my ($chr) = @_;

    my $digits = [];
    if ($chr =~ /\,/) {
        foreach my $i (split /\,/, $chr) {
            if ($i =~ /\-/) {
                my ($x, $y) = split /\-/,$i,2;
                push @$digits, $_ for ($x .. $y);
            }
            else {
                push @$digits, $i;
            }
        }
    }
    elsif ($chr =~ /\-/) {
        my ($x, $y) = split /\-/, $chr, 2;
        push @$digits, $_ for ($x .. $y);
    }
    else {
        push @$digits, $chr;
    }

    return $digits;
}

sub die_and_exit {
    my ($message) = @_;

    my $help = $message;
    $help .= "\nUsage:\n\ncorrelation <options>\n\n";
    $help .= "       --file=<input file>           Expects tab separated ascii file.\n";
    $help .= "       --size=<window size>          Default size is 5.\n";
    $help .= "       --slide=<sliding window size> Default size is 2.\n";
    $help .= "       --shuffle=<shuffle count>     Default count is 1.\n";
    $help .= "       --chrset=<total chromosome counts in the file>\n";
    $help .= "       --chr=<chromosomes to analyse>\n";
	$help .= "       --out=<name for the output files>\n";
    $help .= "       --help Print the help message.\n";

    die $help;
}

END {
    my $time = time - $^T;
    my $mm   = $time / 60;
    my $ss   = $time % 60;
    my $hh   = $mm / 60;
    $mm = $mm % 60;

    print sprintf("\n\nThe program ran for %02d:%02d:%02d.\n", $hh, $mm, $ss);
}
