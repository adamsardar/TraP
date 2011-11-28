package Supfam::Phylo::AncestralTree;
require Exporter;
require SelfLoader;

=head1 NAME

Supfam::Phylo::AncestralTree.pm

=head1 SYNOPSIS

Package for investigating SUPERFAMILY ancestral genomes.

=head1 AUTHOR

Matt Oates (Matt.Oates@bristol.ac.uk)

=head1 COPYRIGHT

Copyright 2011 Gough Group, University of Bristol.

=head1 SEE ALSO

Supfam::SQLFunc.pm - Where all the SQL related basic functions are kept.

=head1 DESCRIPTION

=cut

our @ISA = qw(Exporter SelfLoader);

#our %EXPORT_TAGS = ( 'all' => [ qw(
#getProteinImportance
#getDomainImportance
#) ] );
#our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT_OK = qw();
our @EXPORT = qw();

our $VERSION   = 1.00;

use strict;
use warnings;

use Carp;

use Supfam::SQLFunc qw(getProteinIDFromUP getProteinArchitectures doArchitectureTF_IDF doDomainTF_IDF);

1;

__DATA__

=pod
=head2 Methods
=over 4
=cut

=pod
=item * getDomainImportance($sf_id)
Returns a hashref of all the protein ids with their domain assignments and their tf-idf importance.
=cut
sub getAncestorNode {
my ($, $dbh) = @_;
ref $domains eq "ARRAY" or die "Expected an ARRAY ref $!";
$dbh = Supfam::SQLFunc::dbConnect() unless defined $dbh;
my $close_dbh = (@_ > 1)?1:0;

   my $ranked_domains = {};
   map {$ranked_domains->{$_}{'tf'}++} @$domains;

   foreach $id (keys %$ranked_domains) {
      $ranked_domains->{$id}{'tf-idf'} = doDomainTF_IDF($id,$ranked_domains->{$id}{'tf'},$dbh);
   }

dbDisconnect($dbh) if $close_dbh;
return $ranked_domains;
}

=pod

=back

=cut
