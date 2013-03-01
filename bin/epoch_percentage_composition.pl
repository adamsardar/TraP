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

./epoch_percentage_composition.pl  -tr TaxaMappingsFull.txt --samples ~/not_cad_nuc -u 1 -d --output ../data/not_cad_nuc.txt --union -e -c 0
#Processes tissue samples as well

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
use List::Util qw(sum);
use POSIX qw(ceil);
use List::MoreUtils qw/ uniq /;

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
my $domains = 0;
my $epochcount = 0;

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
           "epochcount|e!" => \$epochcount,
        ) or die "Fatal Error: Problem parsing command-line ".$!;

#Get other command line arguments that weren't optional flags.
my @files= @ARGV;

assert_in($source,[qw(1 2 3 0)],"Allowed options for -c|--source are 1,2,3 and NULL\n");
$source = undef if($source == 0);

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

open TIMESUMMARY, ">".$out.".sum" or die $!."\t".$?;
print TIMESUMMARY "0%	5%	25%	50%	75%	95%	100%\n";

open TIMEDETAILS, ">".$out.".detailed" or die $!."\t".$?;
open TIMEDOMAINS, ">".$out.".domains" or die $!."\t".$?;

if($source){
	
	$sth = $dbh->prepare("SELECT DISTINCT snapshot_order_comb.sample_id,snapshot_order_comb.comb_id 
					FROM snapshot_order_comb
					JOIN sample_index ON sample_index.sample_id = snapshot_order_comb.sample_id
					AND sample_index.source = ?;");
						

	$sth->execute($source);
						
}else{
	$sth = $dbh->prepare("SELECT DISTINCT snapshot_order_comb.sample_id,snapshot_order_comb.comb_id 
					FROM snapshot_order_comb
					JOIN sample_index ON sample_index.sample_id = snapshot_order_comb.sample_id;");

	$sth->execute();
}


						
$tth = $ebh->prepare("SELECT comb_MRCA.taxon_id
						FROM comb_MRCA
						WHERE comb_id = ?");

my $SampleID2Combs = {};
#Grab a list of comb ids per sample and whack them into a hash

print STDERR "Creating the hash SampleID2combs.dat ...";



#Read in sample ids and make a hash of sample id names to distinct combs
		
while (my ($sample_id,$comb_id) = $sth->fetchrow_array()){
			
			$SampleID2Combs->{$sample_id}=[] unless(exists($SampleID2Combs->{$sample_id}));
			push(@{$SampleID2Combs->{$sample_id}},$comb_id);
}
print STDERR "done!\n";




my $samplegroups2combs = {};

#For each line of the input file, loop through, grab a list of sample ids and then work out what is in the interection of all of their comb ids

while(my $line = <SAMPLEIDS>){
			
	chomp($line);
	my ($comment,$samids) = split(/\t+/,$line);
	my @sampleids = split(',',$samids);
	
	assert_lacks($samplegroups2combs, $comment, "Sample group names need to be unique!\n" );
	map{assert_in($_,[keys(%$SampleID2Combs)],"Sample id $_ not in the database - error!\n")}@sampleids;
	
	if(scalar(@sampleids) > 1){
		my $lc = List::Compare->new( {
	        lists    => [(@{$SampleID2Combs}{@sampleids})],
	        unsorted => 1,
	        accelerated => 1,
	    } );
		
		unless($union){
			
			$samplegroups2combs->{$comment} = $lc->get_intersection_ref;
		}else{
			
			$samplegroups2combs->{$comment} = $lc->get_union_ref;
		}
	}else{
		
		$samplegroups2combs->{$comment} = 	$SampleID2Combs->{$sampleids[0]};
	}
	
}


#If requested (using -r or --removeubiq), make a lsit of DAs that exists in ALL samples
my @UbiqCombs;
if($removeubiq){
	
	my $TotalSampleCompare = List::Compare->new( {
		        lists    => [(@{$samplegroups2combs}{keys(%$samplegroups2combs)})],
		        unsorted => 1,
		    });
	
	my $NumberGroups= scalar(keys(%$samplegroups2combs));
	my $SampleNumberThreshold = POSIX::floor($NumberGroups*$UbiqFuzzyThreshold/100);
	$SampleNumberThreshold = 2 if($SampleNumberThreshold < 2); #Just a catch all
	my @BagOfCombs = $TotalSampleCompare->get_bag;
	
	my $Combcount = {};
	print STDERR scalar(@BagOfCombs)." - Bag of combs size\n" if($debug);
	
	while (my $comb = shift(@BagOfCombs)){
		#Try to stay smart on memory
		
		$Combcount->{$comb}++;
	}

	foreach my $comb (keys(%$Combcount)){
		
		push(@UbiqCombs,$comb) if($Combcount->{$comb} >= $SampleNumberThreshold);
	}

	print STDERR "(Threshold of $UbiqFuzzyThreshold % translates to a sample number threshold of $SampleNumberThreshold , where the total corpus is $NumberGroups samples)\n";
	print STDERR "Number of ubiquitous domain archs:".scalar(@UbiqCombs)." - these shall be removed from the sample sets that you have inputted\n";
		
}




#Change to being foreach samplegroup
foreach my $comment (keys(%$samplegroups2combs)){
	
	print STDERR "Processing $comment of input ... \n";

	my @DistinctCombIDs;
	
	#If asked to remove DAs that are present in all samples, we do that here
	if($removeubiq){
		
		my $removallc = List::Compare->new( {
	        lists    => [$samplegroups2combs->{$comment},\@UbiqCombs],
	        unsorted => 1,
	        accelerated => 1,
	    } );
	    
	    @DistinctCombIDs = $removallc->get_unique;
	    #Get items which only appear in the first list
	}
	
	my $TaxID2DomArchCountHash ={};
	my $DistinctDAcount=scalar(@DistinctCombIDs);
	
	print STDERR "DistinctDA count for ".$comment." is 0. Consider a higher unique threshold\n" unless($DistinctDAcount > 0);
	
	#Get the MRCA of each and every comb
	print TIMEDETAILS $comment."\t";
	print TIMEDOMAINS  $comment."\t";
	
	foreach my $DA (@DistinctCombIDs){
		
		$tth->execute($DA);
		#Use the comb_MRCA table to get the LCA of the comb
		my ($taxon_id) = $tth->fetchrow_array();
				
		my $MappedTaxonID = $taxon_id;
		$MappedTaxonID = $Taxon_mapping->{$taxon_id} if (exists($Taxon_mapping->{$taxon_id}));
		#If we are using a mappig between epochs, use it to map the LCA to an epoch used
		
		$TaxID2DomArchCountHash->{$MappedTaxonID}++;
		#Finally, uodate the hash
		

		print TIMEDETAILS $MappedTaxonID."\t";					
		print TIMEDOMAINS $DA."\t";
	}
	
	print TIMEDETAILS "\n";
	print TIMEDOMAINS "\n";
	
	map{assert_in($_,\@SortedEpochs,"Your tax mapping needs to include $_ as at current it is unmapped\n")}keys(%$TaxID2DomArchCountHash);
	
	my $CumlativeEpochCount = 0;
	
	#Now for the output. For each epoch, print the percentage of our DA set that comes about at that time, alongside the rolling cumulative
	print TIMEPERCENTAGES $comment."\t";

	my $cent0cutoff = 1;
	my $cent5cutoff = 5;
	my $cent25cutoff =25;
	my $cent50cutoff = 50;
	my $cent75cutoff = 75;
	my $cent95cutoff = 95;
	my $cent100cutoff=100;

	print TIMESUMMARY $comment;
	
	foreach my $Epoch (@SortedEpochs){
		
		my $EpochCount=0;
		
		if(exists($TaxID2DomArchCountHash->{$Epoch})){
			
			$EpochCount=$TaxID2DomArchCountHash->{$Epoch};
		}
		
		$CumlativeEpochCount+=$EpochCount;
		
		if($DistinctDAcount > 0){
			my $EpochPercent = 100*$EpochCount/$DistinctDAcount;
			my $CumulativeEcpochPercent= 100*$CumlativeEpochCount/$DistinctDAcount;
			
			unless($epochcount){
		
				print TIMEPERCENTAGES $EpochPercent.":".$CumulativeEcpochPercent."\t";
			}else{
				
				print TIMEPERCENTAGES $EpochCount."\t";
			}
			
			
			if($CumulativeEcpochPercent > $cent0cutoff){
				print STDERR "Here 0% $CumulativeEcpochPercent !\n" if($verbose);
				print TIMESUMMARY "\t".$Epoch;
				$cent0cutoff = 101;#Set an impossible cutoff sothat it will never again be reached
			}
			
			if($CumulativeEcpochPercent > $cent5cutoff){
				print STDERR "Here 5% $CumulativeEcpochPercent !\n" if($verbose);
				print TIMESUMMARY "\t".$Epoch;
				$cent5cutoff = 101;#Set an impossible cutoff sothat it will never again be reached
			}
			
			if($CumulativeEcpochPercent > $cent25cutoff){
				print STDERR "Here 25% $CumulativeEcpochPercent !\n" if($verbose);
				print TIMESUMMARY "\t".$Epoch;
				$cent25cutoff = 101;#Set an impossible cutoff sothat it will never again be reached
			}
			
			if($CumulativeEcpochPercent > $cent50cutoff){
				print STDERR "Here 50% $CumulativeEcpochPercent !\n" if($verbose);
				print TIMESUMMARY "\t".$Epoch;
				$cent50cutoff = 101;#Set an impossible cutoff sothat it will never again be reached
			}
			
			if($CumulativeEcpochPercent > $cent75cutoff){
				print STDERR "Here 75% $CumulativeEcpochPercent !\n" if($verbose);
				print TIMESUMMARY "\t".$Epoch;
				$cent75cutoff = 101;#Set an impossible cutoff sothat it will never again be reached
			}
			
			if($CumulativeEcpochPercent > $cent95cutoff){
				print STDERR "Here 95% $CumulativeEcpochPercent !\n" if($verbose);
				print TIMESUMMARY "\t".$Epoch;
				$cent95cutoff = 101;#Set an impossible cutoff sothat it will never again be reached
			}
			
			if($CumulativeEcpochPercent >= $cent100cutoff){
				print STDERR "Here 100% $CumulativeEcpochPercent !\n" if($verbose);
				print TIMESUMMARY "\t".$Epoch;
				$cent100cutoff = 101;#Set an impossible cutoff sothat it will never again be reached
			}
			
		}else{
			
			#Just in case there are no domain archs
			unless($epochcount){
				print TIMEPERCENTAGES "0:0\t";
			}else{
				print TIMEPERCENTAGES "0\t";
			}
			
		}
		
	}
	print TIMEPERCENTAGES "\n";
	print TIMESUMMARY "\n";
}

close SAMPLEIDS;
close TIMEPERCENTAGES;
close TIMEDETAILS;
close TIMEDOMAINS;

__END__

