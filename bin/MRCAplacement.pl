#!/usr/bin/env perl

use strict;
use warnings;

=head1 NAME

MRCAplacement.pl

=head1 SYNOPSIS

MRCAplacement [options] -f file

 Basic Options:
  -h --help Get full man page output
  -v --verbose Verbose output with details of mutations
  -d --debug Debug output

=head1 DESCRIPTION

A quick and dirty script - given a list of comb_ids, calculate their respective MRCAs by looking across all genomes in SUPERFAMILY and, using dollo parsomny, assigning the ncbi taxon id at which they were constructed. 
This information is dumped toan SQL readable file.

=back

=head1 EXAMPLES

To get some help output do:



=head1 AUTHOR

B<Owen Rackham> - I<Owen.Rackham@bristol.ac.uk>

B<Adam Sardar> - I<Adam.Sardar@bristol.ac.uk>

=head1 NOTICE

=item B<Adam Sardar> (2012) First features added.

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
use TraP::SQL::TissueMRCA  qw(:all);

# Command Line Options
#-------------------------------------------------------------------------------
my $verbose; #Flag for verbose output from command line opts
my $debug;   #As above for debug
my $help;    #Same again but this time should we output the POD man page defined after __END__
my $file;

#Set command line flags and parameters.
GetOptions("verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
           "help|h!" => \$help,
           "file|f=s" => \$file,
        ) or die "Fatal Error: Problem parsing command-line ".$!;

#Print out some help if it was asked for or if no arguments were given.
pod2usage(-exitstatus => 0, -verbose => 2) if $help;

# Main Script Content
#-------------------------------------------------------------------------------

my @DomainArchitectures;

open DAS, "<$file" or die $!." ".$?;

while (my $line = <DAS>){
	
	chomp($line);
	push(@DomainArchitectures,$line);
}

close DAS;

my $UniqDAs = {};
map{$UniqDAs->{$_}=undef}@DomainArchitectures;

my @DistinctDAs =keys(%$UniqDAs);

print STDERR scalar(@DistinctDAs)." domain architectures in input file\n";

my $root_genome = 'hs';

my $comb_genomes = supra_genomes(\@DistinctDAs);
#$supra_genomes is a  hash of stucture $HAsh->{comb_id}=[list of genome codes]

my (undef,$Comb2TreePlacemenetData) = calculateMRCAstats($comb_genomes,$root_genome);
#Two hashes. First is of structure $Comb2TreePlacemenetData->{comb_id}=[$MRCAtaxon_id,$MRCA_NCBI_Taxonomy_Name,$MRCA_NCBI_Taxonomy_Rank,$DistanceFromReference]

open SQLDUMP, ">MRCAplacements.dat" or die $!." ".$?;

foreach my $comb_id (@DistinctDAs){
	
	my $MRCA_taxon_id = $Comb2TreePlacemenetData->{$comb_id}[1];
	$MRCA_taxon_id = 'NULL' if($MRCA_taxon_id ~~ undef);
	
	my $MRCA_taxon_name = $Comb2TreePlacemenetData->{$comb_id}[0];
	$MRCA_taxon_name = 'NULL' if($MRCA_taxon_name ~~ undef);
	
	print SQLDUMP $comb_id."\t".$MRCA_taxon_id."\t".$MRCA_taxon_name."\n";
}

close SQLDUMP;


__END__

