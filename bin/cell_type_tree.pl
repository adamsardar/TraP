#!/usr/bin/env perl

use strict;
use warnings;

=head1 NAME

cell_type_tree.pl v1.0 - Build a cell type tree.

=head1 SYNOPSIS

cell_type_tree

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

=head1 AUTHOR

B<Matt Oates> - I<Matt.Oates@bristol.ac.uk>

B<Owen Rackham> - I<Owen.Rackham@bristol.ac.uk>

B<Adam Sardar> - I<Adam.Sardar@bristol.ac.uk>

=head1 NOTICE

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

=head1 DEPENDANCY

TraP dependancies:

=over 4

=item B<TraP::SQL::TissueMRCA> Used to perform SQL queries.

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
use Statistics::Descriptive;
use TraP::SQL::TissueMRCA qw/:all/;

# Command Line Options
#-------------------------------------------------------------------------------
my $verbose; #Flag for verbose output from command line opts
my $debug;   #As above for debug
my $help;    #Same again but this time should we output the POD man page defined after __END__

#Set command line flags and parameters.
GetOptions("verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
           "help|h!" => \$help,
        ) or die "Fatal Error: Problem parsing command-line ".$!;

#Get other command line arguments that weren't optional flags.
#my @files= @ARGV;

#Print out some help if it was asked for or if no arguments were given.
pod2usage(-exitstatus => 0, -verbose => 2) if $help;

=head1 FUNCTIONS DEFINED

=over 4

=cut

# Main Script Content
#-------------------------------------------------------------------------------

my %experiment_genomes;
my %experiment_ncbi;
my %experiment_sfs;
my %experiment_supras;
my %experiment_protein_genedistances;
my $source = 7;
my $root_genome = 'hs';
#for every experiment we will collect the supraIDs of the dopamian architectures that are expressed and
#also the gene distances of each of the proteins that are expressed.
foreach my $experiment (sort {$b <=> $a} @{human_cell_type_experiments($source)}) {
	print "running $experiment...\n";
	#$experiment_sfs{$experiment} = experiment_sfs($experiment);
	$experiment_supras{$experiment} = experiment_supras($experiment,$root_genome);
	$experiment_protein_genedistances{$experiment} = experiment_protein_genedistance($experiment,50);
	print "got experiment superfamilies\n";
}
	my $all_protein_genedistances = all_protein_genedistance(1,50);

#for a given source we will collect any supraID for a domain architecture that is expressed in any experiment.
	print "now getting all sfs\n";
	#my $supfams = all_sfs($source);
	#this supras is an array of supraIDs that are expressed and protein_lookup is a mapping from proteinID to supraID
	my ($supras,$protein_lookup,$supra_lookup) = all_supras($source,$root_genome);
	my %protein_lookup = %{$protein_lookup};
	my %supra_lookup = %{$supra_lookup};
	print "now genomes for each sf\n";
	
	#my $sf_genomes = sf_genomes($supfams);
#Given a list of supras provided above we now collect all the genomes that a supra is in
	my $supra_genomes = supra_genomes($supras);
	print "got genomes\n";
	print "got ncbi details\n";
#for a set of genomes for each supra we calculate where on the tree that supra first appeared
	my ($Supra2TreeDataHash,$ncbi_placement) = calculateMRCAstats($supra_genomes,$root_genome);
	my %Supra2TreeDataHash = %{$Supra2TreeDataHash};
	my %ncbi_placement = %{$ncbi_placement};
#This is counts supras at each distance
	my %distances;
	my %s_distances;
	foreach my $supra (keys %ncbi_placement){
		my $dist = $ncbi_placement{$supra};
		if(exists($distances{$dist})){
			$distances{$dist} = $distances{$dist} + scalar(@{$supra_lookup{$supra}});
			$s_distances{$dist} = $s_distances{$dist} +1;
		}else{
			$distances{$dist} = scalar(@{$supra_lookup{$supra}});
			$s_distances{$dist} = 1;
		}
	}

	my $ncbi_distances = calculate_NCBI_taxa_range_distances([keys %distances],$root_genome);
	my %ncbi_distances = %{$ncbi_distances};
	open DIST,">../../data/Trap/distances.txt";
	foreach my $dist (sort { $ncbi_distances{$a} <=> $ncbi_distances{$b}} keys %distances){
		print DIST "$dist($ncbi_distances{$dist})\t$distances{$dist}($s_distances{$dist})\n";
	}


	
	#my %protein_genedistances = %{$all_protein_genedistances};
