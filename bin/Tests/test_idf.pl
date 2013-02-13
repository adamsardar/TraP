#!/usr/bin/env perl

use strict;
use warnings;

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
use lib qw'../../lib';
use TraP::Topic::TFIDF qw/:all/;
use Utils::SQL::Connect qw/:all/;
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

#Lets just echo back the argument list
print "Verbose!\n" if $verbose;
print "More verbose\n" if $debug;

my $DocumentHash={};
#Hash of structure $Hash->{DocumentName}=[list of potentially non-unque terms]

my $PerDocumentDetailedCount={};
#Hash of structure $Hash->{DocumentName}{term} = count

my ($dbh, $sth);
$dbh = dbConnect();

$sth =   $dbh->prepare( "SELECT snapshot_order_comb.comb_id,sample_index.sample_name
						FROM snapshot_order_comb
						JOIN sample_index
						ON snapshot_order_comb.sample_id = sample_index.sample_id
						AND snapshot_order_comb.comb_id != 1
						;"); 
$sth->execute();

while (my ($CombID,$samp_name) = $sth->fetchrow_array ) {
	
	$PerDocumentDetailedCount->{$samp_name}={} unless(exists($PerDocumentDetailedCount->{$samp_name}));
	$PerDocumentDetailedCount->{$samp_name}{$CombID}++;	
}


foreach my $doc (keys(%$PerDocumentDetailedCount)){
	
	$DocumentHash->{$doc}=[keys(%{$PerDocumentDetailedCount->{$doc}})];
}

EasyDump('./docDump.dat',$PerDocumentDetailedCount);

my $idf = idf_calc($DocumentHash);

EasyDump('./idfDump.dat',$idf);

my @Terms = keys(%$idf);
push(@Terms,"Bill");

my $tf = logtf_calc($PerDocumentDetailedCount,\@Terms);

EasyDump('./tfDump.dat',$tf);

dbDisconnect($dbh);

my $TotalToc = Time::HiRes::time;
my $TotalTimeTaken = ($TotalToc - $TotalTic);
say STDERR "Time Taken:".$TotalTimeTaken;

__END__


