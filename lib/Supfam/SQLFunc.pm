#!/usr/bin/env perl

package Supfam::SQLFunc;
require Exporter;
require SelfLoader;

=head1 NAME

Supfam::SQLFunc.pm

=head1 SYNOPSIS

Holds all the functions required to do interesting things with the Superfamily database.
use Supfam::SQLFunc;

=head1 AUTHOR

Matt Oates (Matt.Oates@bristol.ac.uk)

=head1 COPYRIGHT

Copyright 2010 Gough Group, University of Bristol.

=head1 SEE ALSO

Utils::Config.pm

=head1 DESCRIPTION

=cut

our @ISA = qw(Exporter SelfLoader);

our %EXPORT_TAGS = (
'all' => [ qw(
			dbConnect
			dbTRAPConnect
			dbDisconnect
			getGenomeNames
			getGenomeDomCombs
			removeSharedDomCombs
			getProteinIDFromUP
			getProteinArchitectures
			doArchitectureTF_IDF
			doDomainTF_IDF
			getTreeNode
			getTreeNodeByLeft
			getTreeNodeByRight
			getAncestralTreeNode
			getAncestralTreeNodeByLeft
			getAncestralTreeNodeByRight
) ],
'topic' => [ qw(
			doArchitectureTF_IDF
			doDomainTF_IDF
) ],
'tree' => [ qw(
			getTreeNode
			getTreeNodeByLeft
			getTreeNodeByRight
			getAncestralTreeNode
			getAncestralTreeNodeByLeft
			getAncestralTreeNodeByRight
) ],
'connect' => [ qw(
			dbConnect
			dbTRAPConnect
			dbDisconnect
) ],
);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

our $VERSION   = 1.00;

use strict;
use warnings;

use DBI;
use Data::Dumper;
use Term::ProgressBar;
use Math::Combinatorics;

use Utils::Config;

use lib ("../lib");


=pod
=head2 Methods
=over 4
=cut


sub dbConnect {
	my ($database,$host,$user,$password);
	my $c = ''; #Which database config to use

	#Auto fill from database specific config any settings the calling function didn't specify, otherwise use defaults
	if (@_) {
		($database,$host,$user,$password) = @_;
		#If a specific database config exists use it, otherwise default
		$c = (exists $CONFIG{"database.$database"})?"database.$database":'database';
		$database = $CONFIG{"$c.name"} unless $database;
		$host = $CONFIG{"$c.host"} unless $host;
		$user = $CONFIG{"$c.user"} unless $user;
		$password = $CONFIG{"$c.password"} unless $password;
	}
	#Use default database config, which is SUPERFAMILY
	else {
		($database,$host,$user,$password) = ($CONFIG{'database.name'},$CONFIG{'database.host'},$CONFIG{'database.user'},undef);
	}

	return DBI->connect("DBI:mysql:dbname=$database;host=$host"
	                                        ,$user
	                                        ,$password
	                                        ,{RaiseError =>1}
	                                    ) or die "Fatal Error: couldn't connect to $database on $host";
}

sub dbDisconnect {
	my $dbh = shift;
	warn "Closing Database Connection!\n";
	return $dbh->disconnect();
}

sub getGenomeNames {
my ($genome,$dbh) = @_;
$dbh = dbConnect() unless defined $dbh;
my $close_dbh = (@_ < 2)?1:0;

        #Get names for all the genomes as a hash if an array ref is passed in
        if (ref $genome eq "ARRAY") {
					 my $genomes = join ',', map {"'$_'"} @$genome;
                return $dbh->selectall_hashref("SELECT genome, name FROM genome WHERE genome IN ($genomes)",'genome');
        }
        #Otherwise return a string of just the name for this genome
        else {
                ($_) = $dbh->selectrow_array("SELECT name FROM genome WHERE genome=?",undef,$genome);
                return $_;
        }

dbDisconnect($dbh) if $close_dbh;
}

