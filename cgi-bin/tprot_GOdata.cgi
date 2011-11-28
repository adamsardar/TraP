#!/usr/bin/env perl

use strict;
use warnings;
use CGI qw(:standard);
use JSON;
use DBI;
use lib 'modules';
use Data::Dumper;
use tprot;
use DBI;

my $graph = Graph::Easy->new();
my $cgi = CGI->new;
print $cgi->header;

my $json = JSON->new; #Output of cgi will be in JSON format

my %network;
my %exps;
my %prots;

my $dbh = tprot::DBConnect;
my $sth =   $dbh->prepare( "SELECT protein_id,experiment_id FROM expression WHERE expressed = 1 ORDER BY protein_id;" );
my $sth =   $dbh->prepare( "SELECT FROM tprot.expression JOIN superfamily.comb ON protein_id = protein JOIN superfamily.GO_mapping ON  WHERE tprot.expression.expressed = 1 ORDER BY protein_id;" );

$sth->execute;


while (my ($ProtID,$ExpID) = $sth->fetchrow_array ) {
	
	# $ProtID $ExpID are rturned form the above database query
	$exps{$ExpID} = undef;
	$prots{$ProtID} = undef;
	$network{$ProtID}{$ExpID}=1;
}

      
my @experiments = sort keys %exps;

my @data;
push @data, ['Protein',@experiments];
#Initialise @data with a pointer to an array of the string 'Protein' and a list of experiment ids.
	
foreach my $prot (sort keys %prots){
		
	next if (scalar ( keys %{$network{$prot}} ) >= 6); #Thereshold limit for the number of experiments to include in the ouputted graph (proteins with more than this many experiments will not be included)
	my @ProteinExperimentArray = ($prot); #Prepend the protein data array of prescence/abscene reults by the protien id studied
	
	foreach my $exp (@experiments){
		
		if(defined($network{$prot}{$exp})){ #If a protein was studied in a given experiment
			
			push (@ProteinExperimentArray,1);
			
		}else{
			
			push (@ProteinExperimentArray,0);
		}	
	}
	
	push(@data,\@ProteinExperimentArray); # Add a pointer to the protein data array to the 2D array @data, which will be outputted shortly to JSON
}

my $json_text = $json->encode(\@data);

print $json_text;

