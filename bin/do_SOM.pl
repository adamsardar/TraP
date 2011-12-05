#!/usr/bin/perl -w

use strict;
use warnings;
use DBI;
use lib '/home/rackham/modules';
use rackham;
use lib "../lib/TraP";
use lib "../lib/";
use Cluster::SOM;
use Data::Dumper;
use Supfam::Utils;
my %genes;
my %samples;
my %genes_tc;
my %samples_tc;
my %exps;
my %gene_d;
my %network_d;
my %tc_exps;
my %tc_sample;

my %exp_array;
my $TFs = rackham::GetGeneLookup;
my %TFs = %{$TFs};
my ( $dbh, $sth );
$dbh = rackham::DBConnect;
print "running....\n";
 #$sth =   $dbh->prepare( "select sampleID,geneID,value from snap_gene_expression where releaseID = 111;" );
   #     $sth->execute;
   #     print "query returned 1\n";
        #while (my @temp = $sth->fetchrow_array ) {
	#		$genes{$temp[1]} = 1;
	#		$samples{$temp[0]} = 1;
	#		$exps{$temp[0]}{$temp[1]}=$temp[2];
        #}
  #print "loaded data round 1\n";      

 $sth =   $dbh->prepare( "select tprot.raw_data.sampleID, tprot.raw_data.groupID, tprot.raw_data.replica, tprot.raw_data.value, SUBSTRING(tprot.raw_data.GeneID,1,CHAR_LENGTH(tprot.raw_data.GeneID)-2) as a, rackham.ENT_lookup.GeneID from tprot.raw_data , rackham.ENT_lookup where SUBSTRING(tprot.raw_data.GeneID,1,CHAR_LENGTH(tprot.raw_data.GeneID)-2) = rackham.ENT_lookup.ENTID and SampleID = 2;" );
#select tprot.raw_data.sampleID, tprot.raw_data.groupID, tprot.raw_data.replica, tprot.raw_data.value, SUBSTRING(tprot.raw_data.GeneID,1,CHAR_LENGTH(tprot.raw_data.GeneID)-2) as a, rackham.ENT_lookup.GeneID from tprot.raw_data , rackham.ENT_lookup where SUBSTRING(tprot.raw_data.GeneID,1,CHAR_LENGTH(tprot.raw_data.GeneID)-2) = rackham.ENT_lookup.ENTID and SampleID = 5 order by GeneID limit 10;
        $sth->execute;
        print "query returned 2\n";
        while (my @temp = $sth->fetchrow_array ) {
			my $sample = "$temp[0]"."."."$temp[1]"."."."$temp[2]";
			$tc_exps{$temp[0]} = 1;
			$samples{$sample} =1;
			my $g = $temp[5];
			$genes{$g} = 1;
			if(exists($exps{$g}{$sample})){;
			$exps{$g}{$sample}= $exps{$g}{$sample} + $temp[3];
			}else{
			$exps{$g}{$sample}=$temp[3];
			}
        }
print "loaded data round 2\n";
        
open(EXPS,'>exps.txt');

my $Names = join("\t", keys %genes); 
print EXPS "samples\t$Names\n";


foreach my $sample (keys %genes){
	print EXPS "$sample\t";

	foreach my $gene (keys %samples){
		if(exists($exps{$sample}{$gene})){
			if($exps{$sample}{$gene} == 0){
			print EXPS "NaN\t";
			push @{$exp_array{$sample}},$exps{$sample}{$gene};
			}else{
			print EXPS "$exps{$sample}{$gene}\t";
			push @{$exp_array{$sample}},$exps{$sample}{$gene};
			}
		}else{
			print EXPS "NaN\t";
			push @{$exp_array{$sample}},0;
		}

	}
	print EXPS "\n";

}

my ($ClusterPositionsHash,$XYClusterGroups) = SOMcluster(\%exp_array,'s',0);
EasyDump("./ClusterPositionsHash.dat", $ClusterPositionsHash);
EasyDump("./XYClusterGroups.dat", $XYClusterGroups);

foreach my $s (keys %tc_exps){
open(TCEXPS,">tc_exps_$s.txt");

$Names = join("\t", keys %genes_tc); 
print TCEXPS "samples\t$Names\n";

foreach my $sample_1 (sort keys %{$tc_sample{$s}}){
foreach my $sample_2 (sort keys %{$tc_sample{$s}{$sample_1}}){

	print TCEXPS "$s"."$sample_1"."$sample_2"."\t";
	foreach my $gene (sort keys %genes_tc){
		if(exists($tc_sample{$s}{$sample_1}{$sample_2}{$gene})){
			if($tc_sample{$s}{$sample_1}{$sample_2}{$gene} == 0){
			print TCEXPS "NaN\t";
			}else{
			print TCEXPS "$tc_sample{$s}{$sample_1}{$sample_2}{$gene}\t";
			}
		}else{
			print TCEXPS "NaN\t";
		}


	}
	print TCEXPS "\n";
}
}
}


	
