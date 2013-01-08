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

my $sth_PO_queries = PO_query_construct;
my $sth_GO_queries = GO_query_construct;
#Prepare $sth's for use in later queries

my ($dbh, $sth);
$dbh = dbConnect();

mkdir("../data");
mkdir("../data/Enrichment");
#Prepare output dir

########## Per Sample ##########

print STDERR "Now processing a per sample statistic ...\n" if($verbose);


#Hash of structure $Hash->{SampleName}=[list of potentially non-unque terms]
my $PerSampleDetailedCount={};
#Hash of structure $Hash->{DocumentName}{term} = count


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

my $Uniq_combs = {};

while (my ($CombID,$samp_id,$sample_name) = $sth->fetchrow_array ) {
	
	$SampleID2NameDict->{$samp_id} = $sample_name unless(exists($SampleID2NameDict->{$samp_id}));
	
	$PerSampleDetailedCount->{$samp_id}={} unless(exists($PerSampleDetailedCount->{$samp_id}));
	$PerSampleDetailedCount->{$samp_id}{$CombID}++;	
	$Uniq_combs->{$CombID} = undef;
}

$sth->finish;

my ($Comb2HPList,$Comb2DOList) = PO_table_info([keys(%$Uniq_combs)],$sth_PO_queries);
my $Comb2GOList = GO_table_info([keys(%$Uniq_combs)],$sth_GO_queries);

my $PerSampleDAHash={};
my $PerSampleGOHash={};
my $PerSampleDOHash={};
my $PerSampleHPHash={};
#Simply going to be a list of which DA/GO/PO are present in the sample

my $PerSampleGODetailedCount={};
my $PerSampleDODetailedCount={};
my $PerSampleHPDetailedCount={};
#Simply going to be a list of which DA/GO/PO are present in the sample


foreach my $doc (keys(%$PerSampleDetailedCount)){
	
	my @CombIDs = keys(%{$PerSampleDetailedCount->{$doc}});

	$PerSampleDAHash->{$doc}=[@CombIDs];
	
	my (undef,$GOcombs,undef,undef) = IntUnDiff(\@CombIDs,[keys(%$Comb2GOList)]);
	$PerSampleGOHash->{$doc}=[map{@$_}@{$Comb2GOList}{@$GOcombs}];
	$PerSampleGODetailedCount->{$doc}={};
	map{$PerSampleGODetailedCount->{$doc}{$_}++}map{@$_}@{$Comb2GOList}{@$GOcombs};
	
	my (undef,$DOcombs,undef,undef) = IntUnDiff(\@CombIDs,[keys(%$Comb2DOList)]);
	$PerSampleDOHash->{$doc}=[map{@$_}@{$Comb2DOList}{@$DOcombs}];
	$PerSampleDODetailedCount->{$doc}={};
	map{$PerSampleDODetailedCount->{$doc}{$_}++}map{@$_}@{$Comb2DOList}{@$DOcombs};
	
	my (undef,$HPcombs,undef,undef) = IntUnDiff(\@CombIDs,[keys(%$Comb2HPList)]);
	$PerSampleHPHash->{$doc}=[map{@$_}@{$Comb2HPList}{@$HPcombs}];
	$PerSampleHPDetailedCount->{$doc}={};
	map{$PerSampleHPDetailedCount->{$doc}{$_}++}map{@$_}@{$Comb2HPList}{@$HPcombs};

}

#constuct a per sample idf for use across all analysise below

my $PerSampDA_idf = idf_calc($PerSampleDAHash);
my $PerSampGO_idf = idf_calc($PerSampleGOHash);
my $PerSampDO_idf = idf_calc($PerSampleDOHash);
my $PerSampHP_idf = idf_calc($PerSampleHPHash);

