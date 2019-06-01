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
module EPSCUnit
#(
	parameter INTEGER_WIDTH = 16,
	parameter DATA_WIDTH_FRAC = 32,
	parameter DATA_WIDTH = INTEGER_WIDTH + DATA_WIDTH_FRAC, 
	parameter DELTAT_WIDTH = 4
)
(

	input wire signed [(INTEGER_WIDTH-1):0] Eex,
	input wire signed [(DATA_WIDTH-1):0] Vmem,
	input wire signed [(DATA_WIDTH-1):0] gex,
	input wire signed [(DELTAT_WIDTH-1):0] DeltaT,
	input wire signed [(INTEGER_WIDTH-1):0] Taumem,
	

	output wire signed [(DATA_WIDTH-1):0] EPSCOut
);

	//Intermediate Values:
	wire signed [(INTEGER_WIDTH-1):0] Mult1Result_Int, Mult2Result_Int;
	wire signed [(DATA_WIDTH_FRAC-1):0] Mult1Result_Frac, Mult2Result_Frac;
	wire signed [(DATA_WIDTH-1):0] Eex_Extended, DeltaT_Extended, Mult1Result, Mult2Result, Taumem_Extended, Quotient;
	wire signed [(DATA_WIDTH + DATA_WIDTH_FRAC - 1):0] Dividend;

	wire signed [(DATA_WIDTH-1):0] V1;
	wire signed [(2*DATA_WIDTH -1):0] V2,V4;
	wire signed [(DATA_WIDTH + DATA_WIDTH_FRAC - 1):0] V3;



	//Wire Select and/or padding for Fixed-point Arithmetic
	assign Eex_Extended = {Eex, {DATA_WIDTH_FRAC{1'b0}}};                                                                  //pad fractional bits
	assign DeltaT_Extended = {{INTEGER_WIDTH{1'b0}},DeltaT,{DATA_WIDTH_FRAC-DELTAT_WIDTH{1'b0}}};                          //pad integer bits and rest of fractional bits 
	assign Mult1Result_Int = V2[(DATA_WIDTH + DATA_WIDTH_FRAC - 1):(DATA_WIDTH + DATA_WIDTH_FRAC - INTEGER_WIDTH)];        //take lower <INTEGER_WIDTH> integer bits of product
	assign Mult1Result_Frac = V2[(DATA_WIDTH + DATA_WIDTH_FRAC - INTEGER_WIDTH - 1):DATA_WIDTH_FRAC];                      //take higher <DATA_WIDTH_FRAC> frac bits of product
	assign Mult1Result = {Mult1Result_Int,Mult1Result_Frac};                                                               //concatenate to form product in given format
	assign Mult2Result_Int = V4[(DATA_WIDTH + DATA_WIDTH_FRAC - 1):(DATA_WIDTH + DATA_WIDTH_FRAC - INTEGER_WIDTH)];        //take lower <INTEGER_WIDTH> integer bits of product
	assign Mult2Result_Frac = V4[(DATA_WIDTH + DATA_WIDTH_FRAC - INTEGER_WIDTH - 1):DATA_WIDTH_FRAC];                      //take higher <DATA_WIDTH_FRAC> frac bits of product
	assign Mult2Result = {Mult2Result_Int,Mult2Result_Frac};                                                               //concatenate to form product in given format
	assign Taumem_Extended = {Taumem, {DATA_WIDTH_FRAC{1'b0}}};                                                            //pad fractional bits
	assign Dividend = {Mult1Result,{DATA_WIDTH_FRAC{1'b0}}};                                                               //shift by all decimal places before division
	assign Quotient = V3[(DATA_WIDTH-1):0];                                                                                //take lower <DATA_WIDTH> bits of Division result



	//Combinational computation
	assign V1 = Eex_Extended - Vmem;
	assign V2 = V1*DeltaT_Extended;
	assign V3 = Dividend/Taumem_Extended;
	assign V4 = Quotient*gex;
	assign EPSCOut = Mult2Result;


	endmodule

		
		
		
		
		
