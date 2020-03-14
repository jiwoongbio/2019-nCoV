# Author: Jiwoong Kim (jiwoongbio@gmail.com)
use strict;
use warnings;
local $SIG{__WARN__} = sub { die $_[0] };

use Getopt::Long qw(:config no_ignore_case);

GetOptions(
	'h' => \(my $help = ''),
);
if($help || scalar(@ARGV) == 0) {
	die <<EOF;

Usage:   perl region.liftover.pl [options] region.txt position_base.txt > region.liftover.txt

Options: -h       display this help message

EOF
}
my ($regionFile, $positionBaseFile) = @ARGV;
my %positionHash = ();
{
	open(my $reader, $positionBaseFile);
	while(my $line = <$reader>) {
		chomp($line);
		my ($name1, $position1, $base1, $name2, $position2, $base2) = split(/\t/, $line, -1);
		$positionHash{"$name1:$position1"} = [$name2, $position2] if($base1 ne '-' && $base2 ne '-');
	}
	close($reader);
}
open(my $reader, $regionFile);
while(my $line = <$reader>) {
	chomp($line);
	my @tokenList = split(/\t/, $line, -1);
	my ($name, $start, $end, $strand) = @tokenList;
	my ($startName, $endName);
	if(defined($_ = $positionHash{"$name:$start"})) {
		($startName, $start) = @$_;
	}
	if(defined($_ = $positionHash{"$name:$end"})) {
		($endName, $end) = @$_;
	}
	if(defined($startName) && defined($endName) && $startName eq $endName) {
		$name = $startName = $endName;
	} elsif($strand eq '+' && defined($startName)) {
		($name, $end) = ($startName, '');
	} elsif($strand eq '-' && defined($endName)) {
		($name, $start) = ($endName, '');
	} else {
		($name, $start, $end) = ('', '', '');
	}
	@tokenList[0, 1, 2] = ($name, $start, $end);
	print join("\t", @tokenList), "\n";
}
close($reader);
