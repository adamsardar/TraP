#!/usr/bin/env perl


use strict;
use warnings;
use lib "../lib";

use Getopt::Long;                     #Deal with command line options
use Pod::Usage;                       #Print a usage man page from the POD comments after __END__
use Data::Dumper;                     #Allow easy print dumps of datastructures for debugging
#use XML::Simple qw(:strict);          #Load a config file from the local directory
use DBI;
use Utils::SQL::Connect qw/:all/;
use Supfam::Utils qw/:all/;

my ( $dbh, $sth );
$dbh = dbConnect('trap','supfam2');


##################################GET THE NUMBER OF DISTINCT DOMAIN ARCHITECTURE FROM ANY EPOCH FOR EACH SAMPLE#####################################
my %distinct_archictectures_per_sample;
$sth =   $dbh->prepare( "select experiment.experiment_id,count(distinct(supra_id)) from experiment,snapshot_order_supra where experiment.experiment_id = snapshot_order_supra.experiment_id and experiment.include = 'y' group by experiment.experiment_id;"); 
        $sth->execute;
while (my @temp = $sth->fetchrow_array ) {
	$distinct_archictectures_per_sample{$temp[0]} = $temp[1];
}

##################################GET THE NUMBER OF DISTINCT DOMAIN ARCHITECTURES AT EACH EPOCH FOR EACH SAMPLE######################################
my %distinct_architectures_per_epoch_per_sample;
my %epochs;
my %samples;
$sth =   $dbh->prepare( "select taxon_id,experiment.experiment_id,count(distinct(supra_id)) from experiment,snapshot_order_supra where experiment.experiment_id = snapshot_order_supra.experiment_id and experiment.include = 'y' group by taxon_id,experiment.experiment_id;"); 
        $sth->execute;
while (my @temp = $sth->fetchrow_array ) {
	$distinct_architectures_per_epoch_per_sample{$temp[0]}{$temp[1]} = $temp[2];
	$epochs{$temp[0]} = 1;
	$samples{$temp[1]} = 1;
}

#################################DIVIDE THE NUMBER AT EACH EPOCH BY THE TOTAL NUMBER TO GET THE PROPORTION##########################################
my %proportion_of_architectures_per_epoch_per_sample;

foreach my $epoch (keys %epochs){
	foreach my $sample (keys %samples){
		if(exists($distinct_architectures_per_epoch_per_sample{$epoch}{$sample})){
			$proportion_of_architectures_per_epoch_per_sample{$epoch}{$sample} = $distinct_architectures_per_epoch_per_sample{$epoch}{$sample}/$distinct_archictectures_per_sample{$sample};
		}else{
			$proportion_of_architectures_per_epoch_per_sample{$epoch}{$sample} = 0;
		}
	}
}
#print Dumper \%proportion_of_architectures_per_epoch_per_sample;

my $SampleZscoreHash = {};
#A hash of structure $hash->{epoch_MRCA_taxon_id}{sample_id}{z_score}

$sth =   $dbh->prepare( "select taxon_id,experiment.experiment_id,count(distinct(supra_id)) from experiment,snapshot_order_supra where experiment.experiment_id = snapshot_order_supra.experiment_id and experiment.include = 'y' group by taxon_id,experiment.experiment_id;"); 

foreach my $MRCA (keys(%proportion_of_architectures_per_epoch_per_sample)){
	
	my $TempHash = calc_ZScore($proportion_of_architectures_per_epoch_per_sample{$MRCA});
	$SampleZscoreHash->{$MRCA}=$TempHash;
	

	mkdir("../data");
	open FH, ">../data/TaxonID.".$MRCA.".zscores.dat" or die $!.$?;
	print FH join("\n",values(%$TempHash));
	close FH;
	
	` Hist.py -f ../data/TaxonID.$MRCA.zscores.dat -o ../data/TaxonID.$MRCA.zscores.png -u 0` 

}

EasyDump('Zscores.dat',$SampleZscoreHash);
