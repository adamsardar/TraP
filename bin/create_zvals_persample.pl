#!/usr/bin/env perl

use strict;
use warnings;

=head1 NAME

create_zvals_persample.pl 

=head1 SYNOPSIS

create_zvals_persample [-h -v -d] -tr --translate taxon_mapping_file -df --disallowed disallowed_sample_names -iz --includezero include_zero_scores_in_zscores

 Basic Options:
  -h --help Get full man page output
  -v --verbose Verbose output with details of mutations
  -d --debug Debug output

=head1 DESCRIPTION

This program is part of the TraP Project suite.

=head1 OPTIONS

=over 8

=item B<-h, --help>

Print this brief help message from the command line.

=item B<-d, --debug>

Print debug output showing how the text is being mutated with thesaurus usage.

=item B<-v, --verbose>

Verbose output showing how the text is changing.

=back

=head1 EXAMPLES

create_zvals_persample.pl -s -tr ./TaxaMappingsCollapsed.txt 

 ... TO OUTPUT AN SQL DUMP OF TABLE


=head1 AUTHOR

B<Owen Rackham> - I<Owen.Rackham@bristol.ac.uk>

B<Adam Sardar> - I<Adam.Sardar@bristol.ac.uk>

=head1 NOTICE

=over 4

=item B<Owen Rackham> (2011) First features added.

=item B<Adam Sardar> (2011) First features added.

=back

=head1 LICENSE AND COPYRIGHT

B<Copyright 2011 Matt Oates, Owen Rackham, Adam Sardar>

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
my $SQLdump;
my $translation_file;
my $DisallowedSampleFile;
my $IncludeZero = 1;

#Set command line flags and parameters.
GetOptions("verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
           "SQLdump|s!"  => \$SQLdump,
           "help|h!" => \$help,
           "translate|tr:s" => \$translation_file,
           "disallowed|df:s" => \$DisallowedSampleFile,
           "includezero|iz!" => \$IncludeZero,
        ) or die "Fatal Error: Problem parsing command-line ".$!;

#Get other command line arguments that weren't optional flags.
my @files= @ARGV;

#Print out some help if it was asked for or if no arguments were given.
pod2usage(-exitstatus => 0, -verbose => 2) if $help;

my ( $dbh, $sth );
$dbh = dbConnect();


my $Taxon_mapping ={};

if($translation_file){
	
	print STDERR "Creating a mapping between taxon_ids ....\n";
	open FH, "$translation_file" or die $!."\t".$?;
 	
 	while(my $line = <FH>){
 		
 		chomp($line);
 		my ($from,$to,$taxon_name)=split(/\s+/,$line);
 		croak "Incorrect translation file. Expecting a tab seperated file of 'from' 'to'\n" if($Taxon_mapping ~~ undef || $to ~~ undef);
 		$Taxon_mapping->{$from}=$to;
 	}
 	
 	close FH;
}


my $DisallowedSamples = {};

if($DisallowedSampleFile){
	
	print STDERR "Creating a list of diassallowed sample names ....\n";
	open DISALLOWED, "$DisallowedSampleFile" or die $!."\t".$?;
 	
 	while(my $line = <DISALLOWED>){
 		
 		chomp($line);
 		croak "Incorrect disallowed file. Expecting a new line seperated file of sample_name\n" if($line ~~ undef);
 		$DisallowedSamples->{$line}=undef
 	}
	
	close DISALLOWED;
}


##################################GET THE NUMBER OF DISTINCT DOMAIN ARCHITECTURE FROM ANY EPOCH FOR EACH SAMPLE#####################################

