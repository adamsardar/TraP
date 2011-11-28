#!/usr/bin/env perl

package Supfam::Utils;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = (
'all' => [ qw(
	EasyDump
	EasyUnDump
	IntUnDiff
	TabSepFile
	CommaSepFile
	lcp
	lcp_regi
) ],
'lcp' => [ qw(
	lcp
	lcp_regi
) ],
);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

our $VERSION   = 1.00;

use strict;
use warnings;

=head1 NAME

Supfam::Utils v1.0 - Utility functions for basic string/list operations etc.

=head1 DESCRIPTION

This module has been released as part of the Supfam Project code base.

Basic string and data structure manipulation code.

=head1 EXAMPLES

#Uce longest common prefix functions
use Supfam::Utils qw/lcp/;

=head1 AUTHOR

B<Matt Oates> - I<Matt.Oates@bristol.ac.uk>

=head1 NOTICE

B<Matt Oates> (2011) Longest common prefix string functions.

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

=head1 DEPENDANCY

Supfam Dependancies:

=over 4

B<Supfam::SQLFunc>

=back

CPAN Dependancies:

=over 4

=item B<Data::Dumper> Used for debug output.

=item B<Term::ProgressBar> 

=item B<Math::Combinatorics>

=back

=cut
use Data::Dumper; #Allow easy print dumps of datastructures for debugging
use Term::ProgressBar;
use Math::Combinatorics;
use Supfam::SQLFunc;

=head1 FUNCTIONS DEFINED

=over 4
=cut

=item * B<EasyDump(FileName, Pointer)>
A wrapper function for the dumper module. Pass in the desired file name and a pointer to the object to be outputted. Does not return.
=cut
sub EasyDump($$){
	my ($FileName,$Pointer) = @_;
	
	open FH, ">".$FileName or die "Unable to initalise File Handle";
	print FH Dumper($Pointer);
	close FH;
}


=item * B<EasyUnDump($)>
A wrapper function for the dumper module. Given a file produced using dumper, this function will return a pointer to the structure in memory.
=cut
sub EasyUnDump($){
	my ($FileName) = shift();
	
	open FH , "<".$FileName or die "Couldn't open $FileName: $!";
	my $FileDump;
	
		while (my $line = <FH>){
			$FileDump .= $line;
		}
	close FH;
	
	my $VAR1;
	eval($FileDump);
	return($VAR1)
}

=item * B<IntUnDiff($$)>
A quick function to calculate some basic set statistics between two lists (supplied as pointers to two arrays in). Returns four
pointers to arrays of the 1. Union 2. Intersection 3. Elements unique to list A 4. Elements uniqur to list B.
=cut
sub IntUnDiff($$){
	
	my ($ListA,$ListB) = @_;
	
	my $switch = 0;
	#A flag for if the two lists are flipped around in the next step. This allows for correct reporting of the return values
	
	if (scalar(@$ListA) > scalar(@$ListB)){
		my $TempList = $ListA;
		$ListA = $ListB;
		$ListB = $TempList;
		$switch=1;
	}
	# This is to make sure that the code runs efficiently, which requires ListA to be the smaller of the two lists.
	
	my $UnionHash = {};
	my $Union = [];
	my $Intersection = [];
	my $ListAExclusive = [];
	my $ListBExclusive = [];
	
	my $ListALookup={};
	
	foreach(@$ListA){$ListALookup->{$_} = 1;}
	#Initialise a hash for lookup later
	
	foreach my $element (@$ListA, @$ListB) { $UnionHash->{$element}++; } 
	
	@$Union = keys(%$UnionHash);
	
	 foreach my $element (@$Union) {     
	 	   
	 	 if ($UnionHash->{$element} == 2) {  #i.e if it's in both sets      
	 	 	 push (@$Intersection, $element);     
	 	 } else {     
	 	 	no warnings 'uninitialized';
	 	 	#This is to stop Perl moaning about elements not beining initialised in the lookup hash below
	 	 
	 	 	if ($ListALookup->{$element}){
	 	 		push(@$ListAExclusive, $element);   
	 	 	}else {
	 	 		push(@$ListBExclusive, $element); 
	 	 	}
	 	 } 
	 }
	
	unless ($switch) {return($Union,$Intersection,$ListAExclusive,$ListBExclusive);
	}else {			return($Union,$Intersection,$ListBExclusive,$ListAExclusive);
	};
}


=item * B<TabSepFile($Fields,$OutputData,$fileout,$totals -optional,$defualtvalue - optional)>

An easy way to dump a whole load of Entry=>{field1 =>val1, field2 => val2 ...} data to a tab seperated file. First line of output is a list of fields (as specieifed in @$Fields), followed by a line per key in
%$OutputData. Only fields in @$Fields are outputted. $Output data = {row titles => {field1 => val1, field2 => va2 ...}}. For fields not included in the OutputData hash, $defualtvalue will be assumed to be the value

File save to $fileout

