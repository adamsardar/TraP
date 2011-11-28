#!/usr/bin/env perl

package TraP::Topic::TFIDF;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = (
'all' => [ qw(
			tfidf
			tfidf_sf_proteins
) ],
);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

our $VERSION   = 1.00;

use strict;
use warnings;

=head1 NAME

TraP::Topic::TFIDF v1.0 - Module to calculate Term Frequency v Inverse Document Frequency topic weightings

=head1 DESCRIPTION

This module has been released as part of the TraP Project code base.

Module to calculate TFIDF weightings for all input.

=head1 EXAMPLES

use TraP::Topic::TFIDF qw/tfidf/;

=head1 AUTHOR

B<Matt Oates> - I<Matt.Oates@bristol.ac.uk>

=head1 NOTICE

B<Matt Oates> (2011) First features added.

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


#use lib '~/lib';

=head1 DEPENDANCY

B<Data::Dumper> Used for debug output.

=cut
use Data::Dumper; #Allow easy print dumps of datastructures for debugging



=head1 FUNCTIONS DEFINED

=over 4
=cut

=item * tfidf
Function to do something
=cut
sub tfidif {
    my ($var) = @_;
	return 1;
}

=item * tfidf_sf_proteins
Function to do something
=cut
sub tfidf_sf_proteins {
    use Supfam::SQLFunc qw/topic/;
    my ($proteins) = @_;
    if (ref $proteins eq "ARRAY") {
        foreach my $protein (@$proteins) {
            
        }
    }
    else {
    
    }
	return 2;
}

=pod

=back

=head1 TODO

=over 4

=item Add feature here...

=back

=cut

1;
__END__