if($debug){
	
	mkdir('../data/debug/');
	
	EasyDump('../data/debug/DAsampHash.dat',$PerSampleDetailedCount);
	EasyDump('../data/debug/GOsampHash.dat',$PerSampleGODetailedCount);
	EasyDump('../data/debug/DOsampHash.dat',$PerSampleDODetailedCount);
	EasyDump('../data/debug/HPsampHash.dat',$PerSampleHPDetailedCount);
	
	EasyDump('../data/debug/DAIDFHash.dat',$PerSampDA_idf);
	EasyDump('../data/debug/GOIDFHash.dat',$PerSampGO_idf);
	EasyDump('../data/debug/DOIDFHash.dat',$PerSampDO_idf);
	EasyDump('../data/debug/HPIDFHash.dat',$PerSampHP_idf);
	
	EasyDump('../data/debug/DAsampSimpleHash.dat',$PerSampleDAHash);
	EasyDump('../data/debug/GOsampSimpleHash.dat',$PerSampleGOHash);
	EasyDump('../data/debug/DOsampSimpleHash.dat',$PerSampleDOHash);
	EasyDump('../data/debug/HPsampSimpleHash.dat',$PerSampleHPHash);
	
	my $samsize = total_size($PerSampleDetailedCount)/1024**2;
	print "DA Hash occupies for samples ".$samsize." MB \n";
	$samsize = total_size($PerSampleGODetailedCount)/1024**2;
	print "GO Hash occupies for samples ".$samsize." MB \n";
	$samsize = total_size($PerSampleDODetailedCount)/1024**2;
	print "DO Hash occupies for samples ".$samsize." MB \n";
	$samsize = total_size($PerSampleHPDetailedCount)/1024**2;
	print "HP Hash occupies for samples ".$samsize." MB \n";
}
#A little debug information regarding sizes of hashes

my $DATerms = [keys(%$PerSampDA_idf)];
my $GOTerms = [keys(%$PerSampGO_idf)];
my $DOTerms = [keys(%$PerSampDO_idf)];
my $HPTerms = [keys(%$PerSampHP_idf)];
#A list of all the terms that we wish to calculate TF(term frequncy) upon

my $GO_detailed = GO_detailed_info($GOTerms);
my $PO_detailed = PO_detailed_info([@$DOTerms,@$HPTerms]);

enrichment_output("../data/Enrichment/PerSample.DA.Enrichement.txt",$PerSampleDetailedCount,$PerSampDA_idf,$DATerms,$SampleID2NameDict);
enrichment_output("../data/Enrichment/PerSample.GO.Enrichement.txt",$PerSampleGODetailedCount,$PerSampGO_idf,$GOTerms,$GO_detailed);
enrichment_output("../data/Enrichment/PerSample.DO.Enrichement.txt",$PerSampleDODetailedCount,$PerSampDO_idf,$DOTerms,$PO_detailed);
enrichment_output("../data/Enrichment/PerSample.HP.Enrichement.txt",$PerSampleHPDetailedCount,$PerSampHP_idf,$HPTerms,$PO_detailed);

########## Per Cluster ##########

print STDERR "Now processing a per cluster statistic ...\n" if($verbose);

#Hash of structure $Hash->{SampleName}=[list of potentially non-unque terms]
my $PerClusterDADetailedCount={};
#Hash of structure $Hash->{DocumentName}{term} = count

