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
my $graph = Graph::Easy->new( );
my $cgi = CGI->new;
print $cgi->header;
my $dbh = dbConnect('rackham','localhost','projects',undef);
my $sth;
my @nodes;
#$query = "SELECT ?,? FROM ?";
#$values = "id,value,delme";
my $table = $cgi->param('table'); 
my $outtype = $cgi->param('outtype');
my $sg = $cgi->param('sg'); 
unless(defined($sg)){
$sg = 0;
}




print <<ENDHTML
	<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
	<html>
    
    <head>
        <title>Cytoscape Web example</title>
        
        <!-- JSON support for IE (needed to use JS API) -->
        <script type="text/javascript" src="../javascript/js/min/json2.min.js"></script>
        
        <!-- Flash embedding utility (needed to embed Cytoscape Web) -->
        <script type="text/javascript" src="../javascript/js/min/AC_OETags.min.js"></script>
        
        <!-- Cytoscape Web JS API (needed to reference org.cytoscapeweb.Visualization) -->
        <script type="text/javascript" src="../javascript/js/min/cytoscapeweb.min.js"></script>
            <script type="text/javascript" src="../javascript/jquery.js"></script>
        <script type="text/javascript">
        
            window.onload=function() {
                // id of Cytoscape Web container div
                window.div_id = "cytoscapeweb";
                
 	
	window.current = $sg;
	window.next = window.current + 1;
	window.prev = window.current -1;


\$.ajax({url: 'network_data.cgi', data: {values: 'source_node,edge_value,target_node', table: 'networks', wherefields: 'type,source,cluster_id', wherevalues: 'MCODE,adip_tc_mint,meta' , sg: window.current, outtype: 'ml'}, async: false, dataType: 'graphml', type: 'GET', success: function(reply,text) { window.data = reply; }});
\$.ajax({url: 'network_data.cgi', data: {values: 'source_node,edge_value,target_node', table: 'networks', wherefields: 'type,source,cluster_id', wherevalues: 'MCODE,adip_tc_mint,meta' , sg: window.next, outtype: 'ml'}, async: false, dataType: 'graphml', type: 'GET', success: function(reply,text) { window.datanext = reply; }});
\$.ajax({url: 'network_data.cgi', data: {values: 'source_node,edge_value,target_node', table: 'networks', wherefields: 'type,source,cluster_id', wherevalues: 'MCODE,adip_tc_mint,meta' , sg: window.prev, outtype: 'ml'}, async: false, dataType: 'graphml', type: 'GET', success: function(reply,text) { window.dataprev = reply; }});

                    window.visual_style = {
                    global: {
                        backgroundColor: "#ABCFD6"
                    },
                    nodes: {
                        shape: "ELLIPSE",
                        size: 50,
                        borderWidth: 3,
                        borderColor: "#ffffff",
                        color: { passthroughMapper: { attrName: "color" } },
                        labelHorizontalAnchor: "center"
                    },
                    edges: {
                        width: 3,
                        color: "#0B94B1"
                    }
                };

                
                // initialization options
                window.options = {
                    // where you have the Cytoscape Web SWF
                    swfPath: "../javascript/swf/CytoscapeWeb",
                    // where you have the Flash installer SWF
                    flashInstallerPath: "../javascript/swf/playerProductInstall"
                };
                

                
                 window.draw_options = {
                    // your data goes here
                    network: window.data,
                    
                    // show edge labels too
                    edgeLabelsVisible: false,
                    
                    // set the style at initialisation
                    visualStyle: window.visual_style,
                    
                    layout: 'Radial',
                    
                };
                // init and draw
                window.vis = new org.cytoscapeweb.Visualization(window.div_id, window.options);
				window.vis.ready(function() {
                
                    // add a listener for when nodes and edges are clicked
                    window.vis.addListener("click", "nodes", function(event) {
                        handle_click(event);
                    })
                    window.vis.addListener("click", "edges", function(event) {
                        handle_click(event);
                    });
                    
                                       
                });
     
                   window.vis.draw(window.draw_options);   
                   
            };
            
            function handle_click(event) {
                    	
                         var target = event.target;
                         
                         \$.ajax({url: 'network_data.cgi', data: {values: 'source_node,edge_value,target_node', table: 'networks', wherefields: 'type,source,cluster_id', wherevalues: 'MCODE,adip_tc_mint,'+event.target.data.label , sg: window.current, outtype: 'ml', level: '1'}, async: false, dataType: 'graphml', type: 'GET', success: function(reply,text) { window.nodedata = reply; }});

                   window.draw_options2 = {
                    // your data goes here
                    network: window.nodedata,
                    
                    // show edge labels too
                    edgeLabelsVisible: false,
                    
                    // set the style at initialisation
                    visualStyle: window.visual_style,
                    
                    layout: 'Radial',
                    
                };
                   
                   window.vis2 = new org.cytoscapeweb.Visualization('nodes', window.options);
				window.vis2.ready(function() {
                
                    // add a listener for when nodes and edges are clicked
                    window.vis2.addListener("click", "nodes", function(event) {
                        handle_click2(event);
                    })
                    window.vis2.addListener("click", "edges", function(event) {
                        handle_click2(event);
                    });
                    
                    function handle_click2(event) {
                    	
                         var target = event.target;
                         
                         note_clear();
                         note_print("event.group = " + event.group);
                         for (var i in target.data) {
                            var variable_name = i;
                            var variable_value = target.data[i];
                            note_print( "event.target.data." + variable_name + " = " + variable_value );
                            
                         }
                         
                    }
                    function note_clear() {
                        document.getElementById("note").innerHTML = "";
                    }
                
                    function note_print(msg) {
                        document.getElementById("note").innerHTML += "<p>" + msg + "</p>";
                    }                       
                });
     
                   window.vis2.draw(window.draw_options2); 

                         
                    }  
            //PREVIOUS IS HERE
            function prev_group(vis,draw_options) {
             		window.draw_options = {
                    // your data goes here
                    network: window.dataprev,

                    // show edge labels too
                    edgeLabelsVisible: false,
                    
                    // set the style at initialisation
                    visualStyle: window.visual_style,
                    
                    layout: 'Radial',   
                	};
                	window.current = window.current - 1;
             		window.prev = window.prev - 1;
             		window.next = window.next - 1;
                     
                    window.vis = new org.cytoscapeweb.Visualization(window.div_id, window.options);
					window.vis.ready(function() {
                
                    // add a listener for when nodes and edges are clicked
                    window.vis.addListener("click", "nodes", function(event) {
                        handle_click(event);
                    })
                    window.vis.addListener("click", "edges", function(event) {
                        handle_click(event);
                    });
                    
                    
                     
                    
                    
                    
                    
                    
                    
                         
                });
                
                    
                    
                
                    
                window.vis.draw(window.draw_options);
                \$.ajax({url: 'network_data.cgi', data: {values: 'source_node,edge_value,target_node', table: 'networks', wherefields: 'type,source,cluster_id', wherevalues: 'MCODE,adip_tc_mint,meta' , sg: window.next, outtype: 'ml'}, async: false, dataType: 'graphml', type: 'GET', success: function(reply,text) { window.datanext = reply; }}); 
                \$.ajax({url: 'network_data.cgi', data: {values: 'source_node,edge_value,target_node', table: 'networks', wherefields: 'type,source,cluster_id', wherevalues: 'MCODE,adip_tc_mint,meta' , sg: window.prev, outtype: 'ml'}, async: false, dataType: 'graphml', type: 'GET', success: function(reply,text) { window.dataprev = reply; }});  


             }
           //NEXT IS HERE
           function next_group(vis,draw_options) {
           				window.draw_options = {
                    // your data goes here
                    network: window.datanext,
                    
                    // show edge labels too
                    edgeLabelsVisible: false,
                    
                    // set the style at initialisation
                    visualStyle: window.visual_style,
                    
                    layout: 'Radial',
                    
                };
           				window.current = window.current + 1;
           				window.prev = window.prev + 1;
             			window.next = window.next + 1;
						window.vis = new org.cytoscapeweb.Visualization(window.div_id, window.options);
				window.vis.ready(function() {
                
                    // add a listener for when nodes and edges are clicked
                    window.vis.addListener("click", "nodes", function(event) {
                        handle_click(event);
                    })
                    window.vis.addListener("click", "edges", function(event) {
                        handle_click(event);
                    });
                    
                    
                     
                    
                    
                    
                    
                    
                    
                         
                });
                
                    
                    
                
                    
                   window.vis.draw(window.draw_options);
                \$.ajax({url: 'network_data.cgi', data: {values: 'source_node,edge_value,target_node', table: 'networks', wherefields: 'type,source,cluster_id', wherevalues: 'MCODE,adip_tc_mint,meta' , sg: window.next, outtype: 'ml'}, async: false, dataType: 'graphml', type: 'GET', success: function(reply,text) { window.datanext = reply; }}); 
                \$.ajax({url: 'network_data.cgi', data: {values: 'source_node,edge_value,target_node', table: 'networks', wherefields: 'type,source,cluster_id', wherevalues: 'MCODE,adip_tc_mint,meta' , sg: window.prev, outtype: 'ml'}, async: false, dataType: 'graphml', type: 'GET', success: function(reply,text) { window.dataprev = reply; }});  

                    }

        </script>
        
        <style>
            /* The Cytoscape Web container must have its dimensions set. */
            html, body { height: 100%; width: 100%; padding: 0; margin: 0; }
            #cytoscapeweb { width: 100%; height: 100%; }
        </style>
    </head>
    
    <body>
    	<div id="buttons">
    		<table>
    			<tr>
    				<td>
    					<INPUT TYPE="button" NAME="PreviousBtn" VALUE="Previous" id="prev" onclick="prev_group(window.vis,window.draw_options)"> 
    				</td>
    				<td>
    					<INPUT TYPE="button" NAME="NextBtn" VALUE="Next" id="next" onclick="next_group(window.vis,window.draw_options)"> 
    				</td>
    			<tr>
    		</table>
    	</div>
        <div id="cytoscapeweb">
            Cytoscape Web will replace the contents of this div with your graph.
        </div>
          <div id="nodes">
            <p>node graphs will appear here once you click on one!.</p>
        </div>
        <table>
        <tr>
        <td>
        <h3>Node Info</h3>
                <div id="note">
            <p>Click nodes or edges.</p>
        </div>
        </td>
        <td>
        <h3>Cluster Info</h3>
        </div>
                <div id="cluster_note">
            <p>Click cluster or edges.</p>
        </div>
        </td>
        </tr>
        </table>
    </body>
    
</html>
ENDHTML
