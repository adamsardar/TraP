#!/usr/bin/env perl

use strict;
use warnings;

=head1 NAME

skeleton v1.0 - testing script for the TissueMRCA.pm module

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
use lib qw'../../lib';
use Statistics::Descriptive;
use TraP::SQL::TissueMRCA qw/:all/;
use Supfam::Utils qw/:all/;

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

#Print out some help if it was asked for or if no arguments were given.
#pod2usage(-exitstatus => 0, -verbose => 2) if not @files or $help;

=head1 FUNCTIONS DEFINED

=over 4

=cut

=item * func
Function to do something
=cut
sub func {
    my @input = @_;
	return "@input\n";
}

# Main Script Content
#-------------------------------------------------------------------------------

#Lets just echo back the argument list
print "Verbose!\n" if $verbose;
print "More verbose\n" if $debug;


my $Genomes = [qw(hs mm )];

my ($DistanceFromReference,$NCBIPlacement) = calculate_MRCA_NCBI_placement($Genomes);

#print $taxon_id."\n";
#print $name."\n";
#print $rank."\n";

my $Trait2GenomesHash = {};
$Trait2GenomesHash->{"Trait"}=$Genomes;
$Trait2GenomesHash->{"Awesome"} = [qw(hs dg mm dh)];

my $SF2Genomes = supra_genomes([qw(30561)]);


#print Dumper $SF2Genomes;
#$SF2Genomes->{'test'}=[qw(mm xp)];


my ($Supra2TreeDataHash,$Supra2NCBIplacement) = calculateMRCAstats($SF2Genomes,'hs');

EasyDump('Dump.out',$Supra2NCBIplacement);


1;

__END__


