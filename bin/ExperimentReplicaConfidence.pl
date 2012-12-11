#!/usr/bin/env perl

use strict;
use warnings;

=head1 NAME

ExperimentReplicaStudy.pl

=head1 SYNOPSIS

ExperimentReplicaStudy.pl -o --outputfile OUTFILE -t --threshold THRESHOLD_VALUE -c --cutoff EXPRESSION_CUTOFF_VALUE -r --replicates FLAG_FOR_STIPULATING_REPLICATES

 Basic Options:
  -h --help Get full man page output
  -v --verbose Verbose output with details of mutations
  -d --debug Debug output

=head1 DESCRIPTION

This program is part of the TraP Project. We would like to produce a subset of experiments, clustered by experiment name,
with each experiment possesing a single binary value - 1 (expressed) and 0 (not expressed). If, and there more often than not is,
more than one replicate, use a majority conesus at threshold $threshold (DEFAULT 0.75).

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

TODO

=head1 AUTHOR

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

=head1 DEPENDANCY

TraP dependancies:

=item B<Supfam::SQLFunc> Used to connect to a database and handle the resulting objects

=item B<Supfam::Utils> Useful functions

CPAN dependancies:

=over 4

=item B<Getopt::Long> Used to parse command line options.

=item B<Pod::Usage> Used for usage and help output.

=item B<Data::Dumper> Used for debug output.

=back

=cut

use Supfam::SQLFunc  qw(:all);
use Supfam::Utils  qw(:all);

use DBI;
use Getopt::Long; #Deal with command line options
use Pod::Usage;   #Print a usage man page from the POD comments
use Data::Dumper; #Allow easy print dumps of datastructures for debugging
use Carp::Assert; #Carp is used to check parameter inputs and make sure that everything is running as it should
use Carp::Assert::More;

# Command Line Options
#-------------------------------------------------------------------------------
my $verbose; #Flag for verbose output from command line opts
my $debug;   #As above for debug
my $help;    #Same again but this time should we output the POD man page defined after __END__
my $outfile;
my $threshold = 0.75; #A default theshold value of 3/4 majority consesnsu to decide if soemthing is expressed or not.
my $cutoff = 2 ;
my $replicates = 1; #Should a sample have replicates in order to be counted? Default is 'TRUE'
my $convert = 0;

#Set command line flags and parameters.
GetOptions("verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
           "help|h!" => \$help,
           "outfile|o:s" => \$outfile,
           "threshold|t:f" => \$threshold,
           "cutoff|c:f" => \$cutoff,
           "replicates|r!" => \$replicates,
           "comnvert2DA|conv!" => \$convert,
        ) or die "Fatal Error: Problem parsing command-line ".$!;

#Get other command line arguments that weren't optional flags.
my @files= @ARGV;

#Print out some help if it was asked for or if no arguments were given.
pod2usage(-exitstatus => 0, -verbose => 2) if $help;

# Main Script Content
#-------------------------------------------------------------------------------

assert_positive($threshold, "Threshold proportion for majority rules consensus must be between 0 and 1\n");
assert($threshold <= 1,"Threshold proportion for majority rules consensus must be between 0 and 1\n");
assert_positive($cutoff, "Cut off, which is the log(expression) value for which we should call something as 'expressed'  or not must be positive\n");

print STDERR "Using an expression cutoff of log(expression) >= $cutoff\n";
print STDERR "Using a majority rules conesensus of $threshold as to whether a gene is expressed by a cell-type or not \n";
print STDERR "Outputting a dump of sample name and gene_id to comb_id ready to be read into a SQL database \n" if($convert);


my $dbh = dbConnect();

