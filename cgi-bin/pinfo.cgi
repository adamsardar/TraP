#!/bin/bash

#Go CGI!
. /usr/local/bin/bashlib

#Script to pull out all information for proteins specified from the SUPERFAMILY database

#SQL to get all the taxon_id for a species below a certain point e.g. Viridiplantae
#select node.taxon_id,node.name from ncbi_taxonomy as node, ncbi_taxonomy as parent where parent.taxon_id=33090 and (node.left_id between parent.left_id and parent.right_id) and (node.left_id=node.right_id-1);

version=1.0
usage=$( cat <<EOF
<h1>`basename $0`</h1>
<p>
<strong>Usage:</strong><br />
<i>`basename $0`?proteins=3389847,3389848,3389849&genomes=up,at&fasta=1&dryrun=0</i><br /><hr />
</p>
EOF
)

#Output this script if someone asks for it
if [ `param "source"` == "show" ]; then
echo "Content-type: text/plain"
echo ""
cat `basename $0`
exit
fi

#Output the HTML header at the first opportunity
echo "Content-type: text/html"
echo ""

#If there is no input to the page create a form to submit input to self
if [ "$QUERY_STRING" == "" ]; then
cat <<EOF
<html>
<head>
	<title>Get Protein Information</title>
</head>
<body>
	$usage
	<form action="`basename $0`" method="post">
		<label for="proteins">Proteins*:</label>&nbsp;&nbsp;<input type="text" name="proteins" id="proteins" value="3389847,3389848,3389849" /><br />
		<label for="genomes">Genomes:</label>&nbsp;&nbsp;<input type="text" name="genomes" id="genomes" value="up,at" /><br />
		<input type="checkbox" checked="checked" name="fasta" id="fasta" value="1" /><label for="fasta">Output FASTA sequences?</label><br />
		<input type="checkbox" name="dryrun" id="dryrun" value="1" /><label for="dryrun">Do a dry run and get SQL used?</label><br />
		<input type="submit" name="submit" id="submit" value="Submit" />
	<form>
</body>
</html>
EOF
exit
fi

#Otherwise process form input and output results

genomes=`param genomes`
proteins=`param proteins`
proteins=`echo "$proteins" | tr ',' ' '`
fasta=`param fasta`
[ "$fasta" == "" ] && fasta=0;
dry_run=`param dryrun`
[ "$dry_run" == "" ] && dry_run=0;

function sfam_protein_info {
local just_echo=$1
local protein=$2
local genomes=$3
local ingenomes='?'
local nproteins='?'
local uniprotids='?'

echo "<p>"
	
	SQL="SELECT count(protein) FROM protein WHERE protein = '$protein';"
        if [ $just_echo = 1 ]; then
		echo "echo \"$SQL\" | \mysql -bNA superfamily | tr '\n' ' '";
        else 
		nproteins=`echo "$SQL" | \mysql -bNA superfamily | tr '\n' ' '`;
        fi

	SQL="SELECT DISTINCT genome FROM protein WHERE protein = '$protein';"
        if [ $just_echo = 1 ]; then
		echo "echo \"$SQL\" | \mysql -bNA superfamily | tr '\n' ' '";
        else
		ingenomes=`echo "$SQL" | \mysql -bNA superfamily | tr '\n' ' '  | sed "s/ $//;s/[^ ]*/<strong>&<\/strong>,/g;s/[, ]*$//"`;
        fi

	SQL="SELECT protein.seqid FROM protein WHERE protein = '$protein' and protein.genome = 'up';"
        if [ $just_echo = 1 ]; then
		echo "echo \"$SQL\" | \mysql -bnA superfamily | sed 's/\t/\n/g;s/^/>/;'";
        else
		uniprotids=`echo "$SQL" | \mysql -bNA superfamily | tr '\n' ' ' | sed "s/ $//;s/[^ ]*/<strong>&<\/strong>,/g;s/[, ]*$//"`;
        fi
	echo -e "Protein <i>$protein</i> is found <strong>${nproteins}</strong>times in: ${ingenomes} genomes\n<br />\nIdentified by UniProt IDs: $uniprotids\n<br />\n"
	if [ $fasta -eq 1 ]; then
	echo -e "Sequences:\n<br/>\n<pre>\n"

	SQL="SELECT protein.seqid,genome_sequence.sequence FROM protein,genome_sequence WHERE genome_sequence.protein=protein.protein AND protein.protein = '$protein' $genomes;"
	if [ $just_echo = 1 ]; then
		echo "echo \"$SQL\" | \mysql -bnA superfamily | sed 's/\t/\n/g;s/^/>/;'";
	else
		echo "$SQL" | \mysql -bNA superfamily | sed 's/\t/\n/g;s/^/>/;';
	fi

	fi
	echo -e "\n</pre>\n<br /><hr />"
echo "</p>"

}

#If we have a genomes list then make add it as a constraint in the queries
if [ "$genomes" != "" ]; then
	genomes=`echo $genomes | sed "s/[^,]*/\'&\'/g"`
	genomes="AND protein.genome IN ($genomes)"
fi

if [ "$proteins" == "" ]; then
	echo "<h1>No Proteins Defined!</h1><br /><p>$usage</p>" && exit 1;
fi

echo "<html><head><title>Protein Info</title></head><body>"

#For all the proteins defined in input files
for protein in $proteins
do
	sfam_protein_info "$dry_run" "$protein" "$genomes"
done

echo "</body></html>"
