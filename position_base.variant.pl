# Author: Jiwoong Kim (jiwoongbio@gmail.com)
use strict;
use warnings;
local $SIG{__WARN__} = sub { die $_[0] };

use Getopt::Long qw(:config no_ignore_case);

GetOptions(
	'h' => \(my $help = ''),
	'f=i' => \(my $flankingLength = 0),
);
if($help || scalar(@ARGV) == 0) {
	die <<EOF;

Usage:   perl position_base.variant.pl [options] position_base.txt > variant.txt

Options: -h       display this help message
         -f INT   flanking length

EOF
}
my ($positionBaseFile) = @ARGV;
my @tokenListList = ();
open(my $reader, $positionBaseFile);
while(my $line = <$reader>) {
	chomp($line);
	my @tokenList = split(/\t/, $line, -1);
	push(@tokenListList, \@tokenList);
}
close($reader);

if(my @indexList = grep {$tokenListList[$_]->[2] ne $tokenListList[$_]->[5]} 0 .. $#tokenListList) {
	my @indexIndexList = (0, (grep {$tokenListList[$indexList[$_ - 1]]->[0] ne $tokenListList[$indexList[$_]]->[0] || $tokenListList[$indexList[$_ - 1]]->[1] + 1 + $flankingLength < $tokenListList[$indexList[$_]]->[1]} 1 .. $#indexList), scalar(@indexList));
	foreach my $index (0 .. $#indexIndexList - 1) {
		my ($startIndex, $endIndex) = ($indexList[$indexIndexList[$index]] - $flankingLength, $indexList[$indexIndexList[$index + 1] - 1] + $flankingLength);
		$startIndex = 0 if($startIndex < 0);
		$endIndex = $#tokenListList if($endIndex > $#tokenListList);
		my @variantTokenListList = @tokenListList[$startIndex .. $endIndex];
		(my $referenceSequence = join('', map {$_->[2]} @variantTokenListList)) =~ s/-//g;
		(my $alternateSequence = join('', map {$_->[5]} @variantTokenListList)) =~ s/-//g;
		print join("\t", @{$variantTokenListList[0]}[0, 1], $referenceSequence, $alternateSequence), "\n";
	}
}
