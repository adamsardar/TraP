#!/usr/bin/env perl

use strict;
use warnings;

=head1 NAME

epoch_percentage_composition.pl - A script for addressing the question of when a group of samples could
have existed.

=head1 SYNOPSIS

epoch_percentage_composition.pl [options] -tr|--taxontranslate <TaxonRangesToMapBetween> -s --samples <SampleIDsFile>

 Basic Options:
  -h --help Get full man page output
  -v --verbose Verbose output with details of mutations
  -d --debug Debug output

=head1 DESCRIPTION

This program is part of the TraP Project

epoch_percentage_composition.pl - A script for addressing the question of when a group of samples could
have existed.

Input is a newline seperated file of sample ids. Output is a file, in the same order as input, with columns
of key taxonomic divisions and the percentage of the distinct expressed architectures that existed at that
point. It also has the cumulative percentage.

Input:

"Comment"\t"comma seperated sample ids"
e.g
ImmuneSystemCells	1,45,32,12,67...

Output:

"epoch label"\t"epoch label"...
"CommentFromInput"\t"Percentage created at epoch:Cumulative percentage"\t"Percentage created at epoch:Cumlative Percentage"\t""\t
e.g

	CellularOrganisms	Eukaroytes
ImmuneSystemCells	12%:12%		34%:46%		...

=head1 EXAMPLES

To get some help output do:

skeleton --help

To list the files in the current directory do:

skeleton *

B<Adam Sardar> - I<Adam.Sardar@bristol.ac.uk>

=head1 NOTICE

=item B<Adam Sardar> (2013) First features added.

=back

=head1 LICENSE AND COPYRIGHT

B<Copyright 2013 Matt Oates, Owen Rackham, Adam Sardar>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

#By default use the TraP libraries, assuming executing from the bin dir
use lib qw'../lib';

=head1 DEPENDANCY

TraP dependancies:

=over 4

=item B<TraP::Skeleton> Used to do nothing.

=back

CPAN dependancies:

=over 4

=item B<Getopt::Long> Used to parse command line options.

=item B<Pod::Usage> Used for usage and help output.

=item B<Data::Dumper> Used for debug output.

=back

=cut

use Getopt::Long; #Deal with command line options
use Pod::Usage;   #Print a usage man page from the POD comments
use Data::Dumper; #Allow easy print dumps of datastructures for debugging

use Utils::SQL::Connect qw/:all/;
use Supfam::Utils qw/:all/;
use Carp;
use Carp::Assert::More;

# Command Line Options
#-------------------------------------------------------------------------------
my $verbose; #Flag for verbose output from command line opts
my $debug;   #As above for debug
my $help;    #Same again but this time should we output the POD man page defined after __END__

my $samplesfile;
my $translation_file;

#Set command line flags and parameters.
GetOptions("verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
           "help|h!" => \$help,
           "taxontranslate|tr:s" => \$translation_file,
           "samples|s=s" => \$samplesfile,
        ) or die "Fatal Error: Problem parsing command-line ".$!;

#Get other command line arguments that weren't optional flags.
my @files= @ARGV;

#Print out some help if it was asked for or if no arguments were given.
pod2usage(-exitstatus => 0, -verbose => 2) if $help;

###Main script

my ( $dbh, $sth );
$dbh = dbConnect();


#Make a translation file to map between taxonomic ranges
my $Taxon_mapping ={};
my $InverseTaxonMapping = {};

if($translation_file){
	
	print STDERR "Creating a mapping between taxon_ids ....\n";
	open FH, "$translation_file" or die $!."\t".$?;
 	
 	while(my $line = <FH>){
 		
 		chomp($line);
 		my ($from,$to,$taxon_name)=split(/\s+/,$line);
 		croak "Incorrect translation file. Expecting a tab seperated file of 'from' 'to'\n" if($Taxon_mapping ~~ undef || $to ~~ undef);
 		$Taxon_mapping->{$from}=$to;
 		$InverseTaxonMapping->{$to}=$from;
 	}
 	
 	close FH;
}

#Open sampleids file, work through line by line and estimate age

my @SortedEpochs;

$sth = $dbh->prepare("SELECT DISTINCT(taxon_id) FROM taxon_details ORDER BY distance ASC;");

$sth->execute();

while (my ($taxon_id) = $sth->fetchrow_array()){
	
	if($translation_file){
		next unless(exists($InverseTaxonMapping->{$taxon_id}));
	}
	
	push(@SortedEpochs,$taxon_id);
}

#Need to construct these - pull them from the database.

open SAMPLEIDS, "<$samplesfile" or die $?."\t".$!;

mkdir("../data");
open TIMEPERCENTAGES, ">../data/EpochSampleGroupPercentages.dat" or die $!."\t".$?;
print TIMEPERCENTAGES join("\t",@SortedEpochs);
print TIMEPERCENTAGES "\n";

$sth = $dbh->prepare("SELECT DISTINCT(comb_MRCA.comb_id),comb_MRCA.taxon_id 
						FROM comb_MRCA 
						JOIN snapshot_order_comb ON comb_MRCA.comb_id = snapshot_order_comb.comb_id
						WHERE sample_id IN (?)");

while(my $line = <SAMPLEIDS>){
	
	chomp($line);
	my ($comment,$samids) = split("\t",$line);
	my @sampleids = split(',',$samids);
	
	my $TaxID2DomArchCountHash ={};
	
	my $DistinctDAcount=0;
	$sth->execute($samids);
	
	while (my ($comb_id,$taxon_id) = $sth->fetchrow_array()){
		
		my $MappedTaxonID = $taxon_id;
		$MappedTaxonID = $Taxon_mapping->{$taxon_id} if (exists($Taxon_mapping->{$taxon_id}));
		
		$TaxID2DomArchCountHash->{$MappedTaxonID}++;
		$DistinctDAcount++;
	}
	
	my $CumlativeEpochCount = 0;
	
	foreach my $Epoch (@SortedEpochs){
		
		my $EpochCount=0;
		print TIMEPERCENTAGES $comment."\t";
		
		unless(exists($TaxID2DomArchCountHash->{$Epoch})){
			
			$EpochCount=$TaxID2DomArchCountHash->{$Epoch};
		}
		
		$CumlativeEpochCount+=$EpochCount;
		
		my $EpochPercent = 100*$EpochCount/$DistinctDAcount;
		my $CumulativeEcpochPercent= 100*$CumlativeEpochCount/$DistinctDAcount;
			
		print TIMEPERCENTAGES $EpochPercent.":".$CumulativeEcpochPercent."\t";
	}
	print TIMEPERCENTAGES "\n";
}

close SAMPLEIDS;
close TIMEPERCENTAGES;


__END__

