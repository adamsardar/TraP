#!/usr/bin/env perl

use strict;
use warnings;

=head1 NAME

create_zvals_persample

=head1 SYNOPSIS

skeleton [options] <file>...

 Basic Options:
  -h --help Get full man page output
  -v --verbose Verbose output with details of mutations
  -d --debug Debug output

=head1 DESCRIPTION

This program is part of the TraP Project suite.

=head1 OPTIONS

=over 8

=item B<-h, --help>

Print this brief help message from the command line.

=item B<-d, --debug>

Print debug output showing how the text is being mutated with thesaurus usage.

=item B<-v, --verbose>

Verbose output showing how the text is changing.

=back

=head1 EXAMPLES

To get some help output do:

skeleton --help

To list the files in the current directory do:

skeleton *

=head1 AUTHOR

DELETE AS APPROPRIATE!

B<Matt Oates> - I<Matt.Oates@bristol.ac.uk>

B<Owen Rackham> - I<Owen.Rackham@bristol.ac.uk>

B<Adam Sardar> - I<Adam.Sardar@bristol.ac.uk>

=head1 NOTICE

DELETE AS APPROPRIATE!

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

use Getopt::Long; #Deal with command line options
use Pod::Usage;   #Print a usage man page from the POD comments
use Data::Dumper; #Allow easy print dumps of datastructures for debugging

use Utils::SQL::Connect qw/:all/;
use Supfam::Utils qw/:all/;


# Command Line Options
#-------------------------------------------------------------------------------
my $verbose; #Flag for verbose output from command line opts
my $debug;   #As above for debug
my $help;    #Same again but this time should we output the POD man page defined after __END__
my $SQLdump;

#Set command line flags and parameters.
GetOptions("verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
           "SQLdump|s!"  => \$SQLdump,
           "help|h!" => \$help,
        ) or die "Fatal Error: Problem parsing command-line ".$!;

#Get other command line arguments that weren't optional flags.
my @files= @ARGV;

#Print out some help if it was asked for or if no arguments were given.
pod2usage(-exitstatus => 0, -verbose => 2) if $help;


my ( $dbh, $sth );
$dbh = dbConnect();


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

foreach my $MRCA (keys(%proportion_of_architectures_per_epoch_per_sample)){
	
	my $TempHash = calc_ZScore($proportion_of_architectures_per_epoch_per_sample{$MRCA});
	$SampleZscoreHash->{$MRCA}=$TempHash;
	
	if($verbose){
		print STDOUT "Outputting Z score data and hists";
		
		mkdir("../data");
		open FH, ">../data/TaxonID.".$MRCA.".zscores.dat" or die $!.$?;
		print FH join("\n",values(%$TempHash));
		close FH;
	
		` Hist.py -f ../data/TaxonID.$MRCA.zscores.dat -o ../data/TaxonID.$MRCA.zscores.png -u 0` 
	}
}

EasyDump('../data/Zscores.dat',$SampleZscoreHash) if($verbose);

if($SQLdump){
	
	mkdir("../data");
	print STDOUT "Creating an SQL tab-sep compatable dump labelled: exp_id\tproportion\ttaxon_id\tepochsize\n";
	
	open SQL, ">SQLData.dat" or die $!.$?;
	
	foreach my $tax_id (keys(%$SampleZscoreHash)){
		
		foreach my $expid (keys(%{$SampleZscoreHash->{$tax_id}})){
			
			my $proportion = $SampleZscoreHash->{$tax_id}{$expid};
			my $epoch_size;
			
			if(exists($distinct_architectures_per_epoch_per_sample{$tax_id}{$expid})){
				
				$epoch_size = $distinct_architectures_per_epoch_per_sample{$tax_id}{$expid};
			}else{
				$epoch_size = 0;
			}
			
			print SQL $expid."\t".$proportion."\t".$tax_id."\t".$epoch_size."\n";
		}		
	}
	
	close SQL;
}

=head1 TODO

=over 4

=item Edit this file removing all the default skeleton.pl comments!

=back

=cut

1;

__END__