sub getGenomeDomCombs {
my ($genome, $combs, $dbh) = @_;
$dbh = dbConnect() unless defined $dbh;
my $close_dbh = (@_ < 3)?1:0;

        my ($nrows) = $dbh->selectrow_array("SELECT count(genome) FROM len_supra WHERE ascomb_prot_number > 0 AND genome = ?", undef, $genome);
        my $query = $dbh->prepare("SELECT comb_index.comb as comb FROM len_supra, comb_index WHERE len_supra.supra_id = comb_index.id AND len_supra.ascomb_prot_number > 0 AND len_supra.genome = ?");
        $query->execute($genome) or return undef;
        my $pbar = Term::ProgressBar->new({'name' => "Getting combs for $genome",
                                           'count' => $nrows,
                                           'remove' => 1,
                                           'ETA' => 'linear',
                                           'fh' => \*STDERR
                                        });
        $pbar->minor(0);
        my $progress = 1;
        my $update = 0;
        while (my ($comb) = $query->fetchrow_array()) {
                my @combinations = combine(2,grep(!/_gap_/,split(/,/,$comb)));
                foreach my $pair (@combinations) {
                        @_ = sort {$a <=> $b} @$pair;
                        $combs->{shift()}{shift()}++;
                }
                $update = $pbar->update($progress) if $progress >= $update;
        }
	dbDisconnect($dbh) if $close_dbh;
	return $combs;
}

sub removeSharedDomCombs {
my ($genome, $combs, $dbh) = @_;
$dbh = dbConnect() unless defined $dbh;
my $close_dbh = (@_ < 3)?1:0;

	my ($nrows) = $dbh->selectrow_array("SELECT count(genome) FROM len_comb WHERE genome != ?", undef, $genome);

	my $query = $dbh->prepare("SELECT comb FROM len_comb WHERE genome != ?");
	$query->execute($genome) or return undef;
	my $pbar = Term::ProgressBar->new({'name' => "Removing shared combs for $genome",
                                           'count' => $nrows,
                                           'remove' => 1,
                                           'ETA' => 'linear',
                                           'fh' => \*STDERR
                                        });
	$pbar->minor(0);

	my $progress = 1;
	my $update = 0;
        while (my ($comb) = $query->fetchrow_array()) {
                my @combinations = combine(2,grep(!/_gap_/,split(/,/,$comb)));
                foreach my $pair (@combinations) {
                        @_ = sort {$a <=> $b} @$pair;
			#Delete this specific dom pair
                        delete $combs->{shift()}{shift()};
                }
                $progress++;
		$update = $pbar->update($progress) if $progress >= $update;
        }
	#Delete hanging empty keys where we removed all pair partners
	while (my ($key,$val) = each(%$combs)) {delete $combs->{$key} unless keys %$val;}
	dbDisconnect($dbh) if $close_dbh;
}

sub getProteinIDFromUP {
my ($up_id,$dbh) = @_;
$dbh = dbConnect() unless defined $dbh;
my $close_dbh = (@_ < 2)?1:0;
	my $prot_id;
	my $query = $dbh->prepare(
		"SELECT protein FROM protein WHERE seqid=?"
	);
	if (ref $up_id eq "ARRAY") {
		$prot_id = {};
		foreach my $id (@$up_id) {
			$query->execute($id);
			map {$prot_id->{$id} = $_} $query->fetchrow_array;
		}
	}
	else {
		$query->execute($up_id);
		($prot_id) = $query->fetchrow_array;
	}

dbDisconnect($dbh) if $close_dbh;
return $prot_id;
}

sub getProteinArchitectures {
my ($prot_id,$dbh) = @_;
$dbh = dbConnect() unless defined $dbh;
my $close_dbh = (@_ > 1)?1:0;
        my $comb;
        my $query = $dbh->prepare(
                "SELECT comb FROM comb WHERE protein=?"
        );
        if (ref $prot_id eq "ARRAY") {
                $comb = {};
                foreach my $id (@$prot_id) {
                        $query->execute($id);
                        map {$comb->{$id} = $_} $query->fetchrow_array;
                }
        }
        else {
                $query->execute($prot_id);
                ($comb) = $query->fetchrow_array;
        }

dbDisconnect($dbh) if $close_dbh;
return $comb;
}

sub doArchitectureTF_IDF {
my ($architecture,$tf,$dbh) = @_;
$dbh = dbConnect() unless defined $dbh;
my $close_dbh = (@_ < 3)?1:0;
        my ($idf) = $dbh->selectrow_array("SELECT log((SELECT sum(number) FROM len_comb)/(SELECT sum(number) FROM len_comb WHERE comb = ?))", undef, $architecture);
dbDisconnect($dbh) if $close_dbh;
return $tf*$idf;
}

