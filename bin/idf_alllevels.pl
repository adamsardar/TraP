#!/usr/bin/env perl

use Modern::Perl;

=head1 NAME

test_TFIDF.pl

=head1 SYNOPSIS

skeleton [options] <file>...

 Basic Options:
  -h --help Get full man page output
  -v --verbose Verbose output with details of mutations
  -d --debug Debug output

=head1 DESCRIPTION

This program is part of the TraP Project suite.

=head1 EXAMPLES


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
use TraP::Topic::TFIDF qw/:all/;
use Utils::SQL::Connect qw/:all/;
use Supfam::Utils qw/:all/;
use Devel::Size qw(size total_size);

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



#TODO Go Term Analysis

##### GO terms #####

########## Per Sample ##########

########## Per Cluster ##########

########## Per Neuron ##########



#So just doing Da for the second, because it's an easier palce to start


##### DA terms #####

my ($dbh, $sth);
$dbh = dbConnect();


########## Per Sample ##########

my $PerSampleHash={};
#Hash of structure $Hash->{DocumentName}=[list of potentially non-unque terms]

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

while (my ($CombID,$samp_id,$sample_name) = $sth->fetchrow_array ) {
	
	$SampleID2NameDict->{$samp_id} = $sample_name unless(exists($SampleID2NameDict->{$samp_id}));
	
	$PerSampleDetailedCount->{$samp_id}={} unless(exists($PerSampleDetailedCount->{$samp_id}));
	$PerSampleDetailedCount->{$samp_id}{$CombID}++;	
}


foreach my $doc (keys(%$PerSampleDetailedCount)){
	
	$PerSampleHash->{$doc}=[keys(%{$PerSampleDetailedCount->{$doc}})];
}

my $PerSamp_idf = idf_calc($PerSampleHash);

my @Terms = keys(%$PerSamp_idf);

my $PerSamp_tf = logtf_calc($PerSampleDetailedCount,\@Terms);

#Output

mkdir("../data");
mkdir("../data/Enrichment");

open PERSAMDA, ">../data/Enrichment/PerSample.DA.TF_IDF.txt";

foreach my $sampid (keys(%$PerSampleDetailedCount)){
	
	foreach my $trait (keys(%{$PerSampleDetailedCount->{$sampid}})){
		
		my $sampnam = $SampleID2NameDict->{$sampid};
		my $tf = $PerSamp_tf->{$sampid}{$trait};
		my $idf = $PerSamp_idf->{$trait};
		my $tfidf_score = $tf*$idf;
		
		print PERSAMDA $sampnam."\t".$sampid."\t".$trait."\t".$tfidf_score."\n";
	}
}

close PERSAMDA;

my $samsize = total_size($PerSampleDetailedCount)/1024**2;

print "HAsh occupies".$samsize." MB \n";


($PerSamp_tf,$PerSamp_idf,$PerSampleHash,$PerSampleDetailedCount) = (undef,undef,undef,undef);
#Release memory back to the system

########## Per Cluster ##########

my $PerClusterHash={};
#Hash of structure $Hash->{DocumentName}=[list of potentially non-unque terms]

my $PerClusterDetailedCount={};
#Hash of structure $Hash->{DocumentName}{term} = count


$sth =   $dbh->prepare( "SELECT experiment_cluster.cluster_id,snapshot_order_comb.comb_id
						FROM snapshot_order_comb
						JOIN sample_index
						ON snapshot_order_comb.sample_id = sample_index.sample_id
						JOIN experiment_cluster
						WHERE snapshot_order_comb.comb_id != '1'
						;"); 
						
$sth->execute();

while (my ($CombID,$clus_id) = $sth->fetchrow_array ) {
	
	$PerClusterDetailedCount->{$clus_id}={} unless(exists($PerClusterDetailedCount->{$clus_id}));
	$PerClusterDetailedCount->{$clus_id}{$CombID}++;	
}


my $clussize = total_size($PerClusterDetailedCount)/1024**2;

print "HAsh occupies".$clussize." MB \n";


foreach my $doc (keys(%$PerClusterDetailedCount)){
	
	$PerClusterHash->{$doc}=[keys(%{$PerClusterDetailedCount->{$doc}})];
}

my $PerClus_idf = idf_calc($PerClusterHash);

@Terms = keys(%$PerSamp_idf);

my $PerClus_tf = logtf_calc($PerClusterDetailedCount,\@Terms);

#Output


open PERCLUSDA, ">../data/Enrichment/PerCluster.DA.TF_IDF.txt";

foreach my $sampnam (keys(%$PerClusterDetailedCount)){
	
	foreach my $trait (keys(%{$PerClusterDetailedCount->{$sampnam}})){
		
		my $tf = $PerClus_tf->{$sampnam}{$trait};
		my $idf = $PerClus_idf->{$trait};
		my $tfidf_score = $tf*$idf;
		
		print PERCLUSDA $sampnam."\t".$trait."\t".$tfidf_score."\n";
	}
}

close PERCLUSDA;



########## Per Neuron ##########



###################### TIDY UP


my $TotalToc = Time::HiRes::time;
my $TotalTimeTaken = ($TotalToc - $TotalTic);
say STDERR "Total Time Taken:".$TotalTimeTaken if($verbose);


dbDisconnect($dbh);

__END__


