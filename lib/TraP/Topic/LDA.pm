#!/usr/bin/env perl

package TraP::Topic::LDA;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = (
'all' => [ qw(
			lda
) ],
);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

our $VERSION   = 1.00;

use strict;
use warnings;

=head1 NAME

TraP::Topic::LDA v1.0 - Module to perform Latent Dirichlet topic allocation.

=head1 DESCRIPTION

This module has been released as part of the TraP Project code base.

Output topic weightings for given input.

=head1 EXAMPLES

use TraP::Topic::LDA qw/lda/;

my $topics = lda();

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

=head1 DEPENDANCY

B<Data::Dumper> Used for debug output.

=cut
use Data::Dumper; #Allow easy print dumps of datastructures for debugging



=head1 FUNCTIONS DEFINED

=over 4
=cut

=item * lda
Function to calculate Latent Dirichelet allocated topics
=cut
sub lda {
    my ($var) = @_;
	return 1;
}

=pod

=back

=head1 TODO

=over 4

=item Implement LDA

=back

=cut

1;
__END__

