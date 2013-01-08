#!/usr/bin/env perl

use Modern::Perl;

=head1 NAME

dendrogramMatricies4R.pl

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
pod2usage(-exitstatus => 0, -verbose => 2) if not @files or $help;

=head1 FUNCTIONS DEFINED

=over 4

=cut

=item * func
Function to do something
=cut

# Main Script Content
#-------------------------------------------------------------------------------

my @TaxonIDOrder = qw(9606 32525 40674 32524 117571 7711 33511 33316 33213 6072 33154 2759 131567);

foreach my $file (@files){
	
	open FH,"<$file" or die $!."\t".$?;
	
	my $MatrixHash = {};
	
	undef = <FH>;
	#First line is a tonne of guff	
	
	while (my $line  = <FH>){
		
		chomp $line;
		my ($unit_id,$taxon_id,$Z_scor_av) = split(/\t/,$line);
		
		$MatrixHash->{$unit_id}={} unless(exists($MatrixHash->{$unit_id}));
		$MatrixHash->{$unit_id}{$taxon_id}=$Z_scor_av;
	}
	
	close FH;	
	
	open OUT, "$file.mat" or die $!."\t".$?;
	print OUT join("\t",@TaxonIDOrder);
	
	foreach my $unit (keys(%$MatrixHash)){
		
		print OUT $unit."\t";
		print OUT join("\t",@{$MatrixHash->{$unit}}{@TaxonIDOrder});
		print OUT "\n";	
	}
	
	
	close OUT;
	
}



=pod

=back

=head1 TODO

=over 4

=item Edit this file removing all the default skeleton.pl comments!

=back

=cut

1;

__END__

