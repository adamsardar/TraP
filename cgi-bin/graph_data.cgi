#!/usr/bin/env perl

use strict;
use warnings;
use lib "/home/projects/lib";

use CGI qw(:standard);
use JSON;
use DBI;
use Supfam::SQLFunc;

my $cgi = CGI->new;
print $cgi->header;

my $dbh = dbConnect();
my $sth;
#$query = "SELECT ?,? FROM ?";
#$values = "id,value,delme";
my $table = $cgi->param('table');
my @values = split(/,/,$cgi->param('values'));
my $vals=join(',',@values);
my $call = "SELECT $vals FROM $table";
$sth=$dbh->prepare( $call );
$sth->execute();
my @data;
my @axis = ('x','y','z','a','b','c');
 while (my @temp = $sth->fetchrow_array ) {
 	my $c = 0;
 	my %point;
 	foreach (@temp){
 	$point{$axis[$c++]} = $_;
	}
 	push (@data, \%point);
 }
 
  my $return_text = to_json(\@data);
  
  print $return_text;
 
 
