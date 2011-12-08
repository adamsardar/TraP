package Supfam::DataVisualisation;
require Exporter;

=head1 NAME

Supfam::DataVisualisation

=head1 SYNOPSIS

Functions for outputting data as JSON objects and interacting with plotting libraries such as Protovis, d3.js and highcharts.js 
use Supfam::DataVisualisation;

=head1 AUTHORS

Adam Sardar (adam.sardar@bris.ac.uk)
Owen Rackham (owen.rackham@bristol.ac.uk)
Matt Oates (matt.oates@bristol.ac.uk)

=head1 COPYRIGHT

Copyright 2011 Gough Group, University of Bristol.

=head1 SEE ALSO

JSON::XS

=head1 DESCRIPTION

=cut

our @ISA       = qw(Exporter AutoLoader);
our @EXPORT    = qw(
					convertHash2JSONMatrix
                  );
our @EXPORT_OK = qw();
our $VERSION   = 1.00;

use strict;
use warnings;

use JSON::XS;

sub convertHash2JSONMatrix{

	my ($HashRef,$PrimaryIndexLabel) = @_;
	
	my $PrimaryIndexFlag = (@_ < 2)?1:0;
	$PrimaryIndexLabel = 'Entry' unless($PrimaryIndexFlag);
		
	my $Matrix = []; #This will be a 2D array containing records. $Matrix[0] = [PrimaryIndexLabel, key1, key2, key3, ...], while $Matrix[>0] = [PrimaryIndex1, val1, val2, val3, ...] - where the key-value pairs are drawn from the input hash
	
	my @PrimaryIndicies=keys(%$HashRef);
	my @DataLabels = keys(%{$HashRef->{$PrimaryIndicies[0]}}); #Assume that all data values have the same data labels $hash->{PrimaryIndex}={key1 => val1, key2 => val2, key3 => val3, ... } 
	
	$Matrix->[0]=[($PrimaryIndexLabel,@DataLabels)]; #Set up the first row of the output array so as to contain all the right labels etc.

	foreach my $DataEntry (@PrimaryIndicies){
		
		my $DataEntryRow=[($DataEntry,@{$HashRef->{$DataEntry}}{@DataLabels})];
		push(@$Matrix,$DataEntryRow);
	}
	
	my $utf8_encoded_json_text = JSON::XS->new->utf8->indent->encode ($Matrix);
	
	return($utf8_encoded_json_text);
}

=pod
=item * convertHash2JSON( HashRef, PrimaryIndexLabel(opt))
Given a hashref of $hash->{PrimaryIndex}={key1 => val1, key2 => val2, key3 => val3, ... } this function will return JSON
of the form:
var object =[
[PrimaryIndexLabel, key1, key2, key3, ...]
[PrimaryIndex1, val1, val2, val3, ...]
[PrimaryIndex2, val1, val2, val3, ...]
...
];
This is acheived internally by creating a 2D array as a perl data structure and then outputting to JSON via the JSON::XS CPAN module.

PrimaryIndexLabel should be simply a descriptive name of the data labels. If left out, then 'Entry' will be used instead.
=cut


1;