#!/usr/bin/env perl

package TraP::SQL::TissueMRCA;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = (
'all' => [ qw(
        human_cell_type_experiments
		experiment_sfs
		sf_genomes
		all_sfs
		calculate_MRCA_NCBI_placement
		calculateMRCAstats
) ],
);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

our $VERSION   = 1.00;

use strict;
use warnings;

=head1 NAME

TraP::Skeleton v1.0 - Skeleton module for the TraP project

=head1 DESCRIPTION

This module has been released as part of the TraP Project code base.

Just a skeleton layout for each module to start from.

=head1 EXAMPLES

use TraP::Skeleton qw/all/;

=head1 AUTHOR

DELETE AS APPROPRIATE!

B<Matt Oates> - I<Matt.Oates@bristol.ac.uk>

B<Owen Rackham> - I<Owen.Rackham@bristol.ac.uk>

B<Adam Sardar> - I<Adam.Sardar@bristol.ac.uk>

=head1 NOTICE

DELETE AS APPROPRIATE!

B<Matt Oates> (2011) First features added.

B<Owen Rackham> (2011) First features added.

B<Adam Sardar> (2011) First features added.

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

=head1 DEPENDANCY

B<Data::Dumper> Used for debug output.

=cut

use lib qw'../../';
use Utils::SQL::Connect qw/:all/;
use Supfam::Utils qw(:all);
use Data::Dumper; #Allow easy print dumps of datastructures for debugging


=head1 FUNCTIONS DEFINED

=over 4
=cut

=item * human_cell_type_experiments
Function to get all the human cell type experiment ids
=cut
sub human_cell_type_experiments {
	my @ids = ();
	my $dbh = dbConnect('trap');
	my $sth = $dbh->prepare('select experiment_id from experiment where source_id = ? limit 1');
	$sth->execute(1);
	my $results = $sth->fetchall_arrayref();
	dbDisconnect($dbh);
	return $results->[0];
}

=item * sf_genomes
Function to find all the genomes a superfamily occurs in given an array ref of a list of superfamily ids (not supra_ids). Returns a hash of $HAsh->{SFid}=[list of genomes]
=cut
sub sf_genomes {
    
    my ($ListOfSuperfamilies) = @_;
    my %sf_genomes;
    foreach my $sf (@$ListOfSuperfamilies){
    	
 	   my $dbh = dbConnect('superfamily');
    	my $sth = $dbh->prepare("SELECT distinct len_supra.genome FROM genome,len_supra,comb_index WHERE comb_index.length = 1 AND comb_index.comb = ? AND comb_index.id=len_supra.supra_id AND genome.genome=len_supra.genome AND genome.include='y';");

 	   $sth->execute($sf);
    
    	while ( my ($genome) = $sth->fetchrow_array() ) {
    		push (@{$sf_genomes{$sf}},$genome);
    	}
    }

	return \%sf_genomes;

}

=item * experiment_sfs
For a given sampleID this returns an array of disitinct sfs that are expressed in that experiment
=cut
sub experiment_sfs {

my $sample = shift;
my @sfs;
my ($dbh, $sth);
$dbh = dbConnect();

$sth =   $dbh->prepare( "select distinct(superfamily.ass.sf) from trap.cell_snapshot, trap.id_mapping, superfamily.ass where trap.cell_snapshot.gene_id = trap.id_mapping.entrez and trap.id_mapping.protein = superfamily.ass.protein and trap.cell_snapshot.experiment_id = '$sample';" );
        	$sth->execute;
        	while (my ($sf) = $sth->fetchrow_array ) {
				push @sfs, $sf;
        	}
dbDisconnect($dbh);
return \@sfs;
}


=item * all_sfs
For a given source_id this returns an array of distinct sfs that are expressed in any experiment in that source
=cut
sub all_sfs {

my $source = shift;
my @sfs;
my ($dbh, $sth);
$dbh = dbConnect();

$sth =   $dbh->prepare( "select distinct(superfamily.ass.sf) from trap.cell_snapshot, trap.id_mapping, superfamily.ass,trap.experiment where trap.cell_snapshot.gene_id = trap.id_mapping.entrez and trap.id_mapping.protein = superfamily.ass.protein and trap.experiment.experiment_id = trap.cell_snapshot.experiment_id and trap.experiment.source_id = $source;");
        	$sth->execute;
        	while (my ($sf) = $sth->fetchrow_array ) {
				push @sfs, $sf;
        	}
dbDisconnect($dbh);
return \@sfs;
}


=item * calculate_MRCA_NCBI_placement(\@list_of_genomes)

Given a list of superfamily genome codes, this function will get their MRCA in NCBI taxonomy. Returns 
its taxon_id, full name and rank in NCBI taxonomy. If $ReferenceDistanceGenome is provided, then the 
distance between $ReferenceDistanceGenome and the calculated MRCA will be returned else undef will be returned in its place.

