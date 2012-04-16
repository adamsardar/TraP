#!/usr/bin/env perl

use warnings;
use strict;

=head1 NAME

B<cell_timeline.cgi> - Display the disordered architecture for a specified SUPERFAMILY protein.

=head1 DESCRIPTION

Outputs an SVG rendering of the given proteins structual and disordered architecture. Weaker hits are included with their e-values specified as 'hanging' blocks.

An example use of this script is as follows:

To emulate SUPERFAMILY genome page style figures as closely as possible include something similar to the following in the page:

<div width="100%" style="overflow:scroll;">
	<object width="100%" height="100%" data="/cgi-bin/cell_timeline.cgi?proteins=3385949&genome=at&supfam=1&ruler=0" type="image/svg+xml"></object>
</div>

To have super duper Matt style figures do something like:

<div width="100%" style="overflow:scroll;">
	<object width="100%" height="100%" data="/cgi-bin/cell_timeline.cgi?proteins=3385949,26711867&callouts=1&ruler=1&disorder=1" type="image/svg+xml"></object>
</div>


=head1 TODO

B<HANDLE PARTIAL HITS!>

I<SANITIZE INPUT MORE!>

	* Specify lists of proteins, along with other search terms like comb string, required by SUPERFAMILY.

=head1 AUTHOR

B<Matt Oates> - I<Matt.Oates@bristol.ac.uk>

=head1 NOTICE

B<Matt Oates> (Jan 2012) First features added.

=head1 LICENSE AND COPYRIGHT

B<Copyright 2012 Matt Oates>

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.

=head1 FUNCTIONS

=over 4

=cut

use POSIX qw/ceil floor/;
use CGI;
use CGI::Carp qw(fatalsToBrowser); #Force error messages to be output as HTML
use Data::Dumper;
use DBI;
use lib qw'/home/rackham/projects/TraP/lib';
use Utils::SQL::Connect qw/:all/;
use Supfam::Utils qw(:all);

#Deal with the CGI parameters here
my $cgi = CGI->new;
print $cgi->header();

my $genome = $cgi->param('genome');
unless(defined($genome)){
        $genome = 'hs';
}


my %names = %{get_exps($genome)};
print "<table>";
foreach my $name (keys %names){
	print "<tr><td>  <a href=\"http://luca.cs.bris.ac.uk/~rackham/cgi-bin/cell_timeline.cgi?exp=$name\">$names{$name}</a> </td></tr>"
}
print "</table>";

sub get_exps {
	my $exp = shift;
	my $dbh = dbConnect('trap');
	my $sth = $dbh->prepare("select experiment_id,sample_name from experiment where genome = ?;");
	$sth->execute($exp);
	my %name;
	while( my ($id,$name) =  $sth->fetchrow_array()){ 
		$name{$id} = $name;
	}
	return \%name;
}

=pod

=back

=head1 TODO

=over 4

=item Edit this file removing all the default skeleton.pl comments!

=back

=cut

1;

__END__

