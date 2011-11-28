#!/usr/bin/env perl


use strict;
use warnings;
use lib "/home/projects/lib";
use Graph::Easy;
use CGI qw(:standard);
use JSON;
use DBI;
use Supfam::SQLFunc;
use POSIX;
use List::Util qw[min max];

my $hash_ref->{'undirected'} = 1;
my $graph = Graph::Easy->new($hash_ref);
my $cgi = CGI->new;
print $cgi->header;
my $dbh = dbConnect('rackham','localhost','projects',undef);
my $sth;
my @nodes;
#$query = "SELECT ?,? FROM ?";
#$values = "id,value,delme";
my $table = $cgi->param('table'); 
my $outtype = $cgi->param('outtype');
unless(defined($outtype)){
$outtype = 'ml';
}
my $sg = $cgi->param('sg'); 
unless(defined($sg)){
$sg = 1;
}


#select source_node,edge_value,target_node from networks where type='MCODE' and source ='adip_tc_min' and cluster_id='meta';
my @values = split(/,/,$cgi->param('values'));
my $vals=join(',',@values);
my @wherefields = split(/,/,$cgi->param('wherefields'));
my @wherevalues = split(/,/,$cgi->param('wherevalues'));
my @where;
my %lookup;
for (my $count = 0; $count <= (scalar(@wherefields)-1); $count++) {
 	push(@where,"$wherefields[$count]='$wherevalues[$count]'");
 	$lookup{$wherefields[$count]} = "'$wherevalues[$count]'";
 }


 my $level = $cgi->param('level'); 
 unless(defined($level)){
 $level = 0;
 }
 my $cluster = $cgi->param('cluster'); 
 unless(defined($cluster)){
 $cluster = 1;
 }
