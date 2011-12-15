#!/usr/bin/env perl

package Utils::SQL;
require Exporter;
require SelfLoader;

=head1 NAME

Utils::SQL::Connect.pm

=head1 SYNOPSIS

Connect to a database using configs

=head1 AUTHOR

Matt Oates (Matt.Oates@bristol.ac.uk)

=head1 COPYRIGHT


=head1 SEE ALSO

Utils::Config.pm

=head1 DESCRIPTION

=cut

our @ISA = qw(Exporter SelfLoader);

our %EXPORT_TAGS = (
'all' => [ qw(
			dbConnect
			dbDisconnect
) ],
'connect' => [ qw(
			dbConnect
			dbDisconnect
) ],
);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

our $VERSION   = 1.00;

use strict;
use warnings;

use DBI;

use Utils::Config;

use lib ("../../");


=pod
=head2 Methods
=over 4
=cut


sub dbConnect {
	my ($database,$host,$user,$password);
	my $c = ''; #Which database config to use

	#Auto fill from database specific config any settings the calling function didn't specify, otherwise use defaults
	if (@_) {
		($database,$host,$user,$password) = @_;
		#If a specific database config exists use it, otherwise default
		$c = (exists $CONFIG{"database.$database"})?"database.$database":'database';
		$database = $CONFIG{"$c.name"} unless $database;
		$host = $CONFIG{"$c.host"} unless $host;
		$user = $CONFIG{"$c.user"} unless $user;
		$password = $CONFIG{"$c.password"} unless $password;
	}
	#Use default database config, which is SUPERFAMILY
	else {
		($database,$host,$user,$password) = ($CONFIG{'database.name'},$CONFIG{'database.host'},$CONFIG{'database.user'},undef);
	}

	return DBI->connect("DBI:mysql:dbname=$database;host=$host"
	                                        ,$user
	                                        ,$password
	                                        ,{RaiseError =>1}
	                                    ) or die "Fatal Error: couldn't connect to $database on $host";
}

sub dbDisconnect {
	my $dbh = shift;
	warn "Closing Database Connection!\n";
	return $dbh->disconnect();
}

=pod

=back

=cut

1;

__DATA__
