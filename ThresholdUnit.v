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
module ThresholdUnit
#(
	parameter INTEGER_WIDTH = 16, 
	parameter DATA_WIDTH_FRAC = 32,
	parameter DATA_WIDTH = INTEGER_WIDTH + DATA_WIDTH_FRAC
)
(

	input wire signed [(DATA_WIDTH-1):0] Vth,
	input wire signed [(DATA_WIDTH-1):0] Vmem,
	input wire signed [(INTEGER_WIDTH-1):0] Vreset,

	output wire signed [(DATA_WIDTH-1):0] VmemOut,
	output wire SpikeOut 
);

	//Intermediate Values:
	wire signed [(DATA_WIDTH-1):0] Vreset_Extended;


	//Wire Select and/or padding for Fixed-point Arithmetic
	assign Vreset_Extended = {Vreset,{DATA_WIDTH_FRAC{1'b0}}};              //pad fractional bits 



	//Combinational Computation

	assign SpikeOut = (Vmem >= Vth) ? 1'b1 : 1'b0;
	assign VmemOut = (Vmem >= Vth) ? Vreset_Extended : Vmem;


	endmodule
