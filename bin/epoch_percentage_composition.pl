#!/usr/bin/env perl

use Modern::Perl;

=head1 NAME

epoch_percentage_composition.pl - A script for addressing the question of when a group of samples could have existed.

=head1 SYNOPSIS

epoch_percentage_composition.pl [options] -tr|--taxontranslate <TaxonRangesToMapBetween> -u|--union flag_for_calculating_union -s --samples <SampleIDsFile>

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

./epoch_percentage_composition.pl -s TestEpoch -tr TaxaMappingsCollapsed.txt
#Studies domaina rchitectures that are common to all the samples in a group

./epoch_percentage_composition.pl -s SampleIDsFile -r -tr TaxaMappingsCollapsed.txt
# Removes domain architectures that are present in everything

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
use Carp::Assert;
use Carp::Assert::More;
use List::Compare;

# Command Line Options
#-------------------------------------------------------------------------------
my $verbose; #Flag for verbose output from command line opts
my $debug;   #As above for debug
my $help;    #Same again but this time should we output the POD man page defined after __END__

my $samplesfile;
my $translation_file;
my $union = 0;
my $removeubiq = 0;
my $UbiqFuzzyThreshold;
#The percentage number of samples to hold a comb before we call it is a ubiqutous
my $source = 1;
my $out = "../data/EpochSampleGroupPercentages.dat";

#Set command line flags and parameters.
GetOptions("verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
           "help|h!" => \$help,
           "taxontranslate|tr:s" => \$translation_file,
           "samples|s=s" => \$samplesfile,
           "union|u!" => \$union,
           "removeubiq|r!" => \$removeubiq,
           "ubiqthreshold|u:f" => \$UbiqFuzzyThreshold,
           "source|c:i" => \$source,
          "output|o:s" => \$out,
        ) or die "Fatal Error: Problem parsing command-line ".$!;

#Get other command line arguments that weren't optional flags.
my @files= @ARGV;


assert_in($source,[qw(1 2 3 NULL)],"Allowed options for -c|--source are 1,2,3 and NULL\n");

if($UbiqFuzzyThreshold){
	
	$removeubiq =1 if($UbiqFuzzyThreshold);
	assert_positive($UbiqFuzzyThreshold,"Threshold must be greater than 0 - a percentage\n");
	assert($UbiqFuzzyThreshold <= 100,"Threshold must be less than 100 - a percetage\n");
	
}elsif($removeubiq){
	$UbiqFuzzyThreshold = 100 if($removeubiq);
	
}



#Print out some help if it was asked for or if no arguments were given.
pod2usage(-exitstatus => 0, -verbose => 2) if $help;

###Main script

my ( $dbh, $sth , $ebh, $tth);
$dbh = dbConnect();
$ebh = dbConnect();

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

$sth = $dbh->prepare("SELECT DISTINCT(taxon_id) FROM taxon_details ORDER BY distance DESC;");

$sth->execute();

while (my ($taxon_id) = $sth->fetchrow_array()){
	
	if($translation_file){
		next unless(exists($InverseTaxonMapping->{$taxon_id}));
	}
	
	push(@SortedEpochs,$taxon_id);
}

#Need to construct these - pull them from the database.

assert_defined($samplesfile,"You must procide a file to calculate statistics upon! See doc\n");

open SAMPLEIDS, "<$samplesfile" or die $?."\t".$!;

mkdir("../data");

print STDOUT "Printing to outfile $out\n";

open TIMEPERCENTAGES, ">$out" or die $!."\t".$?;
print TIMEPERCENTAGES join("\t",@SortedEpochs);
print TIMEPERCENTAGES "\n";