#here we are going to loop through all the proteins that each supra is in and map the distance and gene_distance.
my %exp_distances;
my %exp_s_distances;
my %dist_totals;
my %s_dist_totals;
my $exps = scalar(keys %experiment_supras);
my %exps_total;
open SUPRADISTANCES ,">../../data/Trap/supra_distances.txt";
foreach my $exp (keys %experiment_supras){
	my @supras = @{$experiment_supras{$exp}};
	$exps_total{$exp} = scalar(@supras);
	foreach my $supra (@supras){
		my $dist = $ncbi_placement{$supra};
		print SUPRADISTANCES "$exp\t$supra\t$dist\n";
		if(exists($exp_distances{$exp}{$dist})){
			$exp_distances{$exp}{$dist} = $exp_distances{$exp}{$dist} + scalar(@{$supra_lookup{$supra}});
			$exp_s_distances{$exp}{$dist} = $exp_s_distances{$exp}{$dist} +1;
		}else{
			$exp_distances{$exp}{$dist} = scalar(@{$supra_lookup{$supra}});
			$exp_s_distances{$exp}{$dist} = 1;
		}
		if(exists($dist_totals{$dist})){
			$dist_totals{$dist} = $dist_totals{$dist} + scalar(@{$supra_lookup{$supra}});
			$s_dist_totals{$dist} = $s_dist_totals{$dist} +1;
		}else{
			$dist_totals{$dist} = scalar(@{$supra_lookup{$supra}});
			$s_dist_totals{$dist} = 1;
		}
	}
}


my $explookup = experiment_name_lookup($source);
my %exp_lookup = %{$explookup};
open EDIST,">../../data/Trap/exparch_distances.txt";
open EPDIST,">../../data/Trap/expprot_distances.txt";
open MEANADIST,">../../data/Trap/exparch_meandistances.txt";
open MEANPDIST,">../../data/Trap/expprot_meandistances.txt";
open ARCHPROP,">../../data/Trap/exparch_props.txt";
open DUMP,">../../data/Trap/dump.txt";
print EDIST "samples\t";
print EPDIST "samples\t";
print MEANADIST "samples\t";
print MEANPDIST "samples\t";
print ARCHPROP "samples\t";
foreach my $ncbi (sort { $ncbi_distances{$a} <=> $ncbi_distances{$b}}keys %ncbi_distances){
	print EDIST "$ncbi($ncbi_distances{$ncbi})\t";
	print EPDIST "$ncbi($ncbi_distances{$ncbi})\t";
	print MEANADIST "$ncbi($ncbi_distances{$ncbi})\t";
	print MEANPDIST "$ncbi($ncbi_distances{$ncbi})\t";
	print ARCHPROP "$ncbi($ncbi_distances{$ncbi})\t";
}
print EDIST "\n";
print EPDIST "\n";
print MEANADIST "\n";
print MEANPDIST "\n";
print ARCHPROP "\n";
my %exp_props;
my %props;
	foreach my $exp (keys %exp_distances){
		print EDIST "$exp_lookup{$exp}\t";
		print EPDIST "$exp_lookup{$exp}\t";
		print MEANADIST "$exp_lookup{$exp}\t";
		print MEANPDIST "$exp_lookup{$exp}\t";
		print ARCHPROP "$exp_lookup{$exp}\t";
		foreach my $dist (sort { $ncbi_distances{$a} <=> $ncbi_distances{$b} } keys %ncbi_distances){
			my $amean = $s_dist_totals{$dist}/$exps;
			my $pmean = $dist_totals{$dist}/$exps;
			
			if(exists($exp_distances{$exp}{$dist})){
				print EDIST "$exp_s_distances{$exp}{$dist}\t";
				print EPDIST "$exp_distances{$exp}{$dist}\t";
				my $adev = $exp_s_distances{$exp}{$dist} - $amean;
				my $pdev = $exp_distances{$exp}{$dist} - $pmean;
				my $aprop = $exp_s_distances{$exp}{$dist}/$exps_total{$exp};
				$exp_props{$exp}{$dist} = $aprop;
				if(exists($props{$dist})){
					$props{$dist} = $props{$dist} + $aprop;
				}else{
					$props{$dist} = $aprop;
				}
				print MEANADIST "$adev\t";
				print MEANPDIST "$pdev\t";
				print ARCHPROP "$aprop\t";
			}else{
				print EDIST "0\t";
				print EPDIST "0\t";
				print MEANADIST "0\t";
				print MEANPDIST "0\t";
				print ARCHPROP "0\t";
			}
		}
		print EDIST "\n";
		print EPDIST "\n";
		print MEANADIST "\n";
		print MEANPDIST "\n";
		print ARCHPROP "\n";
	}

open MEANPROP,">../../data/Trap/exparch_meanprops.txt";
print MEANPROP "samples\t";

foreach my $ncbi (sort { $ncbi_distances{$a} <=> $ncbi_distances{$b}}keys %ncbi_distances){
	print MEANPROP "$ncbi($ncbi_distances{$ncbi})\t";
	

}
print MEANPROP "\n";
	
	
	
foreach my $exp (keys %exp_props){
	print MEANPROP "$exp_lookup{$exp}\t";
	foreach my $dist (sort { $ncbi_distances{$a} <=> $ncbi_distances{$b}} keys  %ncbi_distances){
		if(exists($exp_props{$exp}{$dist})){
			my $pmean = $props{$dist}/$exps;
			my $pdev = $exp_props{$exp}{$dist} - $pmean;
			print MEANPROP "$pdev\t";
			print DUMP "$exp\t$ncbi_distances{$dist}\t$pdev\t$dist\t$root_genome\n"
		}else{
			print MEANPROP "0\t";
			print DUMP "$exp\t$ncbi_distances{$dist}\t0\t$dist\t$root_genome\n"
		}
	}
	print MEANPROP "\n";
}

=pod

=back

=head1 TODO

=over 4

=item Edit this file removing all the default skeleton.pl comments!

=back

=cut

1;

__END__
