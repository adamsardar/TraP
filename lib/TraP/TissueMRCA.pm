#!/usr/bin/env perl

package TraP::TissueMRCA;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = (
'all' => [ qw(
			calculate_MRCA
) ],
'yourtag' => [ qw(
			sub1
) ],
);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

our $VERSION   = 1.00;

use strict;
use warnings;

=head1 NAME

TraP::TissueMRCA

=head1 DESCRIPTION

This module has been released as part of the TraP Project code base.

Module for assesing how old the unique/enriched superfamiles within a tissue transcriptome are.

=head1 EXAMPLES

use TraP::TissueMRCA qw/all/;

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

use lib ("../lib");
use Supfam::Utils qw(:all);
use Supfam::SQLFunc qw(:all);

=head1 DEPENDANCY

B<Data::Dumper> Used for debug output.

=cut

use Data::Dumper; #Allow easy print dumps of datastructures for debugging

=head1 FUNCTIONS DEFINED


=item * calculateSupraListMRCA
Function to do something
=cut

#sub calculateSupraListMRCA {
#    
#Commented out, but might compelte, just for the hey.
#    my ($GenomesList) = @_;
#	
#	#Given a lsit of SFs, calculate their MRCA in the NCBI taxonomy. 
#	
#	my $TreeProvided = ($TreeInNewick)?1:0;
#	#TODO Extract Tree from superfamily if no tree given
#	
#	my $dbh = dbConnect('SUPERFAMILY');
#		
#	my ($root,$TreeCacheHash) = BuildTreeCacheHash($TreeInNewick);
#	
#	my $sth = $dbh-> prepare("SELECT DISTINCT(genome) FROM len_supra WHERE supra_id = ?;");
#	
#	my $Supra2GenomeListHash = {};
#	
#	foreach my $SupraID (@$SupraList){
#		
#		$sth->execute($SupraID);
#		my $GenomesWithSupraID = [];
#		
#		while (my $genome = $sth->fetchrow_array){	push(@$GenomesWithSupraID,$genome); } #Populate $GenomesWithSupraID
#	
#		$Supra2GenomeListHash->{$SupraID}=$GenomesWithSupraID;
#		$sth->finish;
#	}
#	
#	#TODO check that there is an overlap between the tree provided and the genomes
#	SUPERFAMILY
#	#Now calculate the MRCA of each list of genomes
#	my $Supra2MRCAHash = {};
#		
#	foreach  my $SupraID (@$SupraList){
#	
#		my $SupraMRCA = FindMRCA($TreeCacheHash,$root,$Supra2GenomeListHash->{$SupraID});
#		$Supra2MRCAHash->{$SupraID}=$SupraMRCA;
#	}
#	
#	my $DistinctMRCAsHash = {};
#	@{$DistinctMRCAsHash}{values(%$Supra2MRCAHash)}=(undef) x scalar(@$SupraList); #Update hash using a hash slice. This a quick way to get all the distinct MRCAs, as well as preallocating for the next step of the script
#	my @DistinctMRCAs = keys(%$DistinctMRCAsHash);
#
#	my $MRMRCA; #A very strange idea, but this is the most recent most recent common ancestor. i.e., of all the MRCAs, which is the last point on the tree
#
#	foreach my $DistinctMRCA (@DistinctMRCAs){
#		
#		my @MRCADescendents = @{$TreeCacheHash->{$DistinctMRCA}{'all_Descendents'}};
#		my ($Union,$Intersection,$ListAExclusive,$ListBExclusive) = IntUnDiff(\@MRCADescendents,\@DistinctMRCAs);
#		
#		my $NumberOfMRCAsAsDescenents = scalar(@$Intersection);
#		
#		$DistinctMRCAsHash->{$DistinctMRCA}=$NumberOfMRCAsAsDescenents;	#Foreach distinct supra_id MRCA, work out the number of times another MRCA in the set appears within it's descendens
#	
#		if($NumberOfMRCAsAsDescenents == 0){ # The MRCA with no others as descendents must be the MRMRCA
#			
#			die "More than one youngest MRCA! This MUST imply a bug SUPERFAMILYwith the script\n" if($MRMRCA);
#			$MRMRCA = $DistinctMRCA;
#		}
#	}
#	
#	my $MRMRCAGenomes = @{$TreeCacheHash->{$MRMRCA}{'Clade_Leaves'}};
#	
#	my $MRMRCACladeLeftIDs = [];
#	my $MRMRCACladeRightIDs = [];
#	
#	$sth = $dbh-> prepare("SELECT left_id,right_id FROM tree WHERE nodename = ?");
#	
#	foreach my $TreeLeaf ($MRMRCAGenomes){
#		
#		$sth->execute($TreeLeaf);
#		
#		while(my($leftid,$rightid) = $sth->fetchrow_array){
#		
#			push(@$MRMRCACladeLeftIDs,$leftid);
#			push(@$MRMRCACladeRightIDs,$rightid);
#		}
#		$sth->finish;
#	}
#	
#	my $MRMRCAmaxleftid =  List::Util::min(@$MRMRCACladeLeftIDs);
#	my $MRMRCAminrightid = List::Util::max(@$MRMRCACladeRightIDs);
#	
#	$sth = $dbh-> prepare("SELECT taxon_id, MAX(left_id) FROM ncbi_taxonomy ON taxon_id WHERE left_id < ? AND right_id > ?;")
#	$sth->execute($MRMRCAmaxleftid,$MRMRCAminrightid);
#	
#	
#	
#	dbDisconnect($dbh);
#	
#	
#	
#	my 	$MRCABranchName;
#		SUPERFAMILY
#	return ($MRCABranchName);
#}

