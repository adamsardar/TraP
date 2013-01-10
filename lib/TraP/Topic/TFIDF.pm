#!/usr/bin/env perl

package TraP::Topic::TFIDF;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = (
'all' => [ qw(
			idf_calc
			logtf_calc
			linneartf_calc
			PO_table_info
			PO_query_construct
			PO_detailed_info
			GO_table_info
			GO_query_construct
			GO_detailed_info
			enrichment_output
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

Module to calculate TFIDF weightings for all input. Also contains functions for extracting PO and GO terms from superfamily

=head1 EXAMPLES

use TraP::Topic::TFIDF qw/tfidf/;

=head1 AUTHOR

B<Matt Oates> - I<Matt.Oates@bristol.ac.uk>
B<Adam Sardar> - I<Adam.Sardar@bristol.ac.uk>

=head1 NOTICE

B<Matt Oates> (2011) First features added.
B<Adam Sardar> (2013) Added some actual content

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


use lib '../../../lib';

=head1 DEPENDANCY

B<Data::Dumper> Used for debug output.

=cut
use Data::Dumper; #Allow easy print dumps of datastructures for debugging
use List::MoreUtils qw/ uniq /;
use Carp::Assert::More;
use DBI;
use Utils::SQL::Connect qw/:all/;
use Supfam::Utils qw/:all/;
 use Statistics::Basic qw(:all);
use Carp;
use Carp::Assert;
use Carp::Assert::More;

=head1 FUNCTIONS DEFINED


=item * idf_calc

Given a hash of documents and (not neccerserily unique) terms within them, calculate and idf using a log score

=cut

sub idf_calc {

	my ($DocumentHash) = @_;	
	#Hash of structure $Hash->{DocumentName}=[list of non-unque terms]

	my $CorpusSize = scalar(keys(%$DocumentHash));
	
	my $DocumentTermFrequency = {};
	#A count of the number of documents in which a term occurs
	
	foreach my $Document (keys(%$DocumentHash)){
		
		assert_listref($DocumentHash->{$Document},"Expecting a hash of structure Hash->{DocumentName}=[list of non-unque terms]/n");
		map{$DocumentTermFrequency->{$_}++}uniq(@{$DocumentHash->{$Document}}) ;
	}
	
	my @DocumentTerms = keys(%$DocumentTermFrequency);
	
	my $idf = {};
	
	foreach my $term (@DocumentTerms){
		
		if(exists($DocumentTermFrequency->{$term})){
			
			$idf->{$term}=log(1+$CorpusSize/($DocumentTermFrequency->{$term}))
			
		}else{
			
			$idf->{$term}=4;
			#If a term is not in the corpus, then set the idf as 1 so that it has a positive score
			#This is equivlent to a subset of the corpus having the term such that Card_D/n_d = e^2
		}
		
	}
	
	return($idf);
}


=item * logtf_calc

log transformed term frequency

=cut

sub logtf_calc {
	
	my ($DocumentTermsHash,$Terms) = @_;
	
	assert_hashref($DocumentTermsHash,"Expecting a hash of structure DocumentTermsHash->{Document name}{term}=termcount\n");
	assert_listref($Terms,"Expecting an arrayref of a list of terms to calculate tf upon\n");
	
	my $logtf = {};
	
	foreach my $Document (keys(%$DocumentTermsHash)){
		
		$logtf->{$Document}={};
		assert_hashref($DocumentTermsHash->{$Document},"Expecting a hash of structure DocumentTermsHash->{Document name}{term}=termcount\n");
		
		foreach my $term (@$Terms){
		
			if(exists($DocumentTermsHash->{$Document}{$term})){
				
				$logtf->{$Document}{$term}=0.1+log($DocumentTermsHash->{$Document}{$term});
				
			}else{
				
				$logtf->{$Document}{$term}=0;
			}
		}
	}
	
	return $logtf;	
}


=item * linneartf_calc

linnear addition of term frequency

=cut

sub linneartf_calc {
	
	my ($DocumentTermsHash,$Terms) = @_;
	
	assert_hashref($DocumentTermsHash,"Expecting a hash of structure DocumentTermsHash->{Document name}{term}=termcount\n");
	assert_listref($Terms,"Expecting an arrayref of a list of terms to calculate tf upon\n");
	
	my $lintf = {};
	
	foreach my $Document (keys(%$DocumentTermsHash)){
		
		$lintf->{$Document}={};
		assert_hashref($DocumentTermsHash->{$Document},"Expecting a hash of structure DocumentTermsHash->{Document name}{term}=termcount\n");
		
		foreach my $term (@$Terms){
		
			if(exists($DocumentTermsHash->{$Document}{$term})){
				
				$lintf->{$Document}{$term}=$DocumentTermsHash->{$Document}{$term};
				
			}else{
				
				$lintf->{$Document}{$term}=0;
			}
		}
	}
	
	return $lintf;	
}


=item * PO_query_construct

A function to contruct a query handle for extracting data from superfamily PO mapping table

=cut

sub PO_query_construct{
	
	my ($dbh) = @_;
	
	unless(defined($dbh)){
		
		$dbh = dbConnect('superfamily');
	}
	
	my $supfam_POsth =   $dbh->prepare_cached( "SELECT DISTINCT(PO_mapping_supra.po),PO_mapping_supra.obo
								FROM PO_mapping_supra 
								JOIN PO_ic_supra
								ON PO_ic_supra.po = PO_mapping_supra.po
								WHERE (PO_mapping_supra.inherited_from IS NOT NULL OR PO_mapping_supra.inherited_from != '')
								AND PO_mapping_supra.id = ?
								AND PO_ic_supra.include >= 3
								AND (PO_mapping_supra.obo = 'HP' OR PO_mapping_supra.obo = 'DO')
								AND PO_mapping_supra.po IS NOT NULL;"); 
	
	return($supfam_POsth);
}


=item * PO_table_info

Given a list of supra ids, extract HP (human phenotype) and DO (disease ontology) information. Returned are two hashes, one for HP and one for DO (respectively) of structure $hash->{combid}=[list of terms]

=cut

sub PO_table_info {
	
	my ($Supra_ids,$sth) = @_;
	
	unless(defined($sth)){
		
		my $dbh = dbConnect('superfamily');
		$sth = PO_query_construct($dbh);
	}
	
	assert_listref($Supra_ids,"Expecting an arrayref of a list of comb/supra ids which to extract data for\n");
	
	my $Comb2HPList = {};
	my $Comb2DOList = {};
	#Hashes of structure hash->{combID}=[list of DO/HP terms]
	
	foreach my $supra_id (@$Supra_ids){
		
		$sth->execute($supra_id);
		
		while (my ($PO_term,$PO_type) = $sth->fetchrow_array){
			
			if($PO_type ~~ 'HP'){
				
				$Comb2HPList->{$supra_id}=[] unless(exists($Comb2HPList->{$supra_id}));
				push(@{$Comb2HPList->{$supra_id}},$PO_term);
				
			}elsif($PO_type ~~ 'DO'){
				
				$Comb2DOList->{$supra_id}=[] unless(exists($Comb2DOList->{$supra_id}));
				push(@{$Comb2DOList->{$supra_id}},$PO_term);
				
			}else{
				
				die "Only HP and DO are expected as obo types from SUPERFAMILY\n;";
			}
			
		}
	}
	
	return($Comb2HPList,$Comb2DOList);	
}


=item * PO_detailed_info

Extract detailed information from the superfamily database regarding a tonne of GO terms

=cut

sub PO_detailed_info {
	
	my ($PO_terms) = @_;
	

	my $dbh = dbConnect('superfamily');
	my $sth = $dbh->prepare_cached( "SELECT PO_info.name
								FROM PO_info 
								WHERE PO_info.po = ?;"); 

	assert_listref($PO_terms,"Expecting an arrayref of a list of comb/supra ids which to extract data for\n");

	my $POID2Details= {};
	#Hashes of structure hash->{combID}=[list of DO/HP terms]
	
	foreach my $PO_term (@$PO_terms){
		
		$sth->execute($PO_term);
		
		while (my ($PO_details) = $sth->fetchrow_array){
	
			$POID2Details->{$PO_term}=$PO_details;
				
		}
	}
	
	return($POID2Details);	
}


=item * GO_query_construct

A function to contruct a query handle for extracting data from superfamily GO mapping table

=cut

sub GO_query_construct{
	
	my ($dbh) = @_;
	
	unless(defined($dbh)){
		
		$dbh = dbConnect('superfamily');
	}
	
	my $supfam_GOsth =   $dbh->prepare_cached( "SELECT GO_mapping_supra.go
								FROM GO_mapping_supra
								JOIN GO_ic_supra
								ON GO_ic_supra.go = GO_mapping_supra.go
								WHERE (GO_mapping_supra.inherited_from IS NOT NULL OR GO_mapping_supra.inherited_from != '')
								AND GO_mapping_supra.id = ?
								AND GO_ic_supra.include >= 3
								AND GO_mapping_supra.go IS NOT NULL;"); 
	
	return($supfam_GOsth);
}


=item * GO_table_info

Given a list of supra ids, extract GO information. Returned is a hash of supra id to an arrayref of GO terms

The source of these GO terms is as follows i.) check DC GO annotation and then (if no record is found) ii.) look for experiemntal validated data
=cut

sub GO_table_info {
	
	my ($Supra_ids,$sth) = @_;
	
	unless(defined($sth)){
		
		my $dbh = dbConnect('superfamily');
		$sth = GO_query_construct($dbh);
	}
	
	assert_listref($Supra_ids,"Expecting an arrayref of a list of comb/supra ids which to extract data for\n");

	my $experimental_dbh = dbConnect('trap');
	my $experimental_sth = $experimental_dbh->prepare_cached( "SELECT comb_go_mapping.go_id
								FROM comb_go_mapping 
								WHERE comb_go_mapping.comb_id = ?;"); 

	my $Comb2GOList = {};
	#Hashes of structure hash->{combID}=[list of DO/HP terms]
	
	foreach my $supra_id (@$Supra_ids){
		
		$sth->execute($supra_id);
		
		if($sth->rows){
		
			while (my ($GO_term) = $sth->fetchrow_array){
		
				$Comb2GOList->{$supra_id}=[] unless(exists($Comb2GOList->{$supra_id}));
				push(@{$Comb2GOList->{$supra_id}},$GO_term);
			}
			#If there is an entry in DC GO for the supra_id in question, then add the GO term assignmenets
			
		}else{
			
			$experimental_sth->execute($supra_id);
			
			while (my ($GO_term) = $experimental_sth->fetchrow_array){
		
				$Comb2GOList->{$supra_id}=[] unless(exists($Comb2GOList->{$supra_id}));
				push(@{$Comb2GOList->{$supra_id}},$GO_term);
			}
			#Else check for the comb_go_mapping table entry
		}
		
	}
	
	return($Comb2GOList);	
}

=item * GO_detailed_info

Extract detailed information from the superfamily database regarding a tonne of GO terms

=cut

sub GO_detailed_info {
	
	my ($GO_terms) = @_;
	

	my $supfam_dbh = dbConnect('superfamily');
	
	my $supfam_sth = $supfam_dbh->prepare_cached( "SELECT GO_info.name
								FROM GO_info 
								WHERE GO_info.go = ?;"); 

	assert_listref($GO_terms,"Expecting an arrayref of a list of comb/supra ids which to extract data for\n");

	my $GOID2Details= {};
	#Hashes of structure hash->{combID}=[list of DO/HP terms]
	
	foreach my $GO_term (@$GO_terms){
		
		$supfam_sth->execute($GO_term);
		
		while (my ($GO_details) = $supfam_sth->fetchrow_array){
	
			$GOID2Details->{$GO_term}=$GO_details;
		}
	}
	
	return($GOID2Details);	
}

=item * enrichment_output

Having calculated an idf and decided on terms that we wish to analysise - output results to a file

An optional argument *dictionary is provided so that you may output aditional information in relation to samples if you wish

=cut

sub enrichment_output {
	
	my ($filename,$detaileddocumenthash,$idf,$terms,$dictionary) = @_;
	
	assert_listref($terms,"Expected a reference to a list of terms to calculate tf-idf upon\n");
	assert_hashref($detaileddocumenthash,"Detailed document hash shoudl be a hahs of structure hash->{docname}{term}=count\n");
	assert_hashref($idf,"idf shoudl be a hash of form hash->{term}=val\n");
	assert_hashref($dictionary,"Dictionary (an optional argument) shoudl be a has mapping from document name to another desited name\n") if(defined($dictionary));
		
	open FH, ">$filename" or die $?."\t".$!;
	
	my $logtf_hash = logtf_calc($detaileddocumenthash,$terms);
	my $lintf_hash = linneartf_calc($detaileddocumenthash,$terms);
	#Calculate a tf or both linear and log terms
	my $doubleflag= 0; #Almost pointless really, but it adds debug info
	
	my $TraitTFIDFScoreHash = {};
	#A hash to keep a record of all the tf-idf scores. This will be used to output a summary file with candidate enriched values. Just using linnear scores at current
	
	my @SampleIDs = keys(%$detaileddocumenthash);
	
	foreach my $sampid (@SampleIDs){
		
		assert_hashref($detaileddocumenthash->{$sampid},"Detailed document hash shoudl be a hahs of structure hash->{docname}{term}=count\n");

		#Output DA information
		foreach my $trait (keys(%{$detaileddocumenthash->{$sampid}})){
			
			$TraitTFIDFScoreHash->{$trait}={} unless(exists($TraitTFIDFScoreHash->{$trait}));
			
			print FH $sampid."\t";
			
			if(defined($dictionary)){
				
				if(exists($dictionary->{$sampid})){
					
					my $extra = $dictionary->{$sampid};
					print FH $extra."\t";
					
				}elsif(exists($dictionary->{$trait})){
					
					my $extra = $dictionary->{$trait};
					print FH $extra."\t";
				}
				
				$doubleflag=1 if(exists($dictionary->{$trait}) && exists($dictionary->{$sampid}));
			}
			#Dictionary is present so that you can output additional information if you so desire
			

			my $logtf = $logtf_hash->{$sampid}{$trait};
			my $lintf = $lintf_hash->{$sampid}{$trait};
			
			my $idf = $idf->{$trait};
			
			my $logtfidf = $logtf*$idf;
			my $lintfidf = $lintf*$idf;
			
			$TraitTFIDFScoreHash->{$trait}{$sampid} = $lintfidf;
			
			print FH $trait."\t".$logtfidf."\t".$lintfidf."\n";
		}
	}
	carp "By The Way: trait and sample_id are both present in the dictionary. Should be OK ... but just a heads up!\n" if($doubleflag);
		
	close FH;

	open FULL, ">$filename.AllSig.summary" or die $?."\t".$!;
	open ONESIGSUMMARY, ">$filename.OneSig.summary" or die $?."\t".$!;
	#Look for significant enriched terms
	open HIGHSIGSUMMARY, ">$filename.HIGHSig.summary" or die $?."\t".$!;
	#Look for HIGHLY enriched terms
	
	foreach my $term (@$terms){
		
		my @tf_idf_scores = @{$TraitTFIDFScoreHash->{$term}}{@SampleIDs};
		
		my $mean = mean(@tf_idf_scores);
		my $stddev = stddev(@tf_idf_scores);
		
		foreach my $sample (keys(%{$TraitTFIDFScoreHash->{$term}})){
			
			my $score = $TraitTFIDFScoreHash->{$term}{$sample};
			
			my $normedscore;
			if ($stddev > 0){
				
				$normedscore = ($score-$mean)/$stddev;
			}else{
				
				$normedscore = 0;
			}
			
			#Output all scores
			
			print FULL $sample."\t";
			print ONESIGSUMMARY $sample."\t" if ($score > ($mean+$stddev));
			print HIGHSIGSUMMARY $sample."\t" if ($score > 2*($mean+$stddev));
			#Output higher quality scores if they are over 1 or 2 std devs from mean
			
			if(defined($dictionary)){
					
						if(exists($dictionary->{$sample})){
							
							my $extra = $dictionary->{$sample};
							print FULL $extra."\t";
							print ONESIGSUMMARY $extra."\t" if ($score > ($mean+$stddev));
							print HIGHSIGSUMMARY $extra."\t" if ($score > 2*($mean+$stddev));
							
						}elsif(exists($dictionary->{$term})){
							
							my $extra = $dictionary->{$term};
							print FULL $extra."\t";
							print ONESIGSUMMARY $extra."\t" if ($score > ($mean+$stddev));
							print HIGHSIGSUMMARY $extra."\t" if ($score > 2*($mean+$stddev));
						}
			}
			#Dictionary is present so that you can output additional information if you so desire
			
			print FULL $score."\t".$normedscore."\t".$term."\n";
			print ONESIGSUMMARY $score."\t".$normedscore."\t".$term."\n" if ($score > ($mean+$stddev));
			print HIGHSIGSUMMARY $score."\t".$normedscore."\t".$term."\n" if ($score > 2*($mean+$stddev));
							
		}
	}
	
	close ONESIGSUMMARY;
	close HIGHSIGSUMMARY;
	close FULL;
}


1;
__END__

