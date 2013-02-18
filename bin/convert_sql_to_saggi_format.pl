#!/usr/bin/env perl

use strict;
use warnings;



        open FH, "$ARGV[0]" or die $!."\t".$?;
	my %data;
        while(my $line = <FH>){
	chomp($line);
        my ($from,$to)=split(/\s+/,$line);
	$data{$from}{$to} = 1;
	}

	foreach my $f (sort keys %data){
		print "$f\t";
		print(join(',',(keys %{$data{$f}})));
		print "\n";
	}

