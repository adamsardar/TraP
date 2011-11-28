package Supfam::DomainCombs;
require Exporter;

=head1 NAME

Supfam::DomainCombs.pm

=head1 SYNOPSIS

Package for investigating SUPERFAMILY domain combinations.

=head1 AUTHOR

Matt Oates (Matt.Oates@bristol.ac.uk)

=head1 COPYRIGHT

Copyright 2010 Gough Group, University of Bristol.

=head1 SEE ALSO

Supfam::SQLFunc.pm - Where all the SQL related basic functions are kept.

=head1 DESCRIPTION

=cut

our @ISA       = qw(Exporter AutoLoader);
our @EXPORT    = qw(
                     getGenomeUniqDomCombs
                  );
our @EXPORT_OK = qw();
our $VERSION   = 1.00;

use strict;
use warnings;

use Supfam::SQLFunc;

=pod
=head2 Methods
=over 4
=cut


=pod
=item * getGenomeUniqDomCombs($genome_id)
Returns a hashref of all the unique superfamily combinations for a given genome id.
=cut
sub getGenomeUniqDomCombs {
my ($genome, $dbh) = @_;
$dbh = Supfam::SQLFunc::dbConnect() unless defined $dbh;
my $close_dbh = (@_ < 2)?1:0;

	my $uniq_combs = {};
	getGenomeDomCombs($genome,$uniq_combs,$dbh);
	removeSharedDomCombs($genome,$uniq_combs,$dbh);
	dbDisconnect($dbh) if $close_dbh;

	return $uniq_combs;
}

=pod
=item * getUniqDomCombsExclTaxon($genome_id, $taxon_id)
Returns a hashref of all the unique superfamily combinations for a given genome id.
Uniqueness is calculated in respect to excluding comparissons with all genomes 
below the specified NCBI taxonomy id.
=cut
sub getUniqDomCombsExclTaxon($$) {
}

=pod
=item * getUniqCombsExclGenomes($genome_id, $genomes = [])
Returns a hashref of all the unique superfamily combinations for a given genome id.
Uniqueness is calculated in respect to excluding comparissons with all genomes specified
in the $genomes arrayref.
=cut
sub getUniqDomCombsExclGenomes($\) {
my ($genome, $to_exclude) = @_;
ref $to_exclude eq "ARRAY" or die "Expected an ARRAY ref $!";
}

sub getUniqDomCombsUsingGenomes($\) {
my ($genome, $to_use) = @_;
ref $to_use eq "ARRAY" or die "Expected an ARRAY ref $!";
	my $dbh = Supfam::SQLFunc::dbConnect() unless defined $dbh;
	my $close_dbh = (@_ < 2)?1:0;

        my $uniq_combs = {};
        getGenomeDomCombs($genome,$uniq_combs,$dbh);
        removeSharedDomCombs($genome,$uniq_combs,$dbh);
        dbDisconnect($dbh) if $close_dbh;

        return $uniq_combs;
}

=pod

=back

=cut

1;
__END__

