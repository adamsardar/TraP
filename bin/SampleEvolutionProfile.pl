#!/usr/bin/env perl

use strict;
use warnings;

=head1 NAME

A script to extract the evolution profile of an experiment from the TraP database. This will be dumped out as a simple tab seperated file.

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
use lib qw'../lib/TraP';

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
use DBI;

use Utils::SQL::Connect qw/:all/;
use List::Util qw(sum max);


# Command Line Options
#-------------------------------------------------------------------------------
my $verbose; #Flag for verbose output from command line opts
my $debug;   #As above for debug
my $help;    #Same again but this time should we output the POD man page defined after __END__
my $cell_line_type;   #Same again but this time should we output the POD man page defined after __END__

#Set command line flags and parameters.
GetOptions("verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
           "help|h!" => \$help,
           "cell|c=s" => \$cell_line_type,
        ) or die "Fatal Error: Problem parsing command-line ".$!;

#Print out some help if it was asked for or if no arguments were given.
pod2usage(-exitstatus => 0, -verbose => 2) if $help;


# Main Script Content
#-------------------------------------------------------------------------------

#Lets just echo back the argument list
print "Verbose!\n" if $verbose;
print "More verbose\n" if $debug;

my $dbh = dbConnect('trap');

my $sth = $dbh->prepare("
	SELECT a.distance,common_taxa_names.name, COUNT(snapshot_order_supra.supra_id)
	FROM snapshot_order_supra JOIN experiment ON experiment.experiment_id = snapshot_order_supra.experiment_id 
	JOIN (select distinct(taxon_id),distance 
		from `snapshot_evolution`)
		AS a 
	ON a.taxon_id = snapshot_order_supra.taxon_id
	JOIN common_taxa_names ON common_taxa_names.taxon_id = a.taxon_id 
	JOIN cell_snapshot ON cell_snapshot.experiment_id = experiment.experiment_id
	WHERE experiment.sample_name LIKE '%$cell_line_type%'
	AND cell_snapshot.update_number = 7
	GROUP BY a.taxon_id 
	ORDER BY a.distance asc;
");
#Extracts the number of DA for the experimet of interest at each time epoch - also, extract the distance in time from hs genome (homosapien)

$sth->execute();


my $CellTypeEpoch2DANumber = {};
my $DistanceFromhs = {};

while (my ($distancefromhs,$common_name, $supra_count) = $sth->fetchrow_array()){
	
	$CellTypeEpoch2DANumber->{$common_name}=$supra_count;
	$DistanceFromhs->{$common_name}=$distancefromhs;
}

print STDERR "Finished with cell sample data. Extracting background data now\n";

# Extract a background of number of supra ids on average expressed at epochs

$sth = $dbh->prepare("
	SELECT common_taxa_names.name,COUNT(snapshot_order_supra.supra_id),experiment.experiment_id
	FROM snapshot_order_supra JOIN experiment ON experiment.experiment_id = snapshot_order_supra.experiment_id 
	JOIN common_taxa_names ON common_taxa_names.taxon_id = snapshot_order_supra.taxon_id
	JOIN cell_snapshot ON cell_snapshot.experiment_id = experiment.experiment_id
	WHERE cell_snapshot.update_number = 7
	GROUP BY experiment.experiment_id;
");
#Extracts the number of DA per experiment at each time epoch - we shall use this to construct a background

$sth->execute();

my $BackgroundEpochCombNumber = {};

while (my ($common_name,$supra_count,$exp_id) = $sth->fetchrow_array()){
	
	$BackgroundEpochCombNumber->{$common_name}=[] unless(exists($BackgroundEpochCombNumber->{$common_name}));	
	push(@{$BackgroundEpochCombNumber->{$common_name}},$supra_count);
}

#We shall compare this against two types of background - one being the average of each time point and the other being the max value at each time point

my $AverageBackgroundEpochCount = {};

foreach my $epoch (keys(%$BackgroundEpochCombNumber)){
	
	my $meanatepoch = sum(@{$BackgroundEpochCombNumber->{$epoch}})/scalar(@{$BackgroundEpochCombNumber->{$epoch}});
	$AverageBackgroundEpochCount->{$epoch} = $meanatepoch;
}

my $MaxBackgroundEpochCount = {};

foreach my $epoch (keys(%$BackgroundEpochCombNumber)){
	
	my $meanatepoch = max(@{$BackgroundEpochCombNumber->{$epoch}});
	$MaxBackgroundEpochCount->{$epoch} = $meanatepoch;
}

# Normalise 

my $MaxBackroundNormalised = {};
my $AverageNormalisedBAckground ={};

foreach my $epoch (keys(%$BackgroundEpochCombNumber)){
	
	$MaxBackroundNormalised->{$epoch} = ($CellTypeEpoch2DANumber->{$epoch})/($MaxBackgroundEpochCount->{$epoch});
	$AverageNormalisedBAckground->{$epoch} = 0 if ($AverageNormalisedBAckground->{$epoch} ~~ 0);
	next if ($AverageNormalisedBAckground->{$epoch} ~~ 0);
	next unless (exists($AverageNormalisedBAckground->{$epoch} ));
	$AverageNormalisedBAckground->{$epoch} = ($CellTypeEpoch2DANumber->{$epoch})/($AverageNormalisedBAckground->{$epoch});
}


open TABOUT, ">./Normalised_$cell_line_type.dat" or die $!.$?;

print TABOUT "Epoch:\t";
print TABOUT "Raw Number Of Combs At Epoch:\t";
print TABOUT "Normalised By Average Number of DAs Across All Samples:\t";
print TABOUT "Normalised By Max Number of DAs Across All Samples:\t";
print TABOUT "\n";

foreach my $epoch (sort { $DistanceFromhs->{$b} <=> $DistanceFromhs->{$a} } keys(%$CellTypeEpoch2DANumber)) {

	print TABOUT $epoch."\t";
	print TABOUT $CellTypeEpoch2DANumber->{$epoch}."\t";
	print TABOUT $MaxBackroundNormalised->{$epoch}."\t";
	print TABOUT $AverageNormalisedBAckground->{$epoch}."\t";
	print TABOUT "\n";
}

close TABOUT;

=pod

=back

=head1 TODO

=over 4

=item Edit this file removing all the default skeleton.pl comments!

=back

=cut

1;

__END__

