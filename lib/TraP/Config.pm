#!/usr/bin/env perl

package TraP::Config;

=head1 NAME

TraP::Config.pm

=head1 DESCRIPTION

Provides configuration information for the TraP database and related databases.
Loads in the data from ~/.trap_config.ini into %TRAP as well as any local ./config.ini into %CONFIG in the working directory of the currently executing script.
If no TraP config is found a sensible default from inside the package will be given. Failing this you will just run without a config.

=head2 %TRAP

A configuration hash with similar structure to the INI definition found in the .trap_config.ini file of your home.
Example use: `%TRAP{'database.name'}`
Be aware this variable is tied to the file, so if you make a change to the hash you are editing the file too.

=head2 %CONFIG

A configuration hash with similar structure to the INI definition found in the local ./config.ini file.
As with %TRAP this variable is tied to the local config file to reflect changes made programatically.
=cut

require Exporter;

our %TRAP;
our %CONFIG;

our @ISA       = qw(Exporter);
our @EXPORT    = qw(%TRAP %CONFIG);
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
if ( -e $ENV{'HOME'}."/.trap_config.ini") {
   tie %TRAP, "Config::Simple", $ENV{'HOME'}."/.trap_config.ini";
}
#Use the supfamconfig in the current working directory useful for CGI scripts that dont have a home
elsif (-e ".trap_config.ini") {
   tie %TRAP, "Config::Simple", ".trap_config.ini";
}
#Try to load the default from the Supfam package
elsif (-e $mod_path."trap_config.ini") {
   tie %TRAP, "Config::Simple", $mod_path.'trap_config.ini';
}
#Warn that we don't have a config for the package
else {
   carp "Cannot locate the global trap_config.ini for TraP:: modules, looking in: ".$ENV{'HOME'}."/.trap_config.ini or ".$mod_path.'trap_config.ini';
}

1;
__END__