=cut
sub TabSepFile{
	
	my ($Fields,$OutputData,$fileout,$totals,$defualtvalue) = @_;

	$defualtvalue = 'N/A' unless defined($defualtvalue);
	
	# $fields = [field headings]
	# $Output data = {row titles => {field1 => val1, field2 => va2 ...}}. For fields not included in the OutputData hash, $defualtvalue will be assumed to be the value
	#$totals = {field1 = total_val1, field2 => total_val2 ...}
	
	open TABOUTPUT, ">$fileout" or die "Failed to open output tab file.";
	
	print TABOUTPUT "Entry\t";
	print TABOUTPUT join("\t",@$Fields);
	print TABOUTPUT "\n";
	
	if(defined($totals)){
		
		my @FieldValues = @{$totals}{@$Fields}; #Only retrieve the values for which there are fields in @$Fields
		
		print TABOUTPUT "Field_Sum\t";
		print TABOUTPUT join("\t",@FieldValues);
		print TABOUTPUT "\n";
	}
	
	my $FieldsHash = {};
	map{$FieldsHash->{$_}=$defualtvalue}@$Fields;
	#Initialise a hash with default values
	
	foreach my $Entry (keys(%$OutputData)){
	
		my $EntrySpecificFieldHash ={};
		%$EntrySpecificFieldHash = %$FieldsHash ;
		
		@{$EntrySpecificFieldHash}{keys(%{$OutputData->{$Entry}})}=values(%{$OutputData->{$Entry}}); #update entry specific hash using a hash slice
		
		my @FieldValues = @{$EntrySpecificFieldHash}{@$Fields}; #Only retrieve the values for which there are fields in @$Fields

		print TABOUTPUT "$Entry\t";
		print TABOUTPUT join("\t",@FieldValues);
		print TABOUTPUT "\n";
	}
	
	close TABOUTPUT or die "Failed to close tab file.";

	return(1);
	
}


=item * B<CommaSepFile($Fields,$OutputData,$fileout,$totals -optional,$defualtvalue - optional)>

An easy way to dump a whole load of Entry=>{field1 =>val1, field2 => val2 ...} data to a c seperated file. First line of output is a list of fields (as specieifed in @$Fields), followed by a line per key in
%$OutputData. Only fields in @$Fields are outputted. $Output data = {row titles => {field1 => val1, field2 => va2 ...}}. For fields not included in the OutputData hash, $defualtvalue will be assumed to be the value

File save to $fileout

=cut
sub CommaSepFile{
	
	my ($Fields,$OutputData,$fileout,$totals,$defualtvalue) = @_;
	
	$defualtvalue = 'N/A' unless defined($defualtvalue);
	
	# $fields = [field headings]
	# $Output data = {row titles => {field1 => val1, field2 => va2 ...}}. For fields not included in the OutputData hash, $defualtvalue will be assumed to be the value
	#$totals = {field1 = total_val1, field2 => total_val2 ...}
	
	
	open COMMAOUTPUT, ">$fileout" or die "Failed to open comma output.";
		
	print COMMAOUTPUT "Entry,";
	print COMMAOUTPUT join(",",@$Fields);
	print COMMAOUTPUT "\n";
	
	
	if(defined($totals)){
		
		my @FieldValues = @{$totals}{@$Fields}; #Only retrieve the values for which there are fields in @$Fields
		
		print COMMAOUTPUT "Field_Sum,";
		print COMMAOUTPUT join(",",@FieldValues);
		print COMMAOUTPUT "\n";
	}
	
	
	my $FieldsHash = {};
	map{$FieldsHash->{$_}=$defualtvalue}@$Fields;
	
	foreach my $Entry (keys(%$OutputData)){
	
		my $EntrySpecificFieldHash ={};
		%$EntrySpecificFieldHash = %$FieldsHash ;
		
		@{$EntrySpecificFieldHash}{keys(%{$OutputData->{$Entry}})}=values(%{$OutputData->{$Entry}}); #update entry specific hash using a hash slice
		
		my @FieldValues = @{$EntrySpecificFieldHash}{@$Fields}; #Only retrieve the values for which there are fields in @$Fields
		
		print COMMAOUTPUT "$Entry,";
		print COMMAOUTPUT join(",",@FieldValues);
		print COMMAOUTPUT "\n";
	}
	
	close COMMAOUTPUT or die "Failed to close comma output file.";
}


=item * B<lcp_regi(@)> - I<Find the longest common prefix of a list of strings ignoring case.>
=cut
sub lcp_regi(@) {
	#Use the first string as our assumed prefix to start.
	my $prefix = shift;
	#For every remaining string in the list chop down the prefix until it matches.
	for (@_) {
		return '' if $prefix eq '';
		chop $prefix while (! /^\Q$prefix/i); 
	}
	#If $prefix isn't the empty '' then it's by definition the longest common prefix. 
	return $prefix;
}

=item * B<lcp(@)> - I<Strictly find the longest common prefix string, sensitive to case and white space.>
=cut
sub lcp(@) {
	#Take the first string as our initial prefix estimate.
	my $prefix = shift;
	
	#Compare over all strings in the list.
	for (@_) {
		#If we have already determined there is no common prefix return.
		return '' if $prefix eq '';
		#Reduce the prefix until it matches against the current string.
		chop $prefix while ( $prefix ne substr $_, 0, length $prefix );
	}
	
	return $prefix;
}

=pod

=back

=head1 TODO

=over 4

=item Possibly clean up some of these function names to look less like classes...

=back

=cut

1;

__END__


