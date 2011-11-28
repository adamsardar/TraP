#!/usr/bin/env perl

package Supfam::Utils;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = (
'all' => [ qw(
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

B<Data::Dumper> Used for debug output.

=cut
use Data::Dumper; #Allow easy print dumps of datastructures for debugging

=head1 FUNCTIONS DEFINED

=over 4
=cut

=item B<lcp_regi(@)> - I<Find the longest common prefix of a list of strings ignoring case.>
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

=item B<lcp(@)> - I<Strictly find the longest common prefix string, sensitive to case and white space.>
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

=item Nothing

=back

=cut

1;

__END__

