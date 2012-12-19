#!/usr/bin/env perl

use strict;
use warnings;

=head1 NAME

create_zvals_persample

=head1 SYNOPSIS

skeleton [options] <file>...

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

To get some help output do:

skeleton --help

To list the files in the current directory do:

skeleton *

=head1 AUTHOR

DELETE AS APPROPRIATE!

B<Matt Oates> - I<Matt.Oates@bristol.ac.uk>

B<Owen Rackham> - I<Owen.Rackham@bristol.ac.uk>

B<Adam Sardar> - I<Adam.Sardar@bristol.ac.uk>

=head1 NOTICE

DELETE AS APPROPRIATE!

=over 4

=item B<Matt Oates> (2011) First features added.

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

# Command Line Options
#-------------------------------------------------------------------------------
my $verbose; #Flag for verbose output from command line opts
my $debug;   #As above for debug
my $help;    #Same again but this time should we output the POD man page defined after __END__
my $SQLdump;
my $translation_file;

#Set command line flags and parameters.
GetOptions("verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
           "SQLdump|s!"  => \$SQLdump,
           "help|h!" => \$help,
           "translate|tr:s" => \$translation_file,
        ) or die "Fatal Error: Problem parsing command-line ".$!;

#Get other command line arguments that weren't optional flags.
my @files= @ARGV;

#Print out some help if it was asked for or if no arguments were given.
pod2usage(-exitstatus => 0, -verbose => 2) if $help;

my ( $dbh, $sth );
$dbh = dbConnect();


my $Taxon_mapping ={};

if($translation_file){
	
	open FH, "$translation_file" or die $!."\t".$?;
 	
 	while(my $line = <FH>){
 		
 		chomp($line);
 		my ($from,$to,$taxon_name)=split(/\s+/,$line);
 		carp "Incorrect translation file. Expecting a tab seperated file of 'from' 'to'\n" if($Taxon_mapping ~~ undef || $to ~~ undef);
 		$Taxon_mapping->{$from}=$to;
 	}
}
#This is a bit of a hack - it allows us to map from one many taxpn ids to many. So we can collapse homminnae, catharini etc together to primates


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


##################################GET THE NUMBER OF DISTINCT DOMAIN ARCHITECTURES AT EACH EPOCH FOR EACH SAMPLE######################################
print STDERR "Getting the number of distinct domain architectures from each epoch for each samples ...\n";
my $distinct_architectures_per_epoch_per_sample={};
my %epochs;
my %samples;

$sth =   $dbh->prepare( "SELECT comb_MRCA.taxon_id,snapshot_order_comb.sample_name,COUNT(DISTINCT(snapshot_order_comb.comb_id)) 
						FROM snapshot_order_comb JOIN comb_MRCA 
						ON comb_MRCA.comb_id = snapshot_order_comb.comb_id 
						WHERE comb_MRCA.taxon_id != 0
						GROUP BY comb_MRCA.taxon_id,snapshot_order_comb.sample_name;"); 
$sth->execute;

while (my ($taxid,$samplename,$countCombID) = $sth->fetchrow_array ) {
	
	$taxid = $Taxon_mapping->{$taxid};
	$distinct_architectures_per_epoch_per_sample->{$taxid}={} unless(exists($distinct_architectures_per_epoch_per_sample->{$taxid}));
	$distinct_architectures_per_epoch_per_sample->{$taxid}{$samplename} += $countCombID;
	
	$epochs{$taxid} = 1;
	$samples{$samplename} = 1;
}

EasyDump("./ArchsPerEpochPerSampleHash.dat",$distinct_architectures_per_epoch_per_sample) if($verbose);
EasyDump("./ArchsPerEpochHash.dat",$distinct_archictectures_per_sample) if($verbose);

#################################DIVIDE THE NUMBER AT EACH EPOCH BY THE TOTAL NUMBER TO GET THE PROPORTION##########################################
my $proportion_of_architectures_per_epoch_per_sample = {};

foreach my $epoch (keys %epochs){
	
	$proportion_of_architectures_per_epoch_per_sample->{$epoch}={};
	
	foreach my $sample (keys %samples){
		
		
		croak "Uninitialized here\n" unless(exists($distinct_archictectures_per_sample->{$epoch}));
		my $distarchs = $distinct_archictectures_per_sample->{$epoch};
		croak "Died at sample $sample and epoch $epoch as number distinct archs =$distarchs \n" unless($distarchs > 0);
		
		next unless(exists($distinct_architectures_per_epoch_per_sample->{$epoch}{$sample}));

		my $persampledistarchs = $distinct_architectures_per_epoch_per_sample->{$epoch}{$sample};
		croak "Died at sample $sample and epoch $epoch as number distinct archs = $persampledistarchs \n" unless($persampledistarchs > 0);
		
		$proportion_of_architectures_per_epoch_per_sample->{$epoch}{$sample} = $persampledistarchs/$distarchs;
		#Divide the number of domain architectures used by the sample at that stage by the total number of distinct architectures at that epoch
	}
}
#print Dumper \%proportion_of_architectures_per_epoch_per_sample;

my $SampleZscoreHash = {};
#A hash of structure $hash->{epoch_MRCA_taxon_id}{sample_id}{z_score}

print STDERR "Outputting Z score data and hists" if($verbose);

foreach my $MRCA (keys(%$proportion_of_architectures_per_epoch_per_sample)){
	
	print STDERR "Processing $MRCA ...\n";
	 	
	my $TempHash = calc_ZScore($proportion_of_architectures_per_epoch_per_sample->{$MRCA});
	#Hash structure is of $Hash{Tax_id}{samples}= proportion
	$SampleZscoreHash->{$MRCA}=$TempHash;
	
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
	print STDOUT "Creating an SQL tab-sep compatable dump in the Trap/data directory labelled: sample_name\tproportion\ttaxon_id\tepochsize\n";
	
	open SQL, ">../data/ZvalsSQLData.dat" or die $!."\t".$?;
	
	foreach my $tax_id (keys(%$SampleZscoreHash)){
		
		foreach my $expid (keys(%{$SampleZscoreHash->{$tax_id}})){
			
			my $proportion = $SampleZscoreHash->{$tax_id}{$expid};
			my $epoch_size;
			
			if(exists($distinct_architectures_per_epoch_per_sample->{$tax_id}{$expid})){
				
				$epoch_size = $distinct_architectures_per_epoch_per_sample->{$tax_id}{$expid};
			}else{
				
				$epoch_size = 0;
			}
			
			print SQL $expid."\t".$proportion."\t".$tax_id."\t".$epoch_size."\n";
		}
	}
	
	close SQL;
}

__END__