print STDERR "Getting the number of distinct domain architectures from each epoch across all samples ...\n";
my $distinct_archictectures_per_sample = {};
$sth =   $dbh->prepare( "SELECT comb_MRCA.taxon_id,COUNT(DISTINCT(snapshot_order_comb.comb_id)) 
						FROM snapshot_order_comb JOIN comb_MRCA 
						ON comb_MRCA.comb_id = snapshot_order_comb.comb_id 
						WHERE comb_MRCA.taxon_id != 0
						GROUP BY comb_MRCA.taxon_id;"); 
$sth->execute;
        
while (my ($taxid,$countCombID) = $sth->fetchrow_array ) {
	
	unless(exists($Taxon_mapping->{$taxid})){

		$Taxon_mapping->{$taxid}=$taxid;
		#So unless we have a mapping, set our taxid to map to itself	
	}
	
	$taxid = $Taxon_mapping->{$taxid};
	$distinct_archictectures_per_sample->{$taxid} += $countCombID;
}
#NOTE: Some of the sequences do not map to superfamily comb_ids. Hence they have a taxon id of 0 and a taxon_id of 0 in the database
$sth->finish();

##################################GET THE NUMBER OF DISTINCT DOMAIN ARCHITECTURES AT EACH EPOCH FOR EACH SAMPLE######################################
print STDERR "Getting the number of distinct domain architectures from each epoch for each samples ...\n";
my $distinct_architectures_per_epoch_per_sample={};
my $PerSampleTotalNumberDistinctCombsExpressed = {};

$sth =   $dbh->prepare( "SELECT comb_MRCA.taxon_id,sample_index.sample_name,COUNT(DISTINCT(snapshot_order_comb.comb_id)), snapshot_order_comb.sample_id
						FROM snapshot_order_comb 
						JOIN comb_MRCA 
						ON comb_MRCA.comb_id = snapshot_order_comb.comb_id
						JOIN sample_index
						ON snapshot_order_comb.sample_id = sample_index.sample_id
						WHERE comb_MRCA.taxon_id != 0
						GROUP BY comb_MRCA.taxon_id,snapshot_order_comb.sample_id;"); 
$sth->execute;

my $sample_name2Index = {};

while (my ($tax,$samplename,$countCombID,$sampleID) = $sth->fetchrow_array ) {
	
	$sample_name2Index->{$samplename}=$sampleID unless(exists($sample_name2Index->{$samplename}));
	
	next if(exists($DisallowedSamples->{$samplename}));	

	my 	$taxid = $Taxon_mapping->{$tax};
	$distinct_architectures_per_epoch_per_sample->{$taxid}={} unless(exists($distinct_architectures_per_epoch_per_sample->{$taxid}));
	
	$distinct_architectures_per_epoch_per_sample->{$taxid}{$samplename} += $countCombID;
	#$PerSampleTotalNumberDistinctCombsExpressed->{$samplename} += $countCombID;
}

$sth->finish();


################################## Get a count of the number of architectures expressed per sample   ################################## 

 
$sth =   $dbh->prepare( "SELECT sample_index.sample_name,COUNT(DISTINCT(snapshot_order_comb.comb_id)) 
						FROM snapshot_order_comb
						JOIN sample_index
						ON snapshot_order_comb.sample_id = sample_index.sample_id
						GROUP BY sample_index.sample_name;"); 
$sth->execute;

while (my ($samplename,$countCombID) = $sth->fetchrow_array ) {
	
	next if(exists($DisallowedSamples->{$samplename}));	

	$PerSampleTotalNumberDistinctCombsExpressed->{$samplename} = $countCombID;
}

$sth->finish();

if($verbose){

	EasyDump("../data/ArchsPerEpochPerSampleHash.dat",$distinct_architectures_per_epoch_per_sample);
	EasyDump("../data/ArchsPerEpochHash.dat",$distinct_archictectures_per_sample);
	EasyDump("../data/PersampleCount.dat",$PerSampleTotalNumberDistinctCombsExpressed);
 }

#################################DIVIDE THE NUMBER AT EACH EPOCH BY THE TOTAL NUMBER TO GET THE PROPORTION##########################################
my $proportion_of_architectures_per_epoch_per_sample = {};

print STDERR "Not includeding zeroes in z score calcs - " unless($IncludeZero);

foreach my $epoch (keys %$distinct_architectures_per_epoch_per_sample){
	
	$proportion_of_architectures_per_epoch_per_sample->{$epoch}={};
	
	foreach my $sample (keys %$PerSampleTotalNumberDistinctCombsExpressed){
		
		my $sampleexpresseddistarchs = $PerSampleTotalNumberDistinctCombsExpressed->{$sample};
		croak "Died at sample $sample and epoch $epoch as number distinct archs = $sampleexpresseddistarchs \n" unless($sampleexpresseddistarchs > 0);
				
		if(exists($distinct_architectures_per_epoch_per_sample->{$epoch}{$sample})){
			
			my $PerSampleDistarchs  = $distinct_architectures_per_epoch_per_sample->{$epoch}{$sample};
			croak "Died at sample $sample and epoch $epoch as number distinct archs = $PerSampleDistarchs \n" unless($PerSampleDistarchs > 0);
			$proportion_of_architectures_per_epoch_per_sample->{$epoch}{$sample} = $PerSampleDistarchs/$sampleexpresseddistarchs
			#Divide the number of domain architectures used by the sample at that stage by the total number of distinct architectures that architecture expresses. So what proportion of it's expression is at that stage
		
		}else{
			
			$proportion_of_architectures_per_epoch_per_sample->{$epoch}{$sample} = 0 if($IncludeZero);
		}
		# Think of this value as - "Hom much the repertoire available does it express at this time, and what proportion of its total expression does this represent"
	}	

}
#print Dumper \%proportion_of_architectures_per_epoch_per_sample;

EasyDump("../data/ArchProportion.dat",$proportion_of_architectures_per_epoch_per_sample) if($verbose);

my $SampleZscoreHash = {};
#A hash of structure $hash->{epoch_MRCA_taxon_id}{sample_id}{z_score}

print STDERR "Outputting Z score data and hists ..." if($verbose);

foreach my $MRCA (keys(%$proportion_of_architectures_per_epoch_per_sample)){
	
	print STDERR "Processing $MRCA ...";
	
	my $TempProportionsHash = $proportion_of_architectures_per_epoch_per_sample->{$MRCA};
	my $TempHash = calc_ZScore($TempProportionsHash);
	#Hash structure is of $Hash{Tax_id}{samples}= proportion
	assert_hashref($TempHash,"calc_ZScore should return a hashref ...\n");
	
	$SampleZscoreHash->{$MRCA}=$TempHash;
	
	print STDERR scalar(keys(%$TempHash))." samples\n";
	
	if($verbose){
		mkdir("../data");
		open FH, ">../data/TaxonID.".$MRCA.".zscores.dat" or die $!.$?;
		print FH join("\n",values(%$TempHash));
		close FH;
	
		` Hist.py -f ../data/TaxonID.$MRCA.zscores.dat -o ../data/TaxonID.$MRCA.zscores.png -u 0` 
	}
}

EasyDump('../data/Zscores.dat',$SampleZscoreHash) if($verbose);

if($SQLdump){
	
	mkdir("../data");
	print STDOUT "Creating an SQL tab-sep compatable dump in the Trap/data directory labelled: sample_name\tz_score\ttaxon_id\tepochsize\n";
	
	open SQL, ">../data/ZvalsSQLData.dat" or die $!."\t".$?;
	
	foreach my $tax_id (keys(%$SampleZscoreHash)){
		
		foreach my $samp (keys(%{$SampleZscoreHash->{$tax_id}})){
			
			my $zscore = $SampleZscoreHash->{$tax_id}{$samp};
			my $epoch_size;
			
			if(exists($distinct_architectures_per_epoch_per_sample->{$tax_id}{$samp})){
				
				$epoch_size = $distinct_architectures_per_epoch_per_sample->{$tax_id}{$samp};
			}else{
				
				$epoch_size = 0;
			}
			
			print SQL $samp."\t".$zscore."\t".$tax_id."\t".$epoch_size."\n";
		}
	}
	
	close SQL;
}


if($verbose){
	
	mkdir("../data");
	print STDOUT "Creating a reference file of all the data that we have calculated so far, in the Trap/data directory labelled: sample_name\tproportion\tzscore\ttaxon_id\tepochsize\tDomArchcount\n";
	
	open COMPLETE, ">../data/completeAscores.check.dat" or die $!."\t".$?;
	
	foreach my $tax_id (keys(%$SampleZscoreHash)){
		
		foreach my $samp (keys(%{$SampleZscoreHash->{$tax_id}})){
			
			my $zscore = $SampleZscoreHash->{$tax_id}{$samp};
			my $proportion = $proportion_of_architectures_per_epoch_per_sample->{$tax_id}{$samp};
			my $DomArchCountPerSample = $PerSampleTotalNumberDistinctCombsExpressed->{$samp};
			my $DomArchCountPerEpoch = $distinct_archictectures_per_sample->{$tax_id};
			
			
			my $epoch_size;
			
			if(exists($distinct_architectures_per_epoch_per_sample->{$tax_id}{$samp})){
				
				$epoch_size = $distinct_architectures_per_epoch_per_sample->{$tax_id}{$samp};
			}else{
				
				$epoch_size = 0;
			}
			
			my $sampID = $sample_name2Index->{$samp};
			
			print COMPLETE $samp."\t".$sampID."\t".$proportion."\t".$zscore."\t".$tax_id."\t".$epoch_size."\t".$DomArchCountPerSample."\t".$DomArchCountPerEpoch."\n";
		}
	}
	
	close COMPLETE;
}



__END__

