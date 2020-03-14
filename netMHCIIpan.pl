# Author: Jiwoong Kim (jiwoongbio@gmail.com)
use strict;
use warnings;
local $SIG{__WARN__} = sub { die $_[0] };

use IPC::Open2;
use Getopt::Long qw(:config no_ignore_case);

chomp(my $hostname = `hostname`);
my $temporaryDirectory = $ENV{'TMPDIR'};
$temporaryDirectory = '/tmp' unless($temporaryDirectory);
GetOptions(
	'h' => \(my $help = ''),
	't=s' => \$temporaryDirectory,
	'p=i' => \(my $threads = 1),
	'f=s' => \(my $alleleFile = ''),
);
if($help || scalar(@ARGV) == 0) {
	die <<EOF;

Usage:   perl netMHCIIpan.pl [options] protein.fasta [allele ...] > netMHCIIpan.txt

Options: -h       display this help message
         -t DIR   directory for temporary files [\$TMPDIR or /tmp]
         -p INT   number of threads [$threads]
         -f FILE  allele file

EOF
}
{
	my $parentPid = $$;
	my %pidHash = ();
	my $writer;
	my $parentWriter;
	sub forkPrintParentWriter {
		($parentWriter) = @_;
	}
	sub forkPrintSubroutine {
		my ($subroutine, @arguments) = @_;
		if(my $pid = fork()) {
			$pidHash{$pid} = 1;
		} else {
			open($writer, "> $temporaryDirectory/fork.$hostname.$parentPid.$$");
			$subroutine->(@arguments);
			close($writer);
			exit(0);
		}
		forkPrintWait($threads);
	}
	sub forkPrintWait {
		my ($number) = (@_, 1);
		while(scalar(keys %pidHash) >= $number) {
			my $pid = wait();
			if($pidHash{$pid}) {
				open(my $reader, "$temporaryDirectory/fork.$hostname.$parentPid.$pid");
				if(defined($parentWriter)) {
					print $parentWriter $_ while(<$reader>);
				} else {
					print $_ while(<$reader>);
				}
				close($reader);
				system("rm $temporaryDirectory/fork.$hostname.$parentPid.$pid");
				delete $pidHash{$pid};
			}
		}
	}
	sub forkPrint {
		if(defined($writer)) {
			print $writer @_;
		} elsif(defined($parentWriter)) {
			print $parentWriter @_;
		} else {
			print @_;
		}
	}
}
my ($fastaFile, @alleleList) = @ARGV;
my @nameSequenceList = ();
{
	open(my $reader, ($fastaFile =~ /\.gz$/ ? "gzip -dc $fastaFile |" : $fastaFile));
	while(my $line = <$reader>) {
		chomp($line);
		if($line =~ /^>(\S*)/) {
			push(@nameSequenceList, [$1, '']);
		} else {
			$nameSequenceList[-1]->[1] .= $line;
		}
	}
	close($reader);
}
if($alleleFile ne '') {
	open(my $reader, ($alleleFile =~ /\.gz$/ ? "gzip -dc $alleleFile |" : $alleleFile));
	while(my $line = <$reader>) {
		chomp($line);
		push(@alleleList, $line);
	}
	close($reader);
}
foreach my $allele (@alleleList) {
	if($threads == 1) {
		perAllele($allele);
	} else {
		forkPrintSubroutine(\&perAllele, $allele);
	}
}
forkPrintWait();

sub perAllele {
	my ($allele) = @_;
	foreach(@nameSequenceList) {
		my ($name, $sequence) = @$_;
		open(my $writer, "> $temporaryDirectory/netMHCIIpan.fasta.$hostname.$$");
		print $writer ">$name\n";
		print $writer "$sequence\n";
		close($writer);
		open(my $reader, "netMHCIIpan -a '$allele' -f $temporaryDirectory/netMHCIIpan.fasta.$hostname.$$ |");
		while(my $line = <$reader>) {
			chomp($line);
			next if($line =~ /^#/);
			if($line =~ /^\s*(.*)<=\s*(\S+)$/) {
				my @tokenList = split(/\s+/, $1);
				my ($position, $peptide, $bind) = ($tokenList[0], $tokenList[2], $2);
				next if($peptide =~ /\*/);
				forkPrint(join("\t", $name, $position, $peptide, $allele, $bind), "\n");
			}
		}
		close($reader);
		system("rm $temporaryDirectory/netMHCIIpan.fasta.$hostname.$$");
	}
}
