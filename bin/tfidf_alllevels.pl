#!/usr/bin/env perl

use Modern::Perl;

=head1 NAME

tfidf_alllevels.pl

=head1 SYNOPSIS

tfidf_alllevels.pl [options]

 Basic Options:
  -h --help Get full man page output
  -v --verbose Verbose output with details of mutations
  -d --debug Debug output

=head1 DESCRIPTION

Using term frequency / inverse document frequncy as a measure of enrichement, provides enrichement statistics for GO terms and domain architectures
at the levels of per sample, per cluster and per cluster neuron.

=head1 EXAMPLES

tfidf_alllevels.pl -v -d

=head1 AUTHOR

B<Adam Sardar> - I<Adam.Sardar@bristol.ac.uk>

B<Owen Rackham> - I<Owen.Rackham@bristol.ac.uk>

=head1 LICENSE AND COPYRIGHT

B<Copyright 2012 Matt Oates, Owen Rackham, Adam Sardar>

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
use TraP::Topic::TFIDF qw/:all/;
use Utils::SQL::Connect qw/:all/;
use Supfam::Utils qw/:all/;
use Devel::Size qw(size total_size);
use Carp::Assert;
use Carp::Assert::More;

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
use Time::HiRes;

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
my @files= @ARGV;

#Main Script Content
#-------------------------------------------------------------------------------

my $TotalTic = Time::HiRes::time;

#Connect to SUPERFAMILY usign a different dbh to that used below. Prepare a cached query so that we can extract GO terms per supra id that we provide
#In each section, bung the GO terms into a hash similar to the detialed hashes

#Perform enrichement analysis on those as well ...

#Create a SUPERFAMILY dbh						

my ($supfam_dbh, $supfam_sth);
$supfam_dbh = dbConnect('superfamily');