=cut
sub calculate_MRCA_NCBI_placement{

    my ($GenomeList,$ReferenceDistanceGenome) = @_;
    # $GenomeList = [genomes], reference distance genome is the genome from which to calculate the distance to MRCA
    
	#Given a lsit of Genomes, calculate their MRCA in the NCBI taxonomy. 
	
	die "Need to pass in a list of genomes as input!\n" unless(scalar(@$GenomeList));

	my $dbh = dbConnect('superfamily');
	
	#Convert to left and right ids for each genome
		
	my $Genome_left_ids = []; #All the left_ids of genomes
	my $Genome_right_ids = []; #All the right_ids of genomes
		
	my $sth = $dbh->prepare("SELECT left_id,right_id FROM tree WHERE nodename = ?;");
	
	my ($RefernceGenomeLeftID,$ReferenceGenomeRightID);
	
	unless($ReferenceDistanceGenome ~~ undef){
		
		$sth->execute($ReferenceDistanceGenome);
		my $Nrows = $sth->rows;
		die "Reference genome $ReferenceDistanceGenome not found in SUPERFAMILY\n" if($Nrows < 1);
		($RefernceGenomeLeftID,$ReferenceGenomeRightID) = $sth->fetchrow_array();
		$sth->finish;
	}
	#If a refernce genome to calculate distances to was given, then grab the left and right ids 

	foreach my $genome (@$GenomeList){
			
			$sth->execute($genome);
			my $Nrows = $sth->rows;
			
			unless($Nrows){
				
				print STDERR "Genome $genome not found in SUPERFAMILY tree table, skipping this one\n";
				next;
				
			}elsif($Nrows > 1){
				
				die "More than one genome entry for genome $genome in superfamily.tree. Something is very wrong !\n";
				
			}elsif($Nrows == -1){
				
				die "Query appears to have failed on genome $genome!\n";
			}
			
			
			my ($left_id,$right_id) = $sth->fetchrow_array();
			push(@$Genome_left_ids,$left_id);
			push(@$Genome_right_ids,$right_id);
			
			$sth->finish;
	}
	
	die "None of the genomes provided were found in the superfamily tree table\n" unless(scalar(@$Genome_left_ids));
	
	#Calculate MRCA for each set of genomes per superfamily
	my $SF2MRCAHash = {};
	my $TaxonID2leftrightidDictionary = {};
	
	$sth = $dbh->prepare("SELECT ncbi_taxonomy.taxon_id, ncbi_taxonomy.name,ncbi_taxonomy.rank, tree.left_id, tree.right_id FROM tree JOIN ncbi_taxonomy ON ncbi_taxonomy.taxon_id = tree.taxon_id WHERE tree.left_id = (SELECT MAX(tree.left_id) FROM tree WHERE tree.left_id <= ? AND tree.right_id >= ?);");
	
	my $MaxLeftID = List::Util::min(@$Genome_left_ids);
	my $MinRightID = List::Util::max(@$Genome_right_ids);
	
	$sth->execute($MaxLeftID,$MinRightID);
	my $Nrows = $sth->rows;
			
	if($Nrows > 1){
				
		die "Error in SQL whilst finding MRCA of left_id $MaxLeftID right_id $MinRightID using superfamily.tree. More than one MRCA! Something is very wrong !\n";
		
	}elsif($Nrows == -1){
				
		die "Query appears to have failed on left_id $MaxLeftID and right_id $MinRightID!\n";
	}
					
	my ($taxon_id,$name,$rank,$MRCAleftid,$MRCArightid) = $sth->fetchrow_array;
	
	$sth->finish;
	
	my $DistanceFromReference; #This is the distance on the tree (in aggregated branch lengths) from MRCA
	
	unless($ReferenceDistanceGenome ~~ undef){
		#i.e. if a reference distance genome was provided
		
		$sth = $dbh->prepare("SELECT SUM(edge_length) FROM tree WHERE left_id <= ? AND left_id > ? AND right_id >= ? AND right_id < ?;");
		
		if($MRCAleftid <=  $RefernceGenomeLeftID && $MRCArightid >= $ReferenceGenomeRightID){
			#i.e. if the reference genome is a direct descendent of the MRCA
			
			$sth->execute($RefernceGenomeLeftID,$MRCAleftid,$ReferenceGenomeRightID,$MRCArightid);
			
			($DistanceFromReference) = $sth->fetchrow_array;
			
			$sth->finish;
			
		}else{
			
			die "Calculating the distance between a leaf genome and a node that isn't even its ancestor makes little to no sense at all!\n";
			#Check that what we're doing is sensible
		}
		
	}	
	
	dbDisconnect($dbh);
	
	return ($taxon_id,$name,$rank,$DistanceFromReference);
}

=item * calculateMRCAstats
Function to take a list of traits (supra_ids, so superfamilies, domain architectures whatever ...) and 
calculates a whole load of information regarding their MRCA.

Expected input: A hash of form $Hash->{trait}=[list if genomes trait belongs in] and a reference genome (optional)

Output: A hash of structure $Hash->{trait}=[MRCAtaxon_id,MRCA_NCBI_Taxonomy_Name,MRCA_NCBI_Taxonomy_Rank,TotalDistanceFromMRCAtoReference]

=cut

sub calculateMRCAstats {
	
	my ($Trait2GenomesHash,$ReferenceDistanceGenomes) = @_;
	#$Trait2GenomesHash->{trait}=[genomes in which it is present]
	
	$ReferenceDistanceGenomes = 'hs' if($ReferenceDistanceGenomes ~~ undef); #Set a default of homo sampien
	
	my $Supra2TreeData = {};
	#Structure will be $Supra2TreeData->{$supra_id}=[$MRCAtaxon_id,$MRCA_NCBI_Taxonomy_Name,$MRCA_NCBI_Taxonomy_Rank,$DistanceFromReference]

	foreach my $Trait (keys(%$Trait2GenomesHash)){
		
		my @TraitGenomes = @{$Trait2GenomesHash->{$Trait}}; #List of genomes possesing trait, as passed into function
		
		print STDERR "Reference Distance genome $ReferenceDistanceGenomes not in list of genomes passed in for Trait $Trait\n" unless(grep{$_ =~ /$ReferenceDistanceGenomes/}@TraitGenomes);
		
		my ($taxon_id,$name,$rank,$DistanceFromReference) = calculate_MRCA_NCBI_placement(\@TraitGenomes,$ReferenceDistanceGenomes);
		$Supra2TreeData->{$Trait}=[$taxon_id,$name,$rank,$DistanceFromReference];
	}
	
	
	return ($Supra2TreeData);
}

1;
__END__

