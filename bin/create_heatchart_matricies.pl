#!/usr/bin/env perl

use strict;
use warnings;

=head1 NAME

create_zvals_persample.pl

=head1 SYNOPSIS

create_zvals_persample.pl -s --SQLdump Output a SQL readable file of z-scores for each sample and at each taxon id  -tr --translate a file containing mappings from on taxon_id to another (this allows for one to collapse homminnan and homminadae to primates, for example)


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

Print debug output

=item B<-v, --verbose>

Verbose output showing how the text is changing.

=back

=head1 EXAMPLES

./create_zvals_persample.pl -v -s

This will output an sql tab seperated file for reading inot a databse or processesing using  scripts, as well as outputting the internal hashes (verbose) for the user to inspect

=head1 AUTHOR

DELETE AS APPROPRIATE!

B<Matt Oates> - I<Matt.Oates@bristol.ac.uk>

B<Owen Rackham> - I<Owen.Rackham@bristol.ac.uk>

B<Adam Sardar> - I<Adam.Sardar@bristol.ac.uk>

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
use List::MoreUtils qw(uniq);

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

my ($dbh, $sth);
$dbh = dbConnect();

my $Taxon_mapping ={};

if($translation_file){
	
	open FH, "$translation_file" or die $!."\t".$?;
 	
 	while(my $line = <FH>){
 		
 		chomp($line);
 		my ($from,$to,$taxon_name)=split(/\t+/,$line);
 		carp "Incorrect translation file. Expecting a tab seperated file of 'from' 'to'\n" if($Taxon_mapping ~~ undef || $to ~~ undef);
 		$Taxon_mapping->{$from}=$to;
 	}
}
#This is a bit of a hack - it allows us to map from one many taxpn ids to many. So we can collapse homminnae, catharini etc together to primates


##################################GET THE NUMBER OF DISTINCT DOMAIN ARCHITECTURE FROM ANY EPOCH FOR EACH SAMPLE#####################################

my $distinct_archictectures_per_sample={};

$sth =   $dbh->prepare( "SELECT DISTINCT(snapshot_order_comb.comb_id),comb_MRCA.taxon_id,snapshot_order_comb.sample_name 
						FROM snapshot_order_comb JOIN comb_MRCA 
						ON comb_MRCA.comb_id = snapshot_order_comb.comb_id 
						WHERE comb_MRCA.taxon_id != 0;
						;"); 
$sth->execute;


##################################COLLECT DATABASE VALUES AND STORE THEM IN A HASH - AN ARRAY OF COMB IDS PER SAMPLENAME PER EPOCH#####################################

while (my ($CombID,$taxid,$samplename) = $sth->fetchrow_array ) {
	
	unless(exists($Taxon_mapping->{$taxid})){

		$Taxon_mapping->{$taxid}=$taxid;
		#So unless we have a mapping, set our taxid to map to itself	
	}
	
	$taxid = $Taxon_mapping->{$taxid};
	
	$distinct_archictectures_per_sample->{$samplename}={} unless(exists($distinct_archictectures_per_sample->{$samplename}));
	$distinct_archictectures_per_sample->{$samplename}{$taxid}=[] unless(exists($distinct_archictectures_per_sample->{$samplename}{$taxid}));
	
	push(@{$distinct_archictectures_per_sample->{$taxid}{$samplename}},$CombID);
}

##################################FOR EACH EPOCH FOR EACH SAMPLE, WORK OUT HOW MANY COMBS EACH SAMPLE SHARED IN COMMON AND OUTPUT A TAB SEPERATED MATRIX#####################################


mkdir("../data");
my @SampleNames = keys(%$distinct_archictectures_per_sample); #A list of all the indivual sample names
my @epochs = uniq(values(%$Taxon_mapping)); #A list of all the unique taxon ids

foreach my $epoch (@epochs){

	my $Epoch_All_vs_All_Comparison = {};
		
	foreach my $sample1 (@SampleNames){
			
			$Epoch_All_vs_All_Comparison->{$sample1}={};
			
			foreach my $sample2 (@SampleNames){
				
				my $NumDAsInCommon = 0;
				
				if(exists($distinct_archictectures_per_sample->{$epoch}{$sample1}) && exists($distinct_archictectures_per_sample->{$epoch}{$sample2})){
					
					my (undef,$intersection,undef,undef) = IntUnDiff($distinct_archictectures_per_sample->{$epoch}{$sample1},$distinct_archictectures_per_sample->{$epoch}{$sample2});
					$NumDAsInCommon = scalar(@$intersection);
				}
			
				$Epoch_All_vs_All_Comparison->{$sample1}{$sample2}=$NumDAsInCommon;
		}
}
	
	
	#Dump heat maps to files for use in R
	print STDERR "Print heatmap for $epoch .... \n";
	
	open HEATMAP, ">../data/Heatmap.".$epoch.".dat" or die $!."\t".$?; 
	
	print HEATMAP join("\t",('SAMPLE',@SampleNames));
	print HEATMAP "\n";
	
	foreach my $OutputSampleName (@SampleNames){
	
		print HEATMAP $OutputSampleName."\t";
		print HEATMAP join("\t",@{$Epoch_All_vs_All_Comparison->{$OutputSampleName}}{@SampleNames});
		print HEATMAP "\n";
	}
	
	close HEATMAP;
}



__END__

