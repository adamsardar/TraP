#!/usr/bin/env perl

package Supfam::HMM;
require Exporter;

=head1 NAME

Supfam::HMM.pm

=head1 SYNOPSIS

Holds all the functions to play with HMM's with HMMER 3.0 and PRC

=head1 AUTHOR

Matt Oates (Matt.Oates@bristol.ac.uk)

=head1 COPYRIGHT

Copyright 2011 Gough Group, University of Bristol.

=head1 SEE ALSO

Supfam::Config.pm
Supfam::SQLFunc.pm

=head1 DESCRIPTION

=head1 FUNCTIONS DEFINED

=over 4

=cut

our @ISA = qw(Exporter SelfLoader);

our %EXPORT_TAGS = (
'all' => [ qw(
			hmmBuildFromSFProtein
			hmmBuildFromSFProteinRange
			prcAllVAll
			hmmSearch
) ],
'build' => [ qw(
			hmmBuildFromSFProtein
			hmmBuildFromSFProteinRange
) ],
'search' => [ qw(
			hmmSearch
) ],
'compare' => [ qw(
			prcAllVAll
) ],
);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

our $VERSION   = 1.00;

use strict;
use warnings;
use threads;

use Supfam::Config;
use Supfam::SQLFunc;
use File::Basename;
use File::Temp qw/ tempfile tempdir /;
use Cwd qw/ abs_path getcwd /;
use File::Path qw/ remove_tree /;
use Term::ProgressBar;

=item I<hmmBuildFromSFProtein> - Build an hmm with HMMER3 from a Superfamily protein using ID
=cut
sub hmmBuildFromSFProtein {
	
}

=item I<hmmBuildFromSFProteinRange> - Build an hmm with HMMER3 from a Superfamily protein using ID and an amino acid range
=cut
sub hmmBuildFromSFProteinRange {
	
}

=item I<hmmSearch> - Search an hmm against a set of sequences
=cut
sub hmmSearch {
	
}

=item I<isHMMER2> - Check if an hmm is in HMMER2 format, undef if the file doesn't exist
=cut
sub isHMMER2 ($) {
	my ($model) = @_;
	return undef unless -e $model;
	return system("head -n 1 $model | grep '^HMMER2' > /dev/null")  == 0;
}

=item I<convertHMMER2> - Create a new copy of the hmm in HMMER2 format
=cut
sub convertHMMER2 ($$) {
	my ($model,$newmodel) = @_;
	return undef unless -e $model;
	if (isHMMER2 $model) {
		#Make a temp copy of the HMM so that we can convert it safely
		return system("cp $model $newmodel") == 0;
	}
	#Convert the HMM to HMMER2.0 format, strip the converted from message as the prc command doesn't like this
	return system ("hmmconvert -2 $model | perl -pe 's/  [[]converted from .*//;' > $newmodel") == 0;
}

=item I<prcHMMvLIB> - Compare a single hmm against a library of other models, excludes self-self comparisson
=cut
#Run prc with one model against a library of models, excludes self-self comparissons
sub prcHMMvLIB {
	my ($model, $tempdir, $models) = @_;
	my $cwd = getcwd;
	my ($filename) = fileparse($model, qr/\.[^.]*/);
	
	#For all the other models we wish to compare to build a library file
	foreach my $compare_to ( grep !/$model/, @$models ) {
		($compare_to) = fileparse($compare_to);
		#$compare_to = abs_path("$tempdir/$compare_to");
		#Populate the library file with local paths to the converted HMMs for this comparisson
		system ("echo $compare_to >> $tempdir/$filename.lib") == 0 
			or warn "Failed to add $compare_to to the HMM library file $tempdir/$filename.lib" and return undef;
	}
	#Move into the tempdir and run PRC on this model vs library of other models
	return `cd $tempdir; prc $filename.hmm $filename.lib $filename > /dev/null && grep -vh '^#' $filename.scores`;
}

=item I<prcAllVAll> - Use prc to do an all v all comparisson of a set of hmm's excluding self comparisson.
=cut
sub prcAllVAll {
	return undef if scalar @_ == 0;
	my @models = @_;
	
	my $tempdir = tempdir( './prc_run_XXXX' );
	
	#Convert HMMs to HMMER2.0 and put in the temp directory
	foreach my $model (@models) {
		my ($filename) = fileparse($model, qr/\.[^.]*/);
		convertHMMER2 $model , "$tempdir/$filename.hmm" or die "Failed to convert $model to HMMER2.0 format.";
	}
	
	#Map each model to a thread that will run PRC against all other models
	my @threads = map { threads->create(\&prcHMMvLIB,$_,"$tempdir",\@models) } @models;
	
	#Wait for all of the threads to finish and append their results
	my @results = ("hmm1	start1	end1	length1	hit_no	hmm2	start2	end2	length2	co-emis	simple	reverse\n");
	push @results, $_->join for @threads;
	
	return @results;
	
	remove_tree $tempdir or warn "Couldnt remove tempdir $tempdir";
	#pareach [ @models ], sub {
	#	my $model = shift;
	
	#};
}

=back
=cut
1;
__END__