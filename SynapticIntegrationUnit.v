/*
-----------------------------------------------------
| Created on: 12.07.2018		            							
| Author: Saunak Saha				    
|                                                   
| Department of Electrical and Computer Engineering  
| Iowa State University                             
-----------------------------------------------------
*/



`timescale 1ns/1ns
module SynapticIntegrationUnit
#(
	parameter INTEGER_WIDTH = 16,
	parameter DATA_WIDTH_FRAC = 32,
	parameter DATA_WIDTH = INTEGER_WIDTH + DATA_WIDTH_FRAC
)
(
		
	

	input wire signed [(DATA_WIDTH-1):0] gex,
	input wire signed [(DATA_WIDTH-1):0] gin,

	input wire signed [(DATA_WIDTH-1):0] ExWeightSum,
	input wire signed [(DATA_WIDTH-1):0] InWeightSum,

	output wire signed [(DATA_WIDTH-1):0] gexOut,
	output wire signed [(DATA_WIDTH-1):0] ginOut
);



	//Combinational Computation
	assign gexOut = gex + ExWeightSum; 
	assign ginOut = gin + InWeightSum; 


	endmodule
