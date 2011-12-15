#!/usr/bin/env perl

package TraP::Skeleton;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = (
'all' => [ qw(
			sub1
			sub2
) ],
'yourtag' => [ qw(
			sub1
) ],
);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

our $VERSION   = 1.00;

use strict;
use warnings;

=head1 NAME

TraP::Skeleton v1.0 - Skeleton module for the TraP project

=head1 DESCRIPTION

This module has been released as part of the TraP Project code base.

Just a skeleton layout for each module to start from.

=head1 EXAMPLES

use TraP::Skeleton qw/all/;

=head1 AUTHOR

DELETE AS APPROPRIATE!

B<Matt Oates> - I<Matt.Oates@bristol.ac.uk>

B<Owen Rackham> - I<Owen.Rackham@bristol.ac.uk>

B<Adam Sardar> - I<Adam.Sardar@bristol.ac.uk>

=head1 NOTICE

DELETE AS APPROPRIATE!

B<Matt Oates> (2011) First features added.

B<Owen Rackham> (2011) First features added.

B<Adam Sardar> (2011) First features added.

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

=item * sub1
Function to do something
=cut
sub sub1 {
    my ($var) = @_;
	return 1;
}

=item * sub2
For a given sampleID this returns an array of disitinct sfs that are expressed in that sample
=cut
sub cell_sfs {

my $sample = shift;
my @sfs;
my ($dbh, $sth);
$dbh = DBConnect;

$sth =   $dbh->prepare( "select distinct(superfamily.ass.sf) from trap.cell_snapshot, trap.id_mapping, superfamily.ass where trap.cell_snapshot.gene_id = trap.id_mapping.entrez and trap.id_mapping.protein = superfamily.ass.protein and trap.cell_snapshot.experiment_id = '$sample';" );
        	$sth->execute;
        	while (my @temp = $sth->fetchrow_array ) {
				push @sfs, $temp[0];
        	}
return \@sfs;
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