=item * calculate_MRCA(\@list_of_genomes)

Given a list of superfamily genome codes, this function will get their MRCA in NCBI taxonomy. Returns 
its taxon_id, full name and rank in NCBI taxonomy.

=cut

sub calculate_MRCA($) {

    my ($GenomeList) = @_;
    # $GenomeList = [genomes]
	#Given a lsit of Genomes, calculate their MRCA in the NCBI taxonomy. 
	
	die "Need to pass in a list of genomes as input!\n" unless(scalar(@$GenomeList));
	
	my $dbh = dbConnect();
	
	#Convert to left and right ids for each genome
		
	my $Genome_left_ids = []; #All the left_ids of genomes
	my $Genome_right_ids = []; #All the right_ids of genomes
	
	my $sth = $dbh->prepare("SELECT left_id,right_id FROM tree WHERE nodename = ?;");

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
	
	$sth = $dbh->prepare("SELECT ncbi_taxonomy.taxon_id, ncbi_taxonomy.name,ncbi_taxonomy.rank FROM tree JOIN ncbi_taxonomy ON ncbi_taxonomy.taxon_id = tree.taxon_id WHERE tree.left_id = (SELECT MAX(tree.left_id) FROM tree WHERE tree.left_id <= ? AND tree.right_id >= ?);");
	
	my $MaxLeftID = List::Util::min(@$Genome_left_ids);
	my $MinRightID = List::Util::max(@$Genome_right_ids);
	
	$sth->execute($MaxLeftID,$MinRightID);
	my $Nrows = $sth->rows;
			
	if($Nrows > 1){
				
		die "Error in SQL whilst finding MRCA of left_id $MaxLeftID right_id $MinRightID using superfamily.tree. More than one MRCA! Something is very wrong !\n";
		
	}elsif($Nrows == -1){
				
		die "Query appears to have failed on left_id $MaxLeftID and right_id $MinRightID!\n";
	}
					
	my ($taxon_id,$name,$rank) = $sth->fetchrow_array;
	
	$sth->finish;
	dbDisconnect($dbh);
	
	return ($taxon_id,$name,$rank);
}


=pod

=back

=head1 TODO

=over 4

=item Add feature here...

=back

=cut

1;
__END__