my $sth=$dbh->prepare("SELECT experiment.experiment_id, experiment.sample_name, cell_snapshot.gene_id, cell_snapshot.raw_expression
					FROM experiment JOIN cell_snapshot ON experiment.experiment_id = cell_snapshot.experiment_id
					WHERE experiment.update_number = 7
					;");

my $ExperimentReplicasHashREF = {};
#A hash of structure $HASH->{SampleNameString}{Experiment_id}=log transform_base_e(raw_expression)

$sth->execute();

while (my ($exp_id, $sample_name, $gene_id, $raw_expression) = $sth->fetchrow_array()){
	
	$ExperimentReplicasHashREF->{$sample_name} = {} unless(exists($ExperimentReplicasHashREF->{$sample_name}));
	$ExperimentReplicasHashREF->{$sample_name}{$exp_id}={} unless(exists($ExperimentReplicasHashREF->{$sample_name}{$exp_id}));
	
	
	$ExperimentReplicasHashREF->{$sample_name}{$exp_id}{$gene_id}=log($raw_expression) unless($raw_expression == 0);
	$ExperimentReplicasHashREF->{$sample_name}{$exp_id}{$gene_id}=undef if($raw_expression == 0);
	#Only include a value if it has poisitive expression values. Otherwise include undef
}

print join("\t",keys(%$ExperimentReplicasHashREF)) if($debug);
print "\n";

my $BinaryExpressionHashREF = {};

my $nsamples_accepted = 0;
my $total_samples = scalar(keys(%$ExperimentReplicasHashREF));

foreach my $UniqSampleName (keys(%$ExperimentReplicasHashREF)){
	
	my @ExperimentIDs = keys(%{$ExperimentReplicasHashREF->{$UniqSampleName}}); 
	
	if($replicates){
		
		next unless(scalar(@ExperimentIDs) > 1);
	}
	#The flag $replicates specifies whether we wish to palce a restriction on experiments requiring replcates
	
	my $UniqGeneIDs = {};
	map{$UniqGeneIDs->{$_}=undef}map{keys(%$_)}@{$ExperimentReplicasHashREF->{$UniqSampleName}}{@ExperimentIDs};
	my @GeneIDs = keys(%$UniqGeneIDs);
	
	foreach my $Gene (@GeneIDs){
		
		my @LogExpressionValues;
		
		foreach my $experiment (@ExperimentIDs){
			
			if(exists($ExperimentReplicasHashREF->{$UniqSampleName}{$experiment}{$Gene})){

				my $LogValExp = $ExperimentReplicasHashREF->{$UniqSampleName}{$experiment}{$Gene};
				push(@LogExpressionValues,$LogValExp);	
			}
		}
		
		next if (scalar(@LogExpressionValues) == 0);
		
		my  $NumberAboveThreshold = 0;
		my @NoUndefsLogExpressionValues = grep defined,@LogExpressionValues;
		print join("\t",@NoUndefsLogExpressionValues) if($debug);
	
		map{$NumberAboveThreshold++ if($_ >= $cutoff)}@NoUndefsLogExpressionValues;
		
		my $ThresholdConesus = ($NumberAboveThreshold/scalar(@LogExpressionValues) >= $threshold)?1:0;
		#If there are more values above cuttoff than the majority-rules threshold, set the value as 1. Otherwsie 0.
		$nsamples_accepted++ if($ThresholdConesus);
		$BinaryExpressionHashREF->{$UniqSampleName}{$Gene} = $ThresholdConesus if($ThresholdConesus);
	}
}

print STDERR $nsamples_accepted." = Number of genes accepted\n";
print STDERR $total_samples." = Total number of distinct cell samples\n";
print STDERR $nsamples_accepted/$total_samples." = Average accepted genes per sample\n";


if ($verbose){
	
	EasyDump('./file.dat',$BinaryExpressionHashREF);
}

#If requested, convert all of the per experiemnt gene assignments, following QC, into domain architecture (comb) assignements. These are outputted so as to update an SQL table

if($convert){
	
	print STDERR "Printing a dump of experiment_id & gene_id to comb_id and frequency of expression to filename SQLsnashopordercomb.dat\n";
	
	$sth=$dbh->prepare("SELECT comb_id FROM entrez_longest_comb_all_species WHERE gene_id = ?;");
	
	my $Gene_id2CombIDHashRef = {};
	#A lookup hash, so as to minimise the calls to the database

	open SNAPSHOTCOMB, ">./SQLsnashopordercomb.dat" or die $!." ".$?;
	my $UnmappedGeneIDs = {};
	
	foreach my $UniqSampleName (keys(%$BinaryExpressionHashREF)){
	
		my @GeneIDs = keys(%{$BinaryExpressionHashREF->{$UniqSampleName}});
		
		my @Sample_combs;
		
		my $CombsExpressedHashRef = {};
		
		foreach my $GeneID (@GeneIDs){
			
			unless(exists($Gene_id2CombIDHashRef->{$GeneID}) || exists($UnmappedGeneIDs->{$GeneID})){
			
				$sth->execute($GeneID);
				
				my $nrecords = $sth->rows;
				
				if($nrecords == 0){
					
					$UnmappedGeneIDs->{$GeneID}++;
					next;		
				}
				
				die "GeneID to Comb_id should be a unique mapping! This is not true for $GeneID \n" unless ($sth->rows == 1);
				my ($combID) = $sth->fetchrow_array();
				$Gene_id2CombIDHashRef->{$GeneID} = $combID;
			}
			#Pull datat from the database, unless we've already seen it before
			
			unless(exists($UnmappedGeneIDs->{$GeneID})){
				
				my $comb_id = $Gene_id2CombIDHashRef->{$GeneID};
				$CombsExpressedHashRef->{$comb_id}++;
			}
			#Check if the gene has already been shown to have no mapping. If it does have a mapping, stick it into the mapped hash
			
		}
		
		foreach my $ProcessedGeneID (keys(%$Gene_id2CombIDHashRef)){
			
			my $comb = $Gene_id2CombIDHashRef->{$ProcessedGeneID};
			next unless(exists($CombsExpressedHashRef->{$comb}));
			#Only include combs that are actually expressed.
			
			my $CopyNumberExpressed = $CombsExpressedHashRef->{$comb};
			
			print SNAPSHOTCOMB $ProcessedGeneID."\t".$UniqSampleName."\t".$comb."\t".$CopyNumberExpressed."\n";
		}	
	}
	
	close SNAPSHOTCOMB;
	
	open UNMAPPED, ">UnmappedGene2CombIDs.dat" or die $!." ".$?;
	print UNMAPPED join("\n", keys(%$UnmappedGeneIDs));
	close UNMAPPED;
	
}

$sth->finish;
dbDisconnect($dbh);

__END__

