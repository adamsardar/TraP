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
use Data::Dumper;
use DBI;

#Deal with the CGI parameters here
my $cgi = CGI->new;

=item B<draw_timeline>
=cut
sub draw_timeline {
	my ($width,$height,$times) = @_;
	my $diagram = '';
	my $timeline_y = $height / 2;
	my $scale_y = $height - 20;
	my $tick_height = 10;
	
	#Draw header
	$diagram .= <<EOF
<?xml version="1.0" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" 
	 "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink"
     width="$width" height="$height"
     viewBox="0 0 $width $height">
EOF
    ;
	
	#Draw the time and scale lines
	$diagram .= <<EOF
	<line x1="0" y1="$timeline_y" x2="$width" y2="$timeline_y" style="stroke: #333; stroke-width: 1;" />
	<line x1="0" y1="$scale_y" x2="$width" y2="$scale_y" style="stroke: #333; stroke-width: 1;" />
EOF
	;
	
	#Foreach point in time draw the tickmark/label on the scale and the circle on the timeline
	foreach my $time (keys %{$times}) {
		my $dx = $width*$time;
		my $dy = $scale_y + $tick_height;
		
		#Draw scalebar tick marks
		$diagram .= <<EOF
	<line x1="$dx" y1="$scale_y" x2="$dx" y2="$dy" style="stroke: #333; stroke-width: 1;" />
EOF
		;
		
		my $label =  $times->{$time}{'label'};
		#Draw the labels
		$diagram .= <<EOF
		<text x=\"$dx\" y=\"$dy\" text-anchor=\"middle\" style=\"font-size:10px\">$label</text>
EOF
		;
			
		my $size = $times->{$time}{'size'};
		#Draw the circles
		$diagram .= <<EOF
		<circle cx="$dx" cy="$timeline_y" r="$size" stroke="black" stroke-width="1" fill="red"/>
EOF
	}
	
	$diagram .= "\n<svg>";

	return $diagram;
}

my %times = get_times();

print $cgi->header("image/svg+xml");

print draw_timeline(800,600,\%times);

=back
=cut

1;
