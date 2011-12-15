#!/usr/bin/env perl

package TraP::SQL::TissueMRCA;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = (
'all' => [ qw(
                human_cell_type_experiments
		experiment_sfs
		sf_genomes	
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

=head1 DEPENDANCY

B<Data::Dumper> Used for debug output.

=cut
use lib '../../';
use Utils::SQL::Connect qw/:all/;
use Data::Dumper; #Allow easy print dumps of datastructures for debugging



=head1 FUNCTIONS DEFINED

=over 4
=cut

=item * human_cell_type_experiments
Function to get all the human cell type experiment ids
=cut
sub human_cell_type_experiments {
	my @ids = ();
	my $dbh = dbConnect('trap');
	my $sth = $dbh->prepare('select experiment_id from experiment where source_id = ?');
	$sth->execute(1);
	my $results = $sth->fetchall_arrayref();
	dbDisconnect($dbh);
	return $results->[0];
}

=item * sf_genomes
Function to find all the genomes a superfamily occurs in
=cut
sub sf_genomes {
    my ($sf) = @_;
    my %genomes;
    my $dbh = dbConnect('superfamily');
    my $sth = $dbh->prepare('select distinct(genome) from protein, ass where protein.protein = ass.protein and ass.sf = ?');
    foreach my $id (@$sf) {
        $sth->execute($id);
        while ( my ($genome) = $sth->fetchrow_array() ) {
            $genomes{$genome} = undef;
        }
    }
return [keys %genomes];
}

=item * experiment_sfs
For a given sampleID this returns an array of disitinct sfs that are expressed in that experiment
=cut
sub experiment_sfs {

my $sample = shift;
my @sfs;
my ($dbh, $sth);
$dbh = dbConnect();

$sth =   $dbh->prepare( "select distinct(superfamily.ass.sf) from trap.cell_snapshot, trap.id_mapping, superfamily.ass where trap.cell_snapshot.gene_id = trap.id_mapping.entrez and trap.id_mapping.protein = superfamily.ass.protein and trap.cell_snapshot.experiment_id = '$sample';" );
        	$sth->execute;
        	while (my ($sf) = $sth->fetchrow_array ) {
				push @sfs, $sf;
        	}
dbDisconnect($dbh);
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

