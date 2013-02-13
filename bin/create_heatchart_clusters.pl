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
use Carp::Assert::More;

# Command Line Options
#-------------------------------------------------------------------------------
my $verbose; #Flag for verbose output from command line opts
my $debug;   #As above for debug
my $help;    #Same again but this time should we output the POD man page defined after __END__
my $cluster_id;

#Set command line flags and parameters.
GetOptions("verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
 			"cluster|c=i" => \$cluster_id
        ) or die "Fatal Error: Problem parsing command-line ".$!;

#Get other command line arguments that weren't optional flags.
my @files= @ARGV;

#Print out some help if it was asked for or if no arguments were given.
pod2usage(-exitstatus => 0, -verbose => 2) if $help;

my ($dbh, $sth);
$dbh = dbConnect();


##################################GET A LIST OF DA PER SAMPLE IN THE CLUSTER ID SPECIFIED#####################################

my $distinct_archictectures_per_sample={};

$sth =   $dbh->prepare( "SELECT DISTINCT(experiment_cluster.sample_name), snapshot_order_comb.comb_id
						FROM snapshot_order_comb JOIN experiment_cluster
						ON snapshot_order_comb.sample_id = experiment_cluster.sample_id
						WHERE experiment_cluster.cluster_id = ?
						;"); 
						
$sth->execute($cluster_id);

my $SamplesNamesHash = {};

##################################COLLECT DATABASE VALUES AND STORE THEM IN A HASH - AN ARRAY OF COMB IDS PER SAMPLENAME PER EPOCH#####################################

while (my ($samplename,$CombID) = $sth->fetchrow_array ) {
	
	$SamplesNamesHash->{$samplename}=undef;
	#We jsut want a list of all the sample names
	
	$distinct_archictectures_per_sample->{$samplename}=[] unless(exists($distinct_archictectures_per_sample->{$samplename}));
	push(@{$distinct_archictectures_per_sample->{$samplename}},$CombID);
}


##################################FOR EACH EPOCH FOR EACH SAMPLE, WORK OUT HOW MANY COMBS EACH SAMPLE SHARED IN COMMON AND OUTPUT A TAB SEPERATED MATRIX#####################################


mkdir("../data");
my @SampleNames =keys(%$SamplesNamesHash); #A list of all the unique taxon ids

$sth->finish;


open DETAILED, ">../data/Detailed.Cluster.".$cluster_id.".dat" or die $!."\t".$?;

my $All_vs_All_Comparison = {};
my $All_vs_All_Ratio = {};

my $TrackingHash = {};
#A laxyway to make sure that we only print out to the detialed result file once
	
foreach my $sample1 (@SampleNames){
			
		$All_vs_All_Comparison->{$sample1}={};
		$All_vs_All_Ratio->{$sample1}={};
		
		$TrackingHash->{$sample1} ={} unless(exists($TrackingHash->{$sample1}));
		
		foreach my $sample2 (@SampleNames){
							
			my ($union,$intersection,undef,undef) = IntUnDiff($distinct_archictectures_per_sample->{$sample1},$distinct_archictectures_per_sample->{$sample2});
			my $NumDAsInCommon = scalar(@$intersection);
			$All_vs_All_Ratio->{$sample1}{$sample2}=$NumDAsInCommon/scalar(@$union);
			$All_vs_All_Comparison->{$sample1}{$sample2}=$NumDAsInCommon;
			
			$TrackingHash->{$sample2} ={} unless(exists($TrackingHash->{$sample2}));
				
			next if (exists($TrackingHash->{$sample1}{$sample2}));
			
			$TrackingHash->{$sample1}{$sample2} = undef;
			$TrackingHash->{$sample2}{$sample1} = undef;
			#Use TrackingHAsh to keep track of the samples that we have already analysed and printed out to file
			
			print DETAILED $sample1.":".$sample2."\t";
			print DETAILED join(",",@$intersection);
			print DETAILED "\n";				
	}
}

close DETAILED;

#Dump heat maps to files for use in R
print STDERR "Print heatmap for cluster $cluster_id .... \n";

open RATIOMAP, ">../data/Cluster.Ratiomap.".$cluster_id.".dat" or die $!."\t".$?; 
open HEATMAP, ">../data/Cluster.Heatmap.".$cluster_id.".dat" or die $!."\t".$?;

print RATIOMAP join("\t",@SampleNames);
print RATIOMAP "\n";

print HEATMAP join("\t",@SampleNames);
print HEATMAP "\n";

foreach my $OutputSampleName (@SampleNames){

	print RATIOMAP $OutputSampleName."\t";
	print RATIOMAP join("\t",@{$All_vs_All_Ratio->{$OutputSampleName}}{@SampleNames});
	print RATIOMAP "\n";
	
	print HEATMAP $OutputSampleName."\t";
	print HEATMAP join("\t",@{$All_vs_All_Comparison->{$OutputSampleName}}{@SampleNames});
	print HEATMAP "\n";
	
}

close RATIOMAP;	
close HEATMAP;	




__END__

