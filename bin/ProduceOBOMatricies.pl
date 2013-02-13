#!/usr/bin/env perl

use Modern::Perl;

=head1 NAME

ProduceOBOMatricies.pl

=head1 SYNOPSIS

ProduceOBOMatricies.pl [options] <file>...

 Basic Options:
  -t --terms File listing all the terms to study
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

ProduceOBOMatricies.pl -t TermFiles

=head1 AUTHOR

B<Adam Sardar> - I<Adam.Sardar@bristol.ac.uk>

=over 4

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
my $terms;
my $out = 'Outfile.dat';

#Set command line flags and parameters.
GetOptions("verbose|v!"  => \$verbose,
           "debug|d!"  => \$debug,
           "help|h!" => \$help,
           "terms|t=s" => \$terms,
           "out|o=s" => \$out,
        ) or die "Fatal Error: Problem parsing command-line ".$!;

#Get other command line arguments that weren't optional flags.
my @files= @ARGV;

#Print out some help if it was asked for or if no arguments were given.
pod2usage(-exitstatus => 0, -verbose => 2) if not @files or $help;

#Main Script Content
#-------------------------------------------------------------------------------

my @Terms;

open TERMS, "<$terms" or die $!."\t".$?;

while (my $line = <TERMS>){
	
	chomp($line);
	push(@Terms,$line);
}

close TERMS;

my $TermHashMaster = {};
map{$TermHashMaster->{$_} = 0}@Terms;

open OUT,">$out " or die $!."\t".$?;

print OUT join("\t",@Terms);
print OUT "\n";


#Process each file passed in and create a line of output
foreach my $file (@files){
	
	my $TermHashCopy = {};
	%$TermHashCopy = %$TermHashMaster;
	#Use a hash to store terms in the master hash
	
	#Grab all terms
	open FH,"<$file" or die $!."\t".$?;
	
	while (my $term = <FH>){
		
		chomp($term);
		$TermHashCopy->{$term}=1 if exists($TermHashCopy->{$term});
	}
	
	close FH;
	
	#Print to an outfile
	print OUT $file."\t";
	print OUT join("\t",@{$TermHashCopy}{@Terms});
	print OUT "\n";
}

close OUT;


=pod

=back

=head1 TODO

=over 4

=item Edit this file removing all the default skeleton.pl comments!

=back

=cut

1;

__END__

