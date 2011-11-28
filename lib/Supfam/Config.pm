#!/usr/bin/env perl

package Supfam::Config;

=head1 NAME

Supfam::Config.pm

=head1 DESCRIPTION

Provides configuration information for the SUPERFAMILY database and related databases.
Loads in the data from ~/.supfam_config.ini into %SUPFAM as well as any local ./config.ini into %CONFIG in the working directory of the currently executing script.
If no SUPERFAMILY config is found a sensible default from inside the package will be given. Failing this you will just run without a config.

=head2 %SUPFAM

A configuration hash with similar structure to the INI definition found in the .supfam_config.ini file of your home.
Example use: `%SUPFAM{'database.name'}`
Be aware this variable is tied to the file, so if you make a change to the hash you are editing the file too.

=head2 %CONFIG

A configuration hash with similar structure to the INI definition found in the local ./config.ini file.
As with %SUPFAM this variable is tied to the local config file to reflect changes made programatically.
=cut

require Exporter;

our %SUPFAM;
our %CONFIG;

our @ISA       = qw(Exporter);
our @EXPORT    = qw(%SUPFAM %CONFIG);
our @EXPORT_OK = qw();
our $VERSION   = 1.00;

use strict;
use warnings;
use Carp;
use Config::Simple;
use File::Basename;

#Load in the local config for the invoking script if it exists.
if ( -e "config.ini" ) {
   tie %CONFIG, "Config::Simple", "config.ini";
}

#Where is this module located
my (undef,$mod_path,undef) = fileparse(__FILE__);

#Use the users home supfam_config.ini over anything else
if ( -e $ENV{'HOME'}."/.supfam_config.ini") {
   tie %SUPFAM, "Config::Simple", $ENV{'HOME'}."/.supfam_config.ini";
}
#Use the supfamconfig in the current working directory useful for CGI scripts that dont have a home
elsif (-e ".supfam_config.ini") {
   tie %SUPFAM, "Config::Simple", ".supfam_config.ini";
}
#Try to load the default from the Supfam package
elsif (-e $mod_path."supfam_config.ini") {
   tie %SUPFAM, "Config::Simple", $mod_path.'supfam_config.ini';
}
#Warn that we don't have a config for the package
else {
   carp "Cannot locate the global supfam_config.ini for Supfam:: modules, looking in: ".$ENV{'HOME'}."/.supfam_config.ini or ".$mod_path.'supfam_config.ini';
}

1;
__END__
