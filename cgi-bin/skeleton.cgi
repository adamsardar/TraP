#!/usr/bin/env perl

use strict;
use warnings;

=head1 NAME

skeleton.cgi = CGI script to set the standard

=head1 DESCRIPTION

This module has been released as part of the TraP Project code base.

Just a skeleton layout for each CGI to start from.

=head1 AUTHOR

DELETE AS APPROPRIATE!

B<Matt Oates> - I<Matt.Oates@bristol.ac.uk>

B<Owen Rackham> - I<Owen.Rackham@bristol.ac.uk>

B<Adam Sardar> - I<Adam.Sardar@bristol.ac.uk>

=head1 NOTICE

DELETE AS APPROPRIATE!

B<Matt Oates> (2011) First features added.

B<Owen Rackham> (2011) First features added.

B<Adam Sardar> (2011) First features added.

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


use lib '../lib';

=head1 DEPENDANCY

=over 4

=item B<CGI> Used just for the CGI boiler plate.

=item B<Template> Everything else CGI content/rendering related.

=item B<CGI::Carp> Die/Warn messages go to the browser prettyafied.

=item B<JSON::XS> Deal with JSON efficiently.

=item B<Data::Dumper> Used for debug output.

=back

=cut
use CGI; #Use this for purely GET POST values, nothing more.
use Template; #Use this to render content NOT CGI.pm!!!
use CGI::Carp qw(fatalsToBrowser); #Force error messages to be output as HTML
use JSON::XS;
use Data::Dumper; #Allow easy print dumps of datastructures for debugging


=head1 FUNCTIONS DEFINED

=over 4
=cut

=item * sub1
Function to do something
=cut
sub sub1 {
    my ($var) = @_;
	return 1;
}

=pod

=back

=cut

my $cgi = CGI->new;

#Things you should use CGI for!
my $var6 = ($cgi->param('value_passed_in_get_or_post') or "Didn't pass in!");
my $uploaded_fh = $cgi->upload('file_input_field');
my $user = $query->cookie('trap_user');

#Some otpions to pass in
my $config = {
   INCLUDE_PATH => '../cgi-templates',  # or list ref
   INTERPOLATE  => 1,               #Expand "$var" in plain text
   POST_CHOMP   => 1,               #Cleanup whitespace
   #It's better to use INCLUDE directives in the templates rather than these options!
   #PRE_PROCESS  => 'header.html',   #Prefix each template with the header
   #POST_PROCESS =>  'footer.html',  #Postfix each template with the footer
   EVAL_PERL    => 1,               #Evaluate Perl code blocks
};

#Create Template object
my $template = Template->new($config);

#Define template variables for replacement, notice it ca be a subref!
my $vars = {
   'var1'  => "Hello World",
   #'var2'  => \%hash,
   #'var3'  => \@list,
   #'var4'  => \&code,
   #'var5'  => $object,
   'var6'     => $var6,
};

# process input template, substituting variables
$template->process('skeleton.tt', $vars) or die $template->error();

#OR if you have a DATA fetish
#$template->process(\*DATA, $vars) or die $template->error();

=head1 TODO

=over 4

=item Add feature here...

=back

=cut

1;

__DATA__
    [%  INCLUDE header
          title = 'This is an HTML skeleton!';
        
        pages = [
          { url   = 'http://mattoates.co.uk'
            title = 'Matt Oates World' 
          }
          { url   = 'http://google.com'
            title = 'The Search King' 
          }
        ]
    %]
       <h1>Var1 was [% var1 %]</h1>
       <h1>Var6 was [% var6 %]</h1>
       <h1>Some Skeleton Output</h1>
       <ul>
    [%  FOREACH page IN pages %]
         <li><a href="[% page.url %]">[% page.title %]</a>
    [%  END %]
       </ul>
       
       <h1>All of your PATH</h1>
       <ol>
    [%  FOREACH p IN path %]
        <li>[% p %]</li>
    [% END %]
        </ol>
    
    [% INCLUDE footer %]