$sth =   $dbh->prepare( "SELECT snapshot_order_comb.comb_id,experiment_cluster.unit_id
						FROM experiment_cluster
						JOIN snapshot_order_comb
						ON experiment_cluster.sample_id = snapshot_order_comb.sample_id
						WHERE snapshot_order_comb.comb_id != 1
						;"); 
$sth->execute();

#While loop below goes as follows:
# Extract all domain 

$Uniq_combs = {};
while (my ($CombID,$clus_id) = $sth->fetchrow_array ) {
	
	$PerClusterDADetailedCount->{$clus_id}={} unless(exists($PerClusterDADetailedCount->{$clus_id}));
	$PerClusterDADetailedCount->{$clus_id}{$CombID}++;	
	$Uniq_combs->{$CombID} = undef;
}

$sth->finish;

($Comb2HPList,$Comb2DOList) = PO_table_info([keys(%$Uniq_combs)],$sth_PO_queries);
$Comb2GOList = GO_table_info([keys(%$Uniq_combs)],$sth_GO_queries);

my $PerClusterDAHash={};
my $PerClusterGOHash={};
my $PerClusterDOHash={};
my $PerClusterHPHash={};
#Simply going to be a list of which DA/GO/PO are present in the sample

my $PerClusterGODetailedCount={};
my $PerClusterDODetailedCount={};
my $PerClusterHPDetailedCount={};
#Simply going to be a list of which DA/GO/PO are present in the sample

foreach my $doc (keys(%$PerClusterDADetailedCount)){
	
	my @CombIDs = keys(%{$PerClusterDADetailedCount->{$doc}});

	$PerClusterDAHash->{$doc}=[@CombIDs];
	
	my (undef,$GOcombs,undef,undef) = IntUnDiff(\@CombIDs,[keys(%$Comb2GOList)]);
	$PerClusterGOHash->{$doc}=[map{@$_}@{$Comb2GOList}{@$GOcombs}];
	$PerClusterGODetailedCount->{$doc}={};
	map{$PerClusterGODetailedCount->{$doc}{$_}++}map{@$_}@{$Comb2GOList}{@$GOcombs};
	
	my (undef,$DOcombs,undef,undef) = IntUnDiff(\@CombIDs,[keys(%$Comb2DOList)]);
	$PerClusterDOHash->{$doc}=[map{@$_}@{$Comb2DOList}{@$DOcombs}];
	$PerClusterDODetailedCount->{$doc}={};
	map{$PerClusterDODetailedCount->{$doc}{$_}++}map{@$_}@{$Comb2DOList}{@$DOcombs};
	
	my (undef,$HPcombs,undef,undef) = IntUnDiff(\@CombIDs,[keys(%$Comb2HPList)]);
	$PerClusterHPHash->{$doc}=[map{@$_}@{$Comb2HPList}{@$HPcombs}];
	$PerClusterHPDetailedCount->{$doc}={};
	map{$PerClusterHPDetailedCount->{$doc}{$_}++}map{@$_}@{$Comb2HPList}{@$HPcombs};
}

#constuct a per sample idf for use across all analysise below

if($debug){
	
	EasyDump('../data/debug/clusDAHash.dat',$PerClusterDADetailedCount);
	EasyDump('../data/debug/clusGOHash.dat',$PerClusterGODetailedCount);
	EasyDump('../data/debug/clusDOHash.dat',$PerClusterDODetailedCount);
	EasyDump('../data/debug/clusHPHash.dat',$PerClusterHPDetailedCount);

	EasyDump('../data/debug/clusDASimpleHash.dat',$PerClusterDAHash);
	EasyDump('../data/debug/clusGOSimpleHash.dat',$PerClusterGOHash);
	EasyDump('../data/debug/clusDOSimpleHash.dat',$PerClusterDOHash);
	EasyDump('../data/debug/clusHPSimpleHash.dat',$PerClusterHPHash);
	
	my $samsize = total_size($PerClusterDADetailedCount)/1024**2;
	print "DA Hash occupies for samples ".$samsize." MB \n";
	$samsize = total_size($PerClusterGODetailedCount)/1024**2;
	print "GO Hash occupies for samples ".$samsize." MB \n";
	$samsize = total_size($PerClusterDODetailedCount)/1024**2;
	print "DO Hash occupies for samples ".$samsize." MB \n";
	$samsize = total_size($PerClusterHPDetailedCount)/1024**2;
	print "HP Hash occupies for samples ".$samsize." MB \n";
}
#A little debug information regarding sizes of hashes

enrichment_output("../data/Enrichment/PerCluster.DA.Enrichement.txt",$PerClusterDADetailedCount,$PerSampDA_idf,$DATerms);
enrichment_output("../data/Enrichment/PerCluster.GO.Enrichement.txt",$PerClusterGODetailedCount,$PerSampGO_idf,$GOTerms,$GO_detailed);
enrichment_output("../data/Enrichment/PerCluster.DO.Enrichement.txt",$PerClusterDODetailedCount,$PerSampDO_idf,$DOTerms,$PO_detailed);
enrichment_output("../data/Enrichment/PerCluster.HP.Enrichement.txt",$PerClusterHPDetailedCount,$PerSampHP_idf,$HPTerms,$PO_detailed);

########## Per Neuron ##########

print STDERR "Now processing a per neuron statistic ...\n" if($verbose);

#Hash of structure $Hash->{SampleName}=[list of potentially non-unque terms]
my $PerNeuronDADetailedCount={};
#Hash of structure $Hash->{DocumentName}{term} = count

$sth =   $dbh->prepare( "SELECT snapshot_order_comb.comb_id,experiment_cluster.cluster_id
						FROM experiment_cluster
						JOIN snapshot_order_comb
						ON experiment_cluster.sample_id = snapshot_order_comb.sample_id
						WHERE snapshot_order_comb.comb_id != 1
						;"); 
$sth->execute();

#While loop below goes as follows:
# Extract all domain 

$Uniq_combs = {};
while (my ($CombID,$clus_id) = $sth->fetchrow_array ) {
	
	$PerNeuronDADetailedCount->{$clus_id}={} unless(exists($PerNeuronDADetailedCount->{$clus_id}));
	$PerNeuronDADetailedCount->{$clus_id}{$CombID}++;	
	$Uniq_combs->{$CombID} = undef;
}

$sth->finish;

($Comb2HPList,$Comb2DOList) = PO_table_info([keys(%$Uniq_combs)],$sth_PO_queries);
$Comb2GOList = GO_table_info([keys(%$Uniq_combs)],$sth_GO_queries);

my $PerNeuronDAHash={};
my $PerNeuronGOHash={};
my $PerNeuronDOHash={};
my $PerNeuronHPHash={};
#Simply going to be a list of which DA/GO/PO are present in the sample

my $PerNeuronGODetailedCount={};
my $PerNeuronDODetailedCount={};
my $PerNeuronHPDetailedCount={};
#Simply going to be a list of which DA/GO/PO are present in the sample

foreach my $doc (keys(%$PerNeuronDADetailedCount)){
	
	my @CombIDs = keys(%{$PerNeuronDADetailedCount->{$doc}});

	$PerNeuronDAHash->{$doc}=[@CombIDs];
	
	my (undef,$GOcombs,undef,undef) = IntUnDiff(\@CombIDs,[keys(%$Comb2GOList)]);
	$PerNeuronGOHash->{$doc}=[map{@$_}@{$Comb2GOList}{@$GOcombs}];
	$PerNeuronGODetailedCount->{$doc}={};
	map{$PerNeuronGODetailedCount->{$doc}{$_}++}map{@$_}@{$Comb2GOList}{@$GOcombs};
	
	my (undef,$DOcombs,undef,undef) = IntUnDiff(\@CombIDs,[keys(%$Comb2DOList)]);
	$PerClusterDOHash->{$doc}=[map{@$_}@{$Comb2DOList}{@$DOcombs}];
	$PerNeuronDODetailedCount->{$doc}={};
	map{$PerNeuronDODetailedCount->{$doc}{$_}++}map{@$_}@{$Comb2DOList}{@$DOcombs};
	
	my (undef,$HPcombs,undef,undef) = IntUnDiff(\@CombIDs,[keys(%$Comb2HPList)]);
	$PerNeuronHPHash->{$doc}=[map{@$_}@{$Comb2HPList}{@$HPcombs}];
	$PerNeuronHPDetailedCount->{$doc}={};
	map{$PerNeuronHPDetailedCount->{$doc}{$_}++}map{@$_}@{$Comb2HPList}{@$HPcombs};
}

#constuct a per sample idf for use across all analysise below

if($debug){
	
	EasyDump('../data/debug/neuronDAHash.dat',$PerNeuronDADetailedCount);
	EasyDump('../data/debug/neuronGOHash.dat',$PerNeuronGODetailedCount);
	EasyDump('../data/debug/neuronDOHash.dat',$PerNeuronDODetailedCount);
	EasyDump('../data/debug/neuronHPHash.dat',$PerNeuronHPDetailedCount);

	EasyDump('../data/debug/neuronDASimpleHash.dat',$PerNeuronDAHash);
	EasyDump('../data/debug/neuronGOSimpleHash.dat',$PerNeuronGOHash);
	EasyDump('../data/debug/neuronDOSimpleHash.dat',$PerNeuronDOHash);
	EasyDump('../data/debug/neuronHPSimpleHash.dat',$PerNeuronHPHash);
	
	my $samsize = total_size($PerNeuronDADetailedCount)/1024**2;
	print "DA Hash occupies for samples ".$samsize." MB \n";
	$samsize = total_size($PerNeuronGODetailedCount)/1024**2;
	print "GO Hash occupies for samples ".$samsize." MB \n";
	$samsize = total_size($PerNeuronDODetailedCount)/1024**2;
	print "DO Hash occupies for samples ".$samsize." MB \n";
	$samsize = total_size($PerNeuronHPDetailedCount)/1024**2;
	print "HP Hash occupies for samples ".$samsize." MB \n";
	
}
#A little debug information regarding sizes of hashes

enrichment_output("../data/Enrichment/PerNeuron.DA.Enrichement.txt",$PerNeuronDADetailedCount,$PerSampDA_idf,$DATerms);
enrichment_output("../data/Enrichment/PerNeuron.GO.Enrichement.txt",$PerNeuronGODetailedCount,$PerSampGO_idf,$GOTerms,$GO_detailed);
enrichment_output("../data/Enrichment/PerNeuron.DO.Enrichement.txt",$PerNeuronDODetailedCount,$PerSampDO_idf,$DOTerms,$PO_detailed);
enrichment_output("../data/Enrichment/PerNeuron.HP.Enrichement.txt",$PerNeuronHPDetailedCount,$PerSampHP_idf,$HPTerms,$PO_detailed);

###################### STOP IT AND TIDY UP

my $TotalToc = Time::HiRes::time;
my $TotalTimeTaken = ($TotalToc - $TotalTic);
say STDERR "Total Time Taken:".$TotalTimeTaken if($verbose);

dbDisconnect($dbh);


__END__


