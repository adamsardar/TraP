#! /usr/bin/env perl

=head1 NAME

celltype2TraitMatrix<.pl>

=head1 USAGE

  celltype2TraitMatrix.pl [options -v,-d,-h] -l --list <tab seperated list of experiment ids wanted> -o --output <outputfile name>
  
=head1 SYNOPSIS

A script to generate a carachter trait matrix file of domain architecture combinations copatible RAxML format from a specified list of TraP experiment ids.

=head1 AUTHOR

B<Adam Sardar> - I<adam.sardar@bristol.ac.uk>

=head1 COPYRIGHT

Copyright 2012 Gough Group, University of Bristol.

=cut

# Strict Pragmas
#----------------------------------------------------------------------------------------------------------------
use strict;
use warnings;

# Add Local Library to LibPath
#----------------------------------------------------------------------------------------------------------------
use lib "../lib";

#CPAN Includes
#----------------------------------------------------------------------------------------------------------------
=head1 DEPENDANCY
B<Getopt::Long> Used to parse command line options.
B<Pod::Usage> Used for usage and help output.
B<Data::Dumper> Used for debug output.
=cut
use Getopt::Long;                     #Deal with command line options
use Pod::Usage;                       #Print a usage man page from the POD comments after __END__
use Data::Dumper;                     #Allow easy print dumps of datastructures for debugging
#use XML::Simple qw(:strict);          #Load a config file from the local directory
use DBI;

use Utils::SQL::Connect qw/:all/;

# Command Line Options
#----------------------------------------------------------------------------------------------------------------

my $verbose; #Flag for verbose output from command line opts
my $debug;   #As above for debug
my $help;    #Same again but this time should we output the POD man page defined after __END__
my $ExperimentIDsFile;
my $GenomeListFile;
my $genome_archs_file;
my $outputfile = 'output';


# Sub definitions

#----------------------------------------------------------------------------------------------------------------
sub RAxMLOutput($$){

	my ($TraitHash,$outputfile) = @_;
	
	my @ExperimentIDs = keys(%$TraitHash);
	my $NoExperiments = scalar(@ExperimentIDs); 
	my $LineLength = length($TraitHash->{$ExperimentIDs[0]});
	
	open OUT, ">$outputfile" or die $?;
		
	print OUT "$NoExperiments\t$LineLength\n";
	
	foreach my $ExpID (@ExperimentIDs){

		print OUT $ExpID."      "; #Phylip format is quite particular in the way it seperate tax names and state details.
		my $TraitString = $TraitHash->{$ExpID};
		print OUT $TraitString;
		print OUT "\n";
	}
	close OUT;
}

sub generateDomArchTraits($){
	
	my (@ExperimentIDs);
	@ExperimentIDs = @{$_[0]};
	
	my $NoExperiments = scalar(@ExperimentIDs);
	
	#Create a hash of all the trait vectors per taxon
	my $TraitHash = {};
	#$TraitHash -> {taxon => binary traits}
	my $FullSpeciesTraitsHash = {};
	#$TraitHash -> {expID => binary traits}, but crucially, this will still contain sites which are identical throughout the whole sample of taxa
			
	my $experimentidquery = join ("' or  snapshot_order_supra.experiment_id ='", @ExperimentIDs); $experimentidquery = "( snapshot_order_supra.experiment_id ='$experimentidquery')";# An ugly way to make the query run - as there is no way to input a list of items explicitly into SQL, I'm just concatenating a string of truth statements
	
	my $dbh = dbConnect('trap');
	my $sth = $dbh->prepare("SELECT DISTINCT(supra_id) FROM snapshot_order_supra WHERE $experimentidquery;");
	$sth->execute();
	
	my @comb_ids;
	
	while (my $CombID = $sth->fetchrow_array() ) {
		
		push(@comb_ids,$CombID);
	}
	
	my %CombHash;
	
	@CombHash{@comb_ids}=((0)x scalar(@comb_ids));#Preallocate
	
	$sth = $dbh->prepare("SELECT supra_id FROM snapshot_order_supra WHERE snapshot_order_supra.experiment_id = ?;");
	
	my %ModelCombHash = %CombHash;
	
	
	foreach my $taxa (@ExperimentIDs){
		
		my %SpeciesCombsHash = %ModelCombHash; #Create a duplicate of %CombHash
		
		$sth->execute($taxa);
		
		while (my $SpeciesCombID = $sth->fetchrow_array() ) {
		
			$SpeciesCombsHash{$SpeciesCombID}=1; #Per species presence/abscence
			$CombHash{$SpeciesCombID}++; #Global total sightings
		}
			
		my @SpeciesCombs = @SpeciesCombsHash{sort(@comb_ids)}; #Sorted by comb_id -> presences absece matrix 000101 etc
		
		$FullSpeciesTraitsHash->{$taxa}=join(',',@SpeciesCombs);
	}
	
	dbDisconnect($dbh) ; 
	
	#Calculate the informative sites and exclude the others
	my $index=0;
	my @InformativeSites;
	
	foreach my $comb_id (sort(@comb_ids)){
		
		push (@InformativeSites,$index) if($CombHash{$comb_id} != $NoExperiments && $CombHash{$comb_id} != 0);
		$index++;
	}
	
	#Selecting only the informative sites, create the trait strings which shall be outputted to file
	foreach my $taxa (@ExperimentIDs){
		
		my @Traits = split(',',$FullSpeciesTraitsHash->{$taxa}); #Full combs
		my $TraitString = join('',@Traits[@InformativeSites]);
		$TraitHash->{$taxa}=$TraitString;
	}
		
	return($TraitHash);
		
}

#Main Script
#----------------------------------------------------------------------------------------------------------------


#Set command line flags and parameters

GetOptions("verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
           "help|h!" => \$help,
           "list|l=s" => \$ExperimentIDsFile,
           "output|o=s" => \$outputfile,
) or die "Fatal Error: Problem parsing command-line ".$!;

#Print out some help if it was asked for or if no arguments were given.
pod2usage(-exitstatus => 0, -verbose => 2) if $help;

my @ExperimentIDs;

open EXPERIMENTIDS, "<$ExperimentIDsFile" or die $!." - ".$?;
while(<EXPERIMENTIDS>){
	
	chomp($_);
	push(@ExperimentIDs,$_);
}
close EXPERIMENTIDS;

my $dbh = dbConnect('trap');
my $sth = $dbh->prepare("SELECT experiment_id FROM snapshot_order_supra WHERE experiment_id = ?;");

foreach my $ExpID (@ExperimentIDs){
	
	$sth->execute($ExpID);
	die "No entry in snapshot_order_supra table of TraP for $ExpID\n" unless($sth->rows());
	$sth->finish;
}

dbDisconnect($dbh) ; 
#Sanity check to make sure that the experiment ids that you pass in are correct.

#Generate the appropriate set of traits
my $TraitHash = generateDomArchTraits(\@ExperimentIDs);

#Wrtie only the records for species in the tree to file
RAxMLOutput($TraitHash,$outputfile);

__END__