if($level == 0){
my %cluster_vals;
my @vals;
	my $call = "SELECT ClusterID,value_double FROM meta_expression_analysis where source = $lookup{'source'} and sample_groupID = $sg";
	$sth=$dbh->prepare( $call );
	$sth->execute();
	while (my @temp = $sth->fetchrow_array ) {
		$cluster_vals{$temp[0]} = $temp[1];
		push(@vals, $temp[1]);
	}
	my $max = max(@vals);
	my $min = min(@vals);
	 	my $call = "select distinct(ClusterID) from clusters where source = $lookup{'source'} and type = $lookup{'type'} order by ClusterID;";
	$sth=$dbh->prepare( $call );
	$sth->execute();
	while (my @temp = $sth->fetchrow_array ) {
		if(exists($cluster_vals{$temp[0]})){
			my %node;
			$node{'nodeName'} = "$temp[0]";
			$node{'value'} = "$cluster_vals{$temp[0]}";
			$node{'group'} = "$temp[0]";
			push (@nodes, \%node);
			my $node = $graph->add_node( "$temp[0]");
			$node->set_attribute('label', "$temp[0]");
			$node->set_attribute('comment', "$cluster_vals{$temp[0]}");
			my $color = ColourCalc($max,$min,$cluster_vals{$temp[0]});
			
			$color = Graph::Easy->color_as_hex( "$color" );
			$node->set_attribute('color', "$color");
		}else{
			my %node;
			$node{'nodeName'} = "$temp[0]";
			$node{'value'} = "1";
			$node{'group'} = "$temp[0]";
			push (@nodes, \%node);
			my $node = $graph->add_node( "$temp[0]");
			$node->set_attribute('label', "1");
			$node->set_attribute('comment', "1");
			my $color = ColourCalc($max,$min,1);
			$color = Graph::Easy->color_as_hex( "$color" );
			$node->set_attribute('color', "$color");
			
			
		}
	}



#http://luca.cs.bris.ac.uk/~projects/cgi-bin/network_data.cgi?values=source_node,edge_value,target_node&table=networks&wherefields=type,source,cluster_id&wherevalues=%27MCODE%27,%27adip_tc_mint%27,%27meta%27&sg=1


 my $where = join(' and ', @where);
my $call = "SELECT $vals FROM $table";

my $call = $call." WHERE ".$where;

$sth=$dbh->prepare( $call );
$sth->execute();
my @links;
 while (my @temp = $sth->fetchrow_array ) {
 	my %link;
 	#####THIS NEEDS TO BE $temp[0] -1 if you are using JSON its crap!
 	$link{'source'} = ($temp[0]-1);
 	$link{'target'} = ($temp[2]-1);
 	$link{'value'} = 1;
 	#$link{'value'} = $temp[1];
	$graph->add_edge($temp[0], $temp[2]);
 	push (@links, \%link);
 	
 }

 my %data;
 $data{'links'} = \@links;
 $data{'nodes'} = \@nodes;
 unless($outtype eq 'ml'){
  my $return_text = to_json(\%data);
  print $return_text;
  }else{
  print $graph->as_graphml();
  }
 }else{
	my %node_vals;
	my @vals;
	my $call = "SELECT GeneID,value_double FROM expression_analysis where source = $lookup{'source'} and sample_groupID = $sg";
	$sth=$dbh->prepare( $call );
	$sth->execute();
	while (my @temp = $sth->fetchrow_array ) {
		$node_vals{$temp[0]} = $temp[1];
		push(@vals, $temp[1]);
	}
	my $max = 1.000001;
	my $min = min(@vals);
	my $call = "select source_node,target_node from networks where type = $lookup{'type'} and source = $lookup{'source'} and cluster_id = $lookup{'cluster_id'};";
	$sth=$dbh->prepare( $call );
	$sth->execute();
	my %nodes;
	my %edges;
	while (my @temp = $sth->fetchrow_array ) {
		unless(exists($nodes{$temp[0]})){
			if(exists($node_vals{$temp[0]})){
				my $node = $graph->add_node( "$temp[0]");
				$node->set_attribute('label', "$temp[0]");
				$node->set_attribute('comment', "$node_vals{$temp[0]}");
				my $color = ColourCalc($max,$min,$node_vals{$temp[0]});
				$color = Graph::Easy->color_as_hex( "$color" );
				$node->set_attribute('color', "$color");
			}else{
				my $node = $graph->add_node( "$temp[0]");
				$node->set_attribute('label', "$temp[0]");
				$node->set_attribute('comment', "1");
				my $color = ColourCalc($max,$min,1);
				$color = Graph::Easy->color_as_hex( "$color" );
				$node->set_attribute('color', "$color");
			}
		}
		unless(exists($nodes{$temp[1]})){
			if(exists($node_vals{$temp[1]})){
				my $node = $graph->add_node( "$temp[1]");
				$node->set_attribute('label', "$temp[1]");
				$node->set_attribute('comment', "$node_vals{$temp[1]}");
				my $color = ColourCalc($max,$min,$node_vals{$temp[1]});
				$color = Graph::Easy->color_as_hex( "$color" );
				$node->set_attribute('color', "$color");
			}else{
				my $node = $graph->add_node( "$temp[1]");
				$node->set_attribute('label', "$temp[1]");
				$node->set_attribute('comment', "1");
				my $color = ColourCalc($max,$min,1);
				$color = Graph::Easy->color_as_hex( "$color" );
				$node->set_attribute('color', "$color");
			}
		}
		
		$nodes{$temp[0]} = 1;
		$nodes{$temp[1]} = 1;
		$graph->add_edge($temp[0], $temp[1]);
		
	}
	print $graph->as_graphml();
	
}
 
 sub ColourCalc {
	my $max = shift;
	my $min = shift;
	my $current = shift;
	my $diff = ((($current - $min))/($max - $min))*255;
	my $b = floor(0+$diff);
	
	my $colour = "rgb(0,$b,$b)";
	#my $colour = $diff;
    return $colour;
}