#!/usr/bin/env perl

package TraP::Topic::TFIDF;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = (
'all' => [ qw(
			idf_calc
			logtf_calc
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


#use lib '~/lib';

=head1 DEPENDANCY

B<Data::Dumper> Used for debug output.

=cut
use Data::Dumper; #Allow easy print dumps of datastructures for debugging
use List::MoreUtils qw/ uniq /;
use Carp::Assert::More;


=head1 FUNCTIONS DEFINED


=item * idf_calc


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
		
		$idf->{$term}=log($CorpusSize/(1+$DocumentTermFrequency->{$term}))
	}
	
	return($idf);
}


=item * logtf_calc


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
				
				$logtf->{$Document}{$term}=1+log($DocumentTermsHash->{$Document}{$term});
				
			}else{
				
				$logtf->{$Document}{$term}=0;
			}
		}
	}
	
	return $logtf;	
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