sub doDomainTF_IDF {
my ($domain,$tf,$dbh) = @_;
$dbh = dbConnect() unless defined $dbh;
my $close_dbh = (@_ < 3)?1:0;
        my ($idf) = $dbh->selectrow_array("SELECT log((SELECT sum(number) FROM len)/(SELECT sum(number) FROM len WHERE sf = ?))", undef, $domain);
dbDisconnect($dbh) if $close_dbh;
return $tf*$idf;
}

sub getDomainGOAnnotations {
my ($domain,$dbh) = @_;
$dbh = dbConnect() unless defined $dbh;
my $close_dbh = (@_ < 2)?1:0;
        my $goterms = {};
        my ($idf) = $dbh->selectrow_array("SELECT id,name FROM len WHERE sf = ?))", undef, $domain);
dbDisconnect($dbh) if $close_dbh;
return $goterms;
}

sub getTreeNode {
my ($id,$dbh) = @_;
$dbh = dbConnect() and my $close_dbh = 1 unless defined $dbh;
	my $node = $dbh->selectrow_hashref("SELECT *
													FROM tree
													WHERE left_id = ?
														OR right_id = ?
													LIMIT 1",
												$id);
dbDisconnect($dbh) if $close_dbh;
return $node;
}

sub getTreeNodeByLeft {
my ($left_id,$dbh) = @_;
$dbh = dbConnect() and my $close_dbh = 1 unless defined $dbh;
	my $node = $dbh->selectrow_hashref("SELECT *
													FROM tree
													WHERE left_id = ?
													LIMIT 1",
												$left_id);
dbDisconnect($dbh) if $close_dbh;
return $node;
}

sub getTreeNodeByRight {
my ($right_id,$dbh) = @_;
$dbh = dbConnect() and my $close_dbh = 1 unless defined $dbh;
	my $node = $dbh->selectrow_hashref("SELECT *
													FROM tree
													WHERE right_id = ?
													LIMIT 1",
												$right_id);
dbDisconnect($dbh) if $close_dbh;
return $node;
}

sub getAncestralTreeNode {
my ($id,$dbh) = @_;
$dbh = dbConnect() and my $close_dbh = 1 unless defined $dbh;
	my $node = $dbh->selectrow_hashref("SELECT tree.*, ancestral_info.*, ncbi_taxonomy.name
													FROM tree, ancestral_info, ncbi_taxonomy
													WHERE tree.left_id = ? OR tree.right_id = ?
													AND tree.left_id = ancestral_info.left_id
													AND tree.taxon_id = ncbi_taxonomy.taxon_id
													LIMIT 1",
												$id);
dbDisconnect($dbh) if $close_dbh;
return $node;
}

sub getAncestralTreeNodeByLeft {
my ($left_id,$dbh) = @_;
$dbh = dbConnect() and my $close_dbh = 1 unless defined $dbh;
	my $node = $dbh->selectrow_hashref("SELECT tree.*, ancestral_info.*, ncbi_taxonomy.name
													FROM tree, ancestral_info, ncbi_taxonomy
													WHERE tree.left_id = ?
													AND tree.left_id = ancestral_info.left_id
													AND tree.taxon_id = ncbi_taxonomy.taxon_id
													LIMIT 1",
												$left_id);
dbDisconnect($dbh) if $close_dbh;
return $node;
}

sub getAncestralTreeNodeByRight {
my ($right_id,$dbh) = @_;
$dbh = dbConnect() and my $close_dbh = 1 unless defined $dbh;
	my $node = $dbh->selectrow_hashref("SELECT tree.*, ancestral_info.*, ncbi_taxonomy.name
													FROM tree, ancestral_info, ncbi_taxonomy
													WHERE tree.right_id = ?
													AND tree.left_id = ancestral_info.left_id
													AND tree.taxon_id = ncbi_taxonomy.taxon_id
													LIMIT 1",
												$right_id);
dbDisconnect($dbh) if $close_dbh;
return $node;
}

=pod

=back

=cut

1;

__DATA__
