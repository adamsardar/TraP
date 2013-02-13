#!/usr/bin/env perl

package TraP::SQL::TissueMRCA;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = (
'all' => [ qw(
		experiment_name_lookup
		calculate_NCBI_taxa_range_distances
        human_cell_type_experiments
		experiment_sfs
		experiment_supras
		sf_genomes
		supra_genomes
		all_sfs
		all_supras
		calculate_MRCA_NCBI_placement
		taxon_histogram
		calculateMRCAstats
		experiment_protein_genedistance
		all_protein_genedistance
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
calculate_NCBI_taxa_range_distances
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
	my $source = shift;
	my @ids = ();
	my $dbh = dbConnect('trap');
	my $sth = $dbh->prepare('select experiment_id from experiment where source_id = ?');
	$sth->execute($source);
	
	my $results=[];	
	while(my ($exp_id)=  $sth->fetchrow_array()){
		push(@$results,$exp_id)
	}

	dbDisconnect($dbh);	
	return $results;
}

=item * sf_genomes
Function to find all the genomes a superfamily occurs in given an array ref of a list of superfamily ids (not supra_ids). Returns a hash of $HAsh->{SFid}=[list of genomes]
=cut
sub sf_genomes {
    
    my ($ListOfSuperfamilies) = @_;
    my %sf_genomes;
    foreach my $sf (@$ListOfSuperfamilies){
    	
 	   my $dbh = dbConnect('superfamily');
    	my $sth = $dbh->prepare("SELECT distinct len_supra.genome FROM genome,len_supra,comb_index WHERE comb_index.length = 1 AND comb_index.comb = ? AND comb_index.id=len_supra.supra_id 
    	AND genome.genome=len_supra.genome AND genome.include= 'y';");

 	   $sth->execute($sf);
    
    	while ( my ($genome) = $sth->fetchrow_array() ) {
    		push (@{$sf_genomes{$sf}},$genome);
    	}
    }

	return \%sf_genomes;

}

=item * supra_genomes
Function to find all the genomes a supradomain occurs in given an array ref of a list of supra ids. Returns a hash of $HAsh->{SFid}=[list of genomes]
=cut
sub supra_genomes {
    
    my ($ListOfSupraIDs) = @_;
    my %supra_genomes;
    foreach my $supra (@$ListOfSupraIDs){
    	
 	   my $dbh = dbConnect('superfamily');
    	my $sth = $dbh->prepare("SELECT DISTINCT(len_supra.genome) 
    							FROM len_supra,genome 
    							WHERE genome.genome = len_supra.genome 
    							AND len_supra.supra_id = ? 
    							AND genome.include = 'y';");

 	   $sth->execute($supra);
    
    	while ( my ($genome) = $sth->fetchrow_array() ) {
    		push (@{$supra_genomes{$supra}},$genome);
    	}
    }

	return \%supra_genomes;

}

=item * taxon_histogram
takes a list of genomes and prints a histogram of their distributions at a specified level of the ncbi taxonomy
=cut
sub taxon_histogram {
    my $depth = shift;
    my ($genomes) = shift;
    my $query;
    if(defined($genomes)){
    	$query = 'select taxonomy from genome';
    	my $genome_list = join(',',@{$genomes});
    	$query = $query."where genome in ($genome_list);"
    }else{
    	$query = 'select taxonomy from genome where include =\'y\'';
    }
    my %taxon_distributions;
    my $dbh = dbConnect('superfamily');
    my $sth = $dbh->prepare("$query");    
    $sth->execute();
    while ( my ($taxons) = $sth->fetchrow_array() ) {
    	my @taxons = split(/;/,$taxons);
    	if(exists($taxon_distributions{$taxons[$depth]})){
    		$taxon_distributions{$taxons[$depth]} = $taxon_distributions{$taxons[$depth]} + 1;
    	}else{
    		$taxon_distributions{$taxons[$depth]} = 1;
    	}
    }
    my $string = '';
    foreach(sort {$taxon_distributions{$a} <=> $taxon_distributions{$b}} keys %taxon_distributions){
    	$string .= "$_\t$taxon_distributions{$_}\n";
    }
    
return $string;
}

=item * experiment_sfs
For a given sampleID this returns an array of disitinct sfs that are expressed in that experiment
=cut
sub experiment_sfs {

my $sample = shift;
my @sfs;
my ($dbh, $sth);
$dbh = dbConnect();

$sth =   $dbh->prepare( "select distinct(superfamily.ass.sf) from trap.cell_snapshot, trap.id_mapping, superfamily.ass where trap.cell_snapshot.gene_id = trap.id_mapping.entrez 
and trap.id_mapping.protein = superfamily.ass.protein and trap.cell_snapshot.experiment_id = '$sample';" );
        	$sth->execute;
        	while (my ($sf) = $sth->fetchrow_array ) {
				push @sfs, $sf;
        	}
dbDisconnect($dbh);
return \@sfs;
}


=item * experiment_supras
For a given sampleID this returns an array of disitinct supraIDs where protein|_ascomb > 0 that are expressed in that experiment

At current, the supraIDs returned are those found in homosapien 'hs'
=cut
sub experiment_supras {

my $sample = shift;
my $root_genome = shift;
my @supras;
my ($dbh, $sth);
print "connected\n";
$dbh = dbConnect();

$sth =   $dbh->prepare( "SELECT DISTINCT(len_supra.supra_id) 
						FROM genome,comb,len_supra,
							(select distinct(protein) as p 
							from trap.cell_snapshot, trap.id_mapping 
							where trap.cell_snapshot.gene_id = trap.id_mapping.entrez 
							and trap.cell_snapshot.experiment_id = $sample 
							and trap.cell_snapshot.raw_expression > 10) AS a 
						WHERE comb.protein=a.p 
						AND len_supra.ascomb_prot_number > 0 
						AND comb.comb_id=len_supra.supra_id 
						AND len_supra.genome = ?
 						AND len_supra.genome = genome.genome 
 						AND genome.include = 'y';" );
        	$sth->execute($root_genome);
        	while (my ($supra) = $sth->fetchrow_array ) {
				push @supras, $supra;
        	}
        	print "run\n";
        	
dbDisconnect($dbh);
return \@supras;
}

=item * experiment_protein_genedistance
For a given experiment this returns an hash of protein ids limked to their average gene distance according to mogrify.
=cut
sub experiment_protein_genedistance {

my $sample = shift;
my $cutoff = shift;
my %gene_distances;
my ($dbh, $sth);
$dbh = dbConnect();
$sth =   $dbh->prepare( "SELECT DISTINCT(protein) AS p, MAX(trap.cell_snapshot.`mogrify_gene_distance`) 
						FROM trap.cell_snapshot, trap.id_mapping 
						WHERE trap.cell_snapshot.gene_id = trap.id_mapping.entrez 
						AND trap.cell_snapshot.`mogrify_gene_distance` > $cutoff 
						AND trap.cell_snapshot.experiment_id = $sample 
						GROUP BY p;" );
        	$sth->execute;
        	while (my ($protein,$gene_distance) = $sth->fetchrow_array ) {
        		if($gene_distance >= $cutoff){
				$gene_distances{$protein} = $gene_distance;
        		}
        	}
dbDisconnect($dbh);
return \%gene_distances;
}
=item * experiment_name_lookup
This returns a hash lookup of exp Id to exp name
=cut
sub experiment_name_lookup {
my $source = shift;
my %lookup;
my ($dbh, $sth);
$dbh = dbConnect();
$sth =   $dbh->prepare( "select trap.experiment.experiment_id,trap.experiment.sample_name from trap.experiment where trap.experiment.source_id = ?;" );
        	$sth->execute($source);
        	while (my ($id,$name) = $sth->fetchrow_array ) {
        		$lookup{$id}=$name
        	}
dbDisconnect($dbh);
return \%lookup;
}
=item * all_protein_genedistance
For a given source this returns an hash of protein ids limked to their average gene distance according to mogrify.
=cut
sub all_protein_genedistance {

my $source = shift;
my $cutoff = shift;
my %gene_distances;
my ($dbh, $sth);
$dbh = dbConnect();
$sth =   $dbh->prepare( "select distinct(protein) as p, max(trap.cell_snapshot.`mogrify_gene_distance`) from trap.cell_snapshot, 
trap.id_mapping where trap.cell_snapshot.gene_id = trap.id_mapping.entrez and trap.cell_snapshot.`mogrify_gene_distance` > $cutoff group by p;" );
        	$sth->execute;
        	while (my ($protein,$gene_distance) = $sth->fetchrow_array ) {
        		if($gene_distance >= $cutoff){
        			if(exists($gene_distances{$protein})){
        			unless($gene_distances{$protein}>$gene_distance){
						$gene_distances{$protein} = $gene_distance;
        			}
        			}else{
        				$gene_distances{$protein} = $gene_distance;
        			}
        		}
        	}
dbDisconnect($dbh);
return \%gene_distances;
}


=item * all_sfs
For a given source_id this returns an array of distinct sfs that are expressed in any experiment in that source
=cut
sub all_sfs {

my $source = shift;
my @sfs;
my ($dbh, $sth);
$dbh = dbConnect();

$sth =   $dbh->prepare( "select distinct(superfamily.ass.sf) from trap.cell_snapshot, trap.id_mapping, superfamily.ass,trap.experiment 
where trap.cell_snapshot.gene_id = trap.id_mapping.entrez and trap.id_mapping.protein = superfamily.ass.protein and 
trap.experiment.experiment_id = trap.cell_snapshot.experiment_id and trap.experiment.source_id = $source;");
        	$sth->execute;
        	while (my ($sf) = $sth->fetchrow_array ) {
				push @sfs, $sf;
        	}
dbDisconnect($dbh);
return \@sfs;
}

=item * all_supras
For a given source_id this returns an array of distinct supras that are expressed in any experiment in that source

At current, the supraIDs returned are those found in homosapien 'hs'
=cut
sub all_supras {

my $source = shift;
my $root_genome = shift;
my @supras;
my ($dbh, $sth);
my %supras;
my %prot_lookup;
my %supra_lookup;
$dbh = dbConnect();

$sth =   $dbh->prepare( "SELECT DISTINCT(len_supra.supra_id),p 
						FROM genome,comb,len_supra,
							(select distinct(protein) as p from 
							trap.cell_snapshot, trap.id_mapping,trap.experiment where trap.cell_snapshot.gene_id = trap.id_mapping.entrez 
							and trap.experiment.experiment_id = trap.cell_snapshot.experiment_id and trap.experiment.source_id = $source) AS a 
						WHERE comb.protein=a.p 
						AND len_supra.ascomb_prot_number > 0 
						AND comb.comb_id=len_supra.supra_id 
						AND genome.genome = ? 
						AND len_supra.genome = genome.genome
 						AND genome.include = 'y';");
        	$sth->execute($root_genome);
        	while (my ($supra,$protein) = $sth->fetchrow_array ) {
				$supras{$supra} =1;
				$prot_lookup{$protein} = $supra;
				push(@{$supra_lookup{$supra}},$protein);
        	}
 @supras = keys %supras;
dbDisconnect($dbh);
return (\@supras,\%prot_lookup,\%supra_lookup);
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
	
	$sth = $dbh->prepare("SELECT tree.left_id, tree.right_id, tree.taxon_id FROM tree WHERE tree.left_id = (SELECT MAX(tree.left_id) FROM tree WHERE tree.left_id <= ? AND tree.right_id >= ?);");
	
	my $MaxLeftID = List::Util::min(@$Genome_left_ids);
	my $MinRightID = List::Util::max(@$Genome_right_ids);
	
	$sth->execute($MaxLeftID,$MinRightID);
	my $Nrows = $sth->rows;
			
	if($Nrows > 1){
				
		die "Error in SQL whilst finding MRCA of left_id $MaxLeftID right_id $MinRightID using superfamily.tree. More than one MRCA! Something is very wrong !\n";
		
	}elsif($Nrows == -1){
				
		die "Query appears to have failed on left_id $MaxLeftID and right_id $MinRightID!\n";
	}
					
	my ($MRCAleftid,$MRCArightid,$taxonID) = $sth->fetchrow_array;
	
	$sth->finish;
	
	my ($DistanceFromReference,$NCBIPlacement); #This is the distance on the tree (in aggregated branch lengths) from MRCA
	
	unless($ReferenceDistanceGenome ~~ undef){
		#i.e. if a reference distance genome was provided
		
		$sth = $dbh->prepare("SELECT SUM(edge_length) FROM tree WHERE left_id <= ? AND left_id > ? AND right_id >= ? AND right_id < ?;");
		
		if($MRCAleftid <=  $RefernceGenomeLeftID && $MRCArightid >= $ReferenceGenomeRightID){
			#i.e. if the reference genome is a direct descendent of the MRCA
			
			$sth->execute($RefernceGenomeLeftID,$MRCAleftid,$ReferenceGenomeRightID,$MRCArightid);
			
			($DistanceFromReference) = $sth->fetchrow_array;
			
			$DistanceFromReference = 0 if($DistanceFromReference ~~ undef);
			
			$sth->finish;
			
		}else{
			
			die "Calculating the distance between a leaf genome and a node that isn't even its ancestor makes little to no sense at all!\n";
			#Check that what we're doing is sensible
		}
		
		unless($taxonID ~~ undef){
			
			$sth = $dbh->prepare("SELECT ncbi_taxonomy_lite.name,ncbi_taxonomy_lite.taxon_id FROM ncbi_taxonomy_lite  WHERE  ncbi_taxonomy_lite.taxon_id = ?;");
			$sth->execute($taxonID);
		}else{
			
			$sth = $dbh->prepare("SELECT ncbi_taxonomy_lite.name,tree.taxon_id FROM ncbi_taxonomy_lite JOIN tree ON tree.taxon_id = ncbi_taxonomy_lite.taxon_id 
			WHERE tree.left_id IN (SELECT MAX(left_id) FROM tree WHERE left_id < ? AND right_id > ? AND taxon_id IS NOT NULL);");
			
			$sth->execute($MRCAleftid,$MRCArightid);
		}
		
		($NCBIPlacement,$taxonID) = $sth->fetchrow_array;
			
		$sth->finish;
		
	}	
	
	dbDisconnect($dbh);
	
	return ($DistanceFromReference,$NCBIPlacement,$taxonID);
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
	
	my $Supra2TreeDistData = {};
	my $Supra2TreePlacemenetData = {};
	#Structure will be $Supra2TreeDistData->{$supra_id}=[$MRCAtaxon_id,$MRCA_NCBI_Taxonomy_Name,$MRCA_NCBI_Taxonomy_Rank,$DistanceFromReference]

	foreach my $Trait (keys(%$Trait2GenomesHash)){
		
		my @TraitGenomes = @{$Trait2GenomesHash->{$Trait}}; #List of genomes possesing trait, as passed into function
		
		print STDERR "Reference Distance genome $ReferenceDistanceGenomes not in list of genomes passed in for Trait $Trait\n" unless(grep{$_ =~ /$ReferenceDistanceGenomes/}@TraitGenomes);
		
		my ($DistanceFromReference,$NCBIPlacement,$Taxon_Id) = calculate_MRCA_NCBI_placement(\@TraitGenomes,$ReferenceDistanceGenomes);
		$Supra2TreeDistData->{$Trait}=$DistanceFromReference;
		$Supra2TreePlacemenetData->{$Trait}=[$NCBIPlacement,$Taxon_Id];
		
	}
	
	return ($Supra2TreeDistData,$Supra2TreePlacemenetData);
}

sub calculate_NCBI_taxa_range_distances($$){
	
	my ($NCBIRanges,$ReferenceDistanceGenome) = @_;
	#$NCBIRanges = [list of NCBI 'names']
	
	$ReferenceDistanceGenome = 'hs' if($ReferenceDistanceGenome ~~ undef); #Set a default of homo sampien
	
	my $dbh = dbConnect('superfamily');
	my $sth = $dbh->prepare("SELECT left_id,right_id FROM tree WHERE nodename = ?;");
	$sth->execute($ReferenceDistanceGenome);
	my $Nrows = $sth->rows;
	die "Reference genome $ReferenceDistanceGenome not found in SUPERFAMILY\n" if($Nrows < 1);
	my ($RefernceGenomeLeftID,$ReferenceGenomeRightID) = $sth->fetchrow_array();
	$sth->finish;
		
	my $NCBITaxonRange2DistanceFromReference = {};
	
	$sth = $dbh->prepare("SELECT SUM(edge_length) FROM tree 
	WHERE left_id <= ?
	AND left_id > (SELECT tree.left_id FROM tree JOIN ncbi_taxonomy_lite ON tree.taxon_id = ncbi_taxonomy_lite.taxon_id WHERE ncbi_taxonomy_lite.name = ?)
	AND right_id >= ?
	AND right_id < (SELECT tree.right_id FROM tree JOIN ncbi_taxonomy_lite ON tree.taxon_id = ncbi_taxonomy_lite.taxon_id WHERE ncbi_taxonomy_lite.name = ?);");
		
	foreach my $NCBITaxonRange (@$NCBIRanges){
	
		$sth->execute($RefernceGenomeLeftID,$NCBITaxonRange,$ReferenceGenomeRightID,$NCBITaxonRange);
		my ($DistanceFromReference) = $sth->fetchrow_array;
		$DistanceFromReference = 0 if($DistanceFromReference ~~ undef);
		$NCBITaxonRange2DistanceFromReference->{$NCBITaxonRange}=$DistanceFromReference;
		$sth->finish;
	}
	
	return($NCBITaxonRange2DistanceFromReference);	
}




1;
__END__

