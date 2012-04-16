#!/usr/bin/env perl

use strict;
use warnings;

=head1 NAME

create_evo_matrix_for_MATLAB takes data from a csv pulled from the database of the 
snapshot_evolution table and then reformats it into a matrix so that the hierachical
clustering can be run on it.x


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
sub create_matrix {
    my $input_file = shift;
	open FILE,"<$input_file";
	my %matrix;
	my %cols;
	my %rows;
	
	while (<FILE>){
		my @data = split(/,/,$_);
		$matrix{$data[1]}{$data[6]} = $data[3];
		$cols{$data[1]} = 1;
		$rows{$data[6]} = 1;
	}
	open COLS,'>../../data/cols.tab';
	foreach my $c (sort keys %cols){
		print COLS "$c\n";
	}
	
	open ROWS,'>../../data/rows.tab';
	foreach my $r (sort keys %rows){
		print ROWS "$r\n";
	}
	
	open MATRIX,'>../../data/matrix.tab';
	foreach my $c (sort keys %cols){
		foreach my $r (sort keys %rows){
			if(exists($matrix{$c}{$r})){
				print MATRIX "$matrix{$c}{$r}\t";
			}else{
				print MATRIX "0\t";
			}
		}
		print MATRIX "\n";
	}
	
	
	
}

sub index_cols{
	open FILE,"<$input_file";
	my %matrix;
	my %cols;
	my %rows;
	my $i = 1;
	my $j = 1;
	while (<FILE>){
		my @data = split(/,/,$_);
		unless(exists($data[0])){
			$cols{$data[0]} = $i++;
		}
		unless(exists($data[1])){
			$rows{$data[1]} = $j++;
		}
		print "$cols{$data[0]}\t$rows{$data[1]}\t$data[2]\n";
	}
	
}



# Main Script Content
#-------------------------------------------------------------------------------

#Lets just echo back the argument list
my $file = $ARGV[0];
print index_cols($file);



=pod

=back

=head1 TODO

=over 4

=item Edit this file removing all the default skeleton.pl comments!

=back

=cut

1;

__END__

