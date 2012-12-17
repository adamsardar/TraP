#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use lib '/home/rackham/modules/';
use rackham;
use Data::Dumper;
use URI::Escape;


use DBI;
my ( $dbh, $sth );
$dbh = rackham::DBConnect;
my %experiments;
open CELLS,'>txts/cell_snap_shots.txt';
 $sth =   $dbh->prepare( "select samplename,sampleID,groupID,celltype,GeneID,value,log2fold,pval,padj,gene_distance from snap_gene_expression where releaseID = 111;" );
        $sth->execute;
        while (my @temp = $sth->fetchrow_array ) {
        my $decode = uri_unescape($temp[0]); 
        my @id_parts = split(/\./,$temp[0]);
        print CELLS "$id_parts[2]\t$temp[4]\t$temp[5]\t$temp[6]\t$temp[7]\t$temp[8]\t$temp[9]\n";
        unless(exists($experiments{$id_parts[2]})){
        	$experiments{$id_parts[2]} = "$temp[0]\t$temp[2]\t$temp[3]";
        }
        }
open EXPS,'>txts/experiments.txt';
foreach my $id (keys %experiments){
	print EXPS "$id\t$experiments{$id}\n";

}
