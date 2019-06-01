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
module GinLeakUnit
#(
	parameter INTEGER_WIDTH = 16, 
	parameter DATA_WIDTH_FRAC = 32,
	parameter DATA_WIDTH = INTEGER_WIDTH + DATA_WIDTH_FRAC, 
	parameter DELTAT_WIDTH = 4
)
(
	
	input wire signed [(DATA_WIDTH-1):0] gin,
	input wire signed [(DELTAT_WIDTH-1):0] DeltaT,
	input wire signed [(INTEGER_WIDTH-1):0] Taugin,
	

	output wire signed [(DATA_WIDTH-1):0] ginOut
);

 
	//Intermediate Values:
	wire signed [(INTEGER_WIDTH-1):0] MultResult_Int;
	wire signed [(DATA_WIDTH_FRAC-1):0] MultResult_Frac;
	wire signed [(DATA_WIDTH-1):0] DeltaT_Extended, MultResult, Taugin_Extended, Quotient;
	wire signed [(DATA_WIDTH + DATA_WIDTH_FRAC - 1):0] Dividend; 

	wire signed [(DATA_WIDTH-1):0] V1;
	wire signed [(2*DATA_WIDTH -1):0] V2;
	wire signed [(DATA_WIDTH + DATA_WIDTH_FRAC - 1):0] V3;


	//Wire Select and/or padding for Fixed-point Arithmetic
	assign DeltaT_Extended = {{INTEGER_WIDTH{1'b0}},DeltaT,{DATA_WIDTH_FRAC-DELTAT_WIDTH{1'b0}}};                         //pad integer bits and rest of fractional bits 
	assign MultResult_Int = V2[(DATA_WIDTH + DATA_WIDTH_FRAC - 1):(DATA_WIDTH + DATA_WIDTH_FRAC - INTEGER_WIDTH)];        //take lower <INTEGER_WIDTH> integer bits of product
	assign MultResult_Frac = V2[(DATA_WIDTH + DATA_WIDTH_FRAC - INTEGER_WIDTH - 1):DATA_WIDTH_FRAC];                      //take higher <DATA_WIDTH_FRAC> frac bits of product
	assign MultResult = {MultResult_Int,MultResult_Frac};                                                                 //concatenate to form product in given format
	assign Taugin_Extended = {Taugin,{DATA_WIDTH_FRAC{1'b0}}};                                                            //pad fractional bits
	assign Dividend = {MultResult,{DATA_WIDTH_FRAC{1'b0}}};                                                               //shift by all decimal places before division
	assign Quotient = V3[(DATA_WIDTH-1):0];                                                                               //take lower <DATA_WIDTH> bits of Division result



	//Combinational Computation
	assign V1 = -gin;
	assign V2 = V1*DeltaT_Extended;
	assign V3 = Dividend/Taugin_Extended;
	assign ginOut = gin + Quotient; 


endmodule