$supfam_sth =   $supfam_dbh->prepare_cached( "SELECT GO_mapping_supra.go,GO_info.name 
								FROM GO_mapping_supra 
								JOIN GO_info 
								ON GO_mapping_supra.go = GO_info.go 
								WHERE GO_mapping_supra.id = ?;"); 
my $GO_Dictionary = {};
#this will be a quick look up of Domain architecture to GO id and synonym. Structure: hash->{DA}[list of GOids]
my $GO_detailed = {};

##### DA terms #####

my ($dbh, $sth);
$dbh = dbConnect();

########## Per Sample ##########

print STDERR "Now processing a per sample statistic ...\n" if($verbose);

my $PerSampleHash={};
#Hash of structure $Hash->{SampleName}=[list of potentially non-unque terms]
my $PerSampleDetailedCount={};
#Hash of structure $Hash->{DocumentName}{term} = count

my $PerSampleGODetailedCount={};
my $PerSampleGOHash={};
#As above, but these shall be for GO terms

$sth =   $dbh->prepare( "SELECT snapshot_order_comb.comb_id,sample_index.sample_id,sample_index.sample_name
						FROM snapshot_order_comb
						JOIN sample_index
						ON snapshot_order_comb.sample_id = sample_index.sample_id
						AND snapshot_order_comb.comb_id != 1
						;"); 
$sth->execute();

my $SampleID2NameDict = {};
#So as to allow the output to contain information of the sampel name, but whilst still workign with sampel IDs internally to the script

#While loop below goes as follows:
# Extract all domain 

while (my ($CombID,$samp_id,$sample_name) = $sth->fetchrow_array ) {
	
	$SampleID2NameDict->{$samp_id} = $sample_name unless(exists($SampleID2NameDict->{$samp_id}));
	
	$PerSampleDetailedCount->{$samp_id}={} unless(exists($PerSampleDetailedCount->{$samp_id}));
	$PerSampleDetailedCount->{$samp_id}{$CombID}++;
	
	unless(exists($GO_Dictionary->{$CombID})){
		
		$supfam_sth->execute($CombID);
		
		$GO_Dictionary->{$CombID}=undef;
		#If there is no GO annotation for the comb of interest, set as undef and the enxt step will not popualte an array fo go terms
		
		while (my ($GOid,$details) = $supfam_sth->fetchrow_array ) {
		
			$GO_Dictionary->{$CombID} = [];
			assert_listref($GO_Dictionary->{$CombID},"GO_dictionary shoudl be a hash of structure  GO_dictionary->{comb_id}=arrayref or udnef\n");
			push(@{$GO_Dictionary->{$CombID}},$GOid);
			$GO_detailed->{$GOid}=$details unless(exists($GO_detailed->{$GOid}));
			#Query superfamily for details regarding this comb
			#Push onto GO dictionary $GO_Dictionary
		}
	}
	
	next if($GO_Dictionary->{$CombID} ~~ undef);
	
	assert_listref($GO_Dictionary->{$CombID},"GO_dictionary shoudl be a hash of structure  GO_dictionary->{comb_id}=arrayref or udnef\n");
	foreach my $GO (@{$GO_Dictionary->{$CombID}}){
		
		$PerSampleGODetailedCount->{$samp_id}={} unless(exists($PerSampleGODetailedCount->{$samp_id}));
		$PerSampleGODetailedCount->{$samp_id}{$GO}++;
	}
	
}

$sth->finish;


foreach my $doc (keys(%$PerSampleDetailedCount)){
	
	$PerSampleHash->{$doc}=[keys(%{$PerSampleDetailedCount->{$doc}})];
	$PerSampleGOHash->{$doc}=[keys(%{$PerSampleGODetailedCount->{$doc}})];
}
#Prepare a hash ($PerSampleHash) to prepare idf upon

#Query superfamily for GO term information

my $PerSampDA_idf = idf_calc($PerSampleHash);
my $PerSampGO_idf = idf_calc($PerSampleGOHash);

my @DATerms = keys(%$PerSampDA_idf);
my @GOTerms = keys(%$PerSampGO_idf);
#A list of all the terms that we wish to calculate TF(term frequncy) upon

my $PerSampDA_tf = logtf_calc($PerSampleDetailedCount,\@DATerms);
my $PerSampGO_tf = logtf_calc($PerSampleGODetailedCount,\@GOTerms);

#Output

mkdir("../data");
mkdir("../data/Enrichment");

open PERSAMDA, ">../data/Enrichment/PerSample.DA.TF_IDF.txt";
open PERSAMGO, ">../data/Enrichment/PerSample.GO.TF_IDF.txt";

foreach my $sampid (keys(%$PerSampleDetailedCount)){
	
	
	#Output DA information
	foreach my $trait (keys(%{$PerSampleDetailedCount->{$sampid}})){
		
		my $sampnam = $SampleID2NameDict->{$sampid};
		my $tf = $PerSampDA_tf->{$sampid}{$trait};
		my $idf = $PerSampDA_idf->{$trait};
		my $tfidf_score = $tf*$idf;
		
		print PERSAMDA $sampnam."\t".$sampid."\t".$trait."\t".$tfidf_score."\n";
	}
	
	#Output GO information
	foreach my $trait (keys(%{$PerSampleGODetailedCount->{$sampid}})){
		
		my $sampnam = $SampleID2NameDict->{$sampid};
		my $tf = $PerSampGO_tf->{$sampid}{$trait};
		my $idf = $PerSampGO_idf->{$trait};
		my $tfidf_score = $tf*$idf;
		my $GOdetails = $GO_detailed->{$trait};
		
		print PERSAMGO $sampnam."\t".$sampid."\t".$trait."\t".$GOdetails."\t".$tfidf_score."\n";
	}
	
	
}

close PERSAMDA;
close PERSAMGO;

if($debug){
	my $samsize = total_size($PerSampleDetailedCount)/1024**2;
	print "DA Hash occupies for samples ".$samsize." MB \n";
	$samsize = total_size($PerSampleGODetailedCount)/1024**2;
	print "GO Hash occupies for samples ".$samsize." MB \n";
}

($PerSampleDetailedCount,$PerSampleGODetailedCount) = (undef,undef);


########## Per Cluster ##########

print STDERR "Now processing a per cluster statistic ...\n" if($verbose);

my $PerClusterHash={};
#Hash of structure $Hash->{SampleName}=[list of potentially non-unque terms]
my $PerClusterDetailedCount={};
#Hash of structure $Hash->{DocumentName}{term} = count

my $PerClusterGODetailedCount={};
my $PerClusterGOHash={};
#As above, but these shall be for GO terms

$sth =   $dbh->prepare( "SELECT experiment_cluster.cluster_id,snapshot_order_comb.comb_id
						FROM snapshot_order_comb
						JOIN experiment_cluster
						ON experiment_cluster.sample_id = snapshot_order_comb.sample_id
						;"); 
$sth->execute();



while (my ($Clus_ID,$CombID) = $sth->fetchrow_array ) {
	
	$PerClusterDetailedCount->{$Clus_ID}={} unless(exists($PerClusterDetailedCount->{$Clus_ID}));
	$PerClusterDetailedCount->{$Clus_ID}{$CombID}++;
	
	unless(exists($GO_Dictionary->{$CombID})){
		
		$supfam_sth->execute($CombID);
		
		$GO_Dictionary->{$CombID}=undef;
		#If there is no GO annotation for the comb of interest, set as undef and the enxt step will not popualte an array fo go terms
		
		while (my ($GOid,$details) = $supfam_sth->fetchrow_array ) {
		
			$GO_Dictionary->{$CombID} = [];
			assert_listref($GO_Dictionary->{$CombID},"GO_dictionary shoudl be a hash of structure  GO_dictionary->{comb_id}=arrayref or udnef\n");
			push(@{$GO_Dictionary->{$CombID}},$GOid);
			$GO_detailed->{$GOid}=$details unless(exists($GO_detailed->{$GOid}));
			#Query superfamily for details regarding this comb
			#Push onto GO dictionary $GO_Dictionary
		}
	}
	
	next if($GO_Dictionary->{$CombID} ~~ undef);
	
	assert_listref($GO_Dictionary->{$CombID},"GO_dictionary shoudl be a hash of structure  GO_dictionary->{comb_id}=arrayref or udnef\n");
	foreach my $GO (@{$GO_Dictionary->{$CombID}}){
		
		$PerClusterGODetailedCount->{$Clus_ID}={} unless(exists($PerClusterGODetailedCount->{$Clus_ID}));
		$PerClusterGODetailedCount->{$Clus_ID}{$GO}++;
	}
	
}

$sth->finish;


foreach my $doc (keys(%$PerClusterDetailedCount)){
	
	$PerClusterHash->{$doc}=[keys(%{$PerClusterDetailedCount->{$doc}})];
	$PerClusterGOHash->{$doc}=[keys(%{$PerClusterGODetailedCount->{$doc}})];
}
#Prepare a hash ($PerSampleHash) to prepare idf upon

#Query superfamily for GO term information

my $PerClusDA_idf = idf_calc($PerClusterHash);
my $PerClusGO_idf = idf_calc($PerClusterGOHash);

@DATerms = keys(%$PerClusDA_idf);
@GOTerms = keys(%$PerClusGO_idf);
#A list of all the terms that we wish to calculate TF(term frequncy) upon

my $PerClusDA_tf = logtf_calc($PerClusterDetailedCount,\@DATerms);
my $PerClusGO_tf = logtf_calc($PerClusterGODetailedCount,\@GOTerms);

#Output

mkdir("../data");
mkdir("../data/Enrichment");

open PERCLUSDA, ">../data/Enrichment/PerCluster.DA.TF_IDF.txt";
open PERCLSUGO, ">../data/Enrichment/PerCluster.GO.TF_IDF.txt";

foreach my $sampid (keys(%$PerClusterDetailedCount)){
	
	
	#Output DA information
	foreach my $trait (keys(%{$PerClusterDetailedCount->{$sampid}})){
		
		my $tf = $PerClusDA_tf->{$sampid}{$trait};
		my $idf = $PerClusDA_idf->{$trait};
		my $tfidf_score = $tf*$idf;
		
		print PERCLUSDA $sampid."\t".$trait."\t".$tfidf_score."\n";
	}
	
	#Output GO information
	foreach my $trait (keys(%{$PerClusterGODetailedCount->{$sampid}})){
		
		my $tf = $PerClusGO_tf->{$sampid}{$trait};
		my $idf = $PerClusGO_idf->{$trait};
		my $tfidf_score = $tf*$idf;
		my $GOdetails = $GO_detailed->{$trait};
		
		print PERCLSUGO $sampid."\t".$trait."\t".$GOdetails."\t".$tfidf_score."\n";
	}
	
}

close PERSAMDA;
close PERCLSUGO;

if($debug){
	my $samsize = total_size($PerClusterDetailedCount)/1024**2;
	print "DA Hash occupies for samples ".$samsize." MB \n";
	$samsize = total_size($PerClusterGODetailedCount)/1024**2;
	print "GO Hash occupies for samples ".$samsize." MB \n";
}

($PerClusterDetailedCount,$PerClusterGODetailedCount) = (undef,undef);


########## Per Neuron ##########

print STDERR "Now processing a per neuron statistic ...\n" if($verbose);

my $PerNeuronHash={};
#Hash of structure $Hash->{SampleName}=[list of potentially non-unque terms]
my $PerNeuronDetailedCount={};
#Hash of structure $Hash->{DocumentName}{term} = count

my $PerNeuronGODetailedCount={};
my $PerNeuronGOHash={};
#As above, but these shall be for GO terms

$sth =   $dbh->prepare( "SELECT experiment_cluster.cluster_id,experiment_cluster.unit_id,snapshot_order_comb.comb_id
						FROM snapshot_order_comb
						JOIN experiment_cluster
						ON experiment_cluster.sample_id = snapshot_order_comb.sample_id
						;"); 
$sth->execute();


while (my ($Clus_ID,$unit_id,$CombID) = $sth->fetchrow_array ) {
	
	my $samnam = $Clus_ID.':'.$unit_id;
	
	$PerNeuronDetailedCount->{$samnam}={} unless(exists($PerNeuronDetailedCount->{$samnam}));
	$PerNeuronDetailedCount->{$samnam}{$CombID}++;
	
	unless(exists($GO_Dictionary->{$CombID})){
		
		$supfam_sth->execute($CombID);
		
		$GO_Dictionary->{$CombID}=undef;
		#If there is no GO annotation for the comb of interest, set as undef and the enxt step will not popualte an array fo go terms
		
		while (my ($GOid,$details) = $supfam_sth->fetchrow_array ) {
		
			$GO_Dictionary->{$CombID} = [];
			assert_listref($GO_Dictionary->{$CombID},"GO_dictionary shoudl be a hash of structure  GO_dictionary->{comb_id}=arrayref or udnef\n");
			push(@{$GO_Dictionary->{$CombID}},$GOid);
			$GO_detailed->{$GOid}=$details unless(exists($GO_detailed->{$GOid}));
			#Query superfamily for details regarding this comb
			#Push onto GO dictionary $GO_Dictionary
		}
	}
	
	next if($GO_Dictionary->{$CombID} ~~ undef);
	
	assert_listref($GO_Dictionary->{$CombID},"GO_dictionary shoudl be a hash of structure  GO_dictionary->{comb_id}=arrayref or udnef\n");
	foreach my $GO (@{$GO_Dictionary->{$CombID}}){
		
		$PerNeuronGODetailedCount->{$samnam}={} unless(exists($PerNeuronGODetailedCount->{$samnam}));
		$PerNeuronGODetailedCount->{$samnam}{$GO}++;
	}
	
}

$sth->finish;


foreach my $doc (keys(%$PerNeuronDetailedCount)){
	
	$PerNeuronHash->{$doc}=[keys(%{$PerNeuronDetailedCount->{$doc}})];
	$PerNeuronGOHash->{$doc}=[keys(%{$PerNeuronGODetailedCount->{$doc}})];
}
#Prepare a hash ($PerSampleHash) to prepare idf upon

#Query superfamily for GO term information

my $PerNeuronDA_idf = idf_calc($PerNeuronHash);
my $PerNeuronGO_idf = idf_calc($PerNeuronGOHash);

@DATerms = keys(%$PerNeuronDA_idf);
@GOTerms = keys(%$PerNeuronGO_idf);
#A list of all the terms that we wish to calculate TF(term frequncy) upon

my $PerNeuronDA_tf = logtf_calc($PerNeuronDetailedCount,\@DATerms);
my $PerNeuronGO_tf = logtf_calc($PerNeuronGODetailedCount,\@GOTerms);

#Output

mkdir("../data");
mkdir("../data/Enrichment");

open PERNEURDA, ">../data/Enrichment/PerNeuron.DA.TF_IDF.txt";
open PERNEURGO, ">../data/Enrichment/PerNeuron.GO.TF_IDF.txt";

foreach my $sampid (keys(%$PerNeuronDetailedCount)){
	
	my ($Clus_ID,$unit_id) = split(':',$sampid);
		
	#Output DA information
	foreach my $trait (keys(%{$PerNeuronDetailedCount->{$sampid}})){
		
		my $tf = $PerNeuronDA_tf->{$sampid}{$trait};
		my $idf = $PerNeuronDA_idf->{$trait};
		my $tfidf_score = $tf*$idf;
		
		print PERNEURDA $Clus_ID."\t".$unit_id."\t".$trait."\t".$tfidf_score."\n";
	}
	
	#Output GO information
	foreach my $trait (keys(%{$PerNeuronGODetailedCount->{$sampid}})){
		
		my $tf = $PerNeuronGO_tf->{$sampid}{$trait};
		my $idf = $PerNeuronGO_idf->{$trait};
		my $tfidf_score = $tf*$idf;
		my $GOdetails = $GO_detailed->{$trait};
		
		print PERNEURGO $Clus_ID."\t".$unit_id."\t".$trait."\t".$GOdetails."\t".$tfidf_score."\n";
	}
	
}

close PERNEURDA;
close PERNEURGO;

if($debug){
	my $samsize = total_size($PerNeuronDetailedCount)/1024**2;
	print "DA Hash occupies for samples ".$samsize." MB \n";
	$samsize = total_size($PerNeuronGODetailedCount)/1024**2;
	print "GO Hash occupies for samples ".$samsize." MB \n";
}

($PerNeuronDetailedCount,$PerNeuronGODetailedCount) = (undef,undef);


###################### TIDY UP


my $TotalToc = Time::HiRes::time;
my $TotalTimeTaken = ($TotalToc - $TotalTic);
say STDERR "Total Time Taken:".$TotalTimeTaken if($verbose);


dbDisconnect($dbh);

__END__