$sth = $dbh->prepare("SELECT DISTINCT snapshot_order_comb.sample_id,snapshot_order_comb.comb_id 
						FROM snapshot_order_comb
						JOIN sample_index ON sample_index.sample_id = snapshot_order_comb.sample_id
						AND sample_index.source = ?;");
						
$tth = $ebh->prepare("SELECT comb_MRCA.taxon_id
						FROM comb_MRCA
						WHERE comb_id = ?");

my $SampleID2Combs = {};
#Grab a list of comb ids per sample and whack them into a hash

#So as to speed up execution, dump that hash to a file, unless we've already done so. In which case, use it!

unless(-e "/tmp/SampleID2Combs.dat" && ! $debug){

	print STDERR "Creating the hash SampleID2combs.dat and dumping it to file ...";
	$sth->execute($source);
			
	while (my ($sample_id,$comb_id) = $sth->fetchrow_array()){
				
				$SampleID2Combs->{$sample_id}=[] unless(exists($SampleID2Combs->{$sample_id}));
				push(@{$SampleID2Combs->{$sample_id}},$comb_id);
	}

	EasyDump("/tmp/SampleID2Combs.dat",$SampleID2Combs);
	print STDERR " done.\n";

}else{
	
	print STDERR "Using a dump of the hash SampleID2combs.dat from an earlier run ...";
	$SampleID2Combs = EasyUnDump("/tmp/SampleID2Combs.dat");
	print STDERR " loaded.\n";
}


#If requested (using -r or --removeubiq), make a lsit of DAs that exists in ALL samples
my @UbiqCombs;
if($removeubiq){
	
	unless(-e "/tmp/Ubiqcombs".$UbiqFuzzyThreshold."%.dat" && ! $debug){

		print STDERR "Creating the array UbiqCombs and dumping it to file ...";
		my $TotalSampleCompare = List::Compare->new( {
			        lists    => [(@{$SampleID2Combs}{keys(%$SampleID2Combs)})],
			        unsorted => 1,
			    });
		
		my $NumberSamples = scalar(keys(%$SampleID2Combs));
		my $SampleNumberThreshold = POSIX::floor($NumberSamples*$UbiqFuzzyThreshold/100);
		my @BagOfCombs = $TotalSampleCompare->get_bag;
		
		my $Combcount = {};
		print STDERR scalar(@BagOfCombs)." - Bag of combs size\n" if($debug);
		
		while (my $comb = shift(@BagOfCombs)){
			#Try to stay smart on memory
			
			$Combcount->{$comb}++;
		}
		
		$TotalSampleCompare->print_subset_chart if($verbose);
		$TotalSampleCompare->print_equivalence_chart if($verbose);
		
		foreach my $comb (keys(%$Combcount)){
			
			push(@UbiqCombs,$comb) if($Combcount->{$comb} >= $SampleNumberThreshold);
		}

		EasyDump("/tmp/Ubiqcombs".$UbiqFuzzyThreshold."%.dat",\@UbiqCombs);
		print STDERR " done.\n";
		print STDERR "(Threshold of $UbiqFuzzyThreshold % translates to a sample number threshold of $SampleNumberThreshold , where the total corpus is $NumberSamples samples)\n";
		
		
	}else{
		
		print STDERR "Using a dump of the uniqutous domains from an earlier run ...";
		my $tmp = EasyUnDump("/tmp/Ubiqcombs".$UbiqFuzzyThreshold."%.dat");
		@UbiqCombs = @$tmp;
		print STDERR " loaded.\n";
	}
	
	print STDERR "Number of ubiquitous domain archs:".scalar(@UbiqCombs)." - these shall be removed from the sample sets that you have inputted\n";
		
}

#For each line of the input file, loop through, grab a list of sample ids and then work out what is in the interection of all of their comb ids
while(my $line = <SAMPLEIDS>){
	
	print STDERR "Processing line $. of input ... \n";
	
	chomp($line);
	my ($comment,$samids) = split(/\s+/,$line);
	my @sampleids = split(',',$samids);
	
	my @DistinctCombIDs;
	
	unless(scalar(@sampleids) == 1){

		my $lc = List::Compare->new( {
	        lists    => [(@{$SampleID2Combs}{@sampleids})],
	        unsorted => 1,
	        accelerated => 1,
	    } );
		
		my @SampIdsInkeys = keys(%$SampleID2Combs);
		map{assert_in($_,\@SampIdsInkeys,"Sample id from file at line $. isn't in the database as having a source id that matches\n")}@sampleids;
		
		
		unless($union){
			
			@DistinctCombIDs = $lc->get_intersection;
		}else{
			
			@DistinctCombIDs = $lc->get_union;
		}
		
	}else{
		
		@DistinctCombIDs = @{$SampleID2Combs->{$sampleids[0]}};
	}
	
	#If asked to remove DAs that are present in all samples, we do that here
	if($removeubiq){
		
		my $removallc = List::Compare->new( {
	        lists    => [\@DistinctCombIDs,\@UbiqCombs],
	        unsorted => 1,
	        accelerated => 1,
	    } );
	    
	    @DistinctCombIDs = $removallc->get_Lonly;;
	}
	
	my $TaxID2DomArchCountHash ={};
	my $DistinctDAcount=scalar(@DistinctCombIDs);
	
	print STDERR "DistinctDA count for ".$comment." is 0. Consider a higher unique threshold\n" unless($DistinctDAcount > 0);
	
	#Get the MRCA of each and every comb
	foreach my $DA (@DistinctCombIDs){
		
		$tth->execute($DA);
		#Use the comb_MRCA table to get the LCA of the comb
		my ($taxon_id) = $tth->fetchrow_array();
		
		my $MappedTaxonID = $taxon_id;
		$MappedTaxonID = $Taxon_mapping->{$taxon_id} if (exists($Taxon_mapping->{$taxon_id}));
		#If we are using a mappig between epochs, use it to map the LCA to an epoch used
		
		$TaxID2DomArchCountHash->{$MappedTaxonID}++;
		#Finally, uodate the hash
	}
	
	my $CumlativeEpochCount = 0;
	
	#Now for the output. For each epoch, print the percentage of our DA set that comes about at that time, alongside the rolling cumulative
	print TIMEPERCENTAGES $comment."\t";
	foreach my $Epoch (@SortedEpochs){
		
		my $EpochCount=0;
		
		if(exists($TaxID2DomArchCountHash->{$Epoch})){
			
			$EpochCount=$TaxID2DomArchCountHash->{$Epoch};
		}
		
		$CumlativeEpochCount+=$EpochCount;
		
		if($DistinctDAcount > 0){
			my $EpochPercent = 100*$EpochCount/$DistinctDAcount;
			my $CumulativeEcpochPercent= 100*$CumlativeEpochCount/$DistinctDAcount;
			print TIMEPERCENTAGES $EpochPercent.":".$CumulativeEcpochPercent."\t";
		}else{
			print TIMEPERCENTAGES "0:0\t";
		}	
		
	}
	print TIMEPERCENTAGES "\n";
}

close SAMPLEIDS;
close TIMEPERCENTAGES;


__END__

