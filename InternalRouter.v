/*
-----------------------------------------------------
| Created on: 12.20.2018		            						
| Author: Saunak Saha				    
|                                                  
| Department of Electrical and Computer Engineering 
| Iowa State University                             
-----------------------------------------------------
*/



`timescale 1ns/1ns
module InternalRouter
#(
	parameter NEURON_WIDTH_LOGICAL = 11,
	parameter NEURON_WIDTH = NEURON_WIDTH_LOGICAL, 
	parameter BT_WIDTH = 36, 
	parameter DELTAT_WIDTH = 4
)	
(
	//Control Inputs
	input wire Clock,
	input wire Reset,
	input wire RouteEnable,
	input wire [(BT_WIDTH-1):0] Current_BT,

	//Network Information 
	input wire [(NEURON_WIDTH-1):0] NeuStart, 
	input wire [(NEURON_WIDTH-1):0] OutRangeLOWER,
	input wire [(NEURON_WIDTH-1):0] OutRangeUPPER,

	//Global Inputs
	input wire [(DELTAT_WIDTH-1):0] DeltaT,

	//Input from NeuronUnit
	input wire [(2**NEURON_WIDTH-1):0] SpikeBuffer,				

	//output to Auxiliary Queue and maybe Output Queue
	output reg [(BT_WIDTH-1):0] ToAuxBTOut,
	output reg [(NEURON_WIDTH-1):0] ToAuxNIDOut,
	output reg [(BT_WIDTH-1):0] ToOutBTOut,
	output reg [(NEURON_WIDTH-1):0] ToOutNIDOut,

	//Control Outputs
	output reg ToAuxEnqueueOut,
	output reg ToOutEnqueueOut,
	output reg RoutingComplete

);


	wire [BT_WIDTH-1:0] DeltaT_Extended;
	reg [(NEURON_WIDTH-1):0] Current_NID;
	reg Spike;

	assign DeltaT_Extended = {{BT_WIDTH-DELTAT_WIDTH{1'b0}},DeltaT};	//pad integer bits
	
	always @ (posedge Clock) begin 
	
		if (Reset) begin 
			
			Current_NID = 0;
			Spike = 0;
			ToAuxEnqueueOut = 0;
			ToOutEnqueueOut = 0;
			RoutingComplete = 0;
			ToAuxBTOut = 0;
			ToAuxNIDOut = 0;
			ToOutBTOut = 0;
			ToOutNIDOut = 0;

		end

		else if (RouteEnable) begin 

			Spike = SpikeBuffer[Current_NID];

			ToAuxEnqueueOut = (Spike)? 1 : 0;
			ToAuxBTOut = (Spike)? Current_BT + DeltaT_Extended : 0;
			ToAuxNIDOut = (Spike)? Current_NID + NeuStart : 0;

			ToOutEnqueueOut = (Spike && (Current_NID+NeuStart >= OutRangeLOWER) && (Current_NID+NeuStart <= OutRangeUPPER)) ? 1 : 0;

			ToOutBTOut = (Spike && (Current_NID+NeuStart >= OutRangeLOWER) && (Current_NID+NeuStart <= OutRangeUPPER)) ? Current_BT + DeltaT_Extended : 0;
			ToOutNIDOut = (Spike && (Current_NID+NeuStart >= OutRangeLOWER) && (Current_NID+NeuStart <= OutRangeUPPER)) ? Current_NID + NeuStart : 0;

			RoutingComplete = (Current_NID < 2**NEURON_WIDTH -1) ? 0 : 1;
			Current_NID = (Current_NID < 2**NEURON_WIDTH -1) ? Current_NID + 1 : 0;
			
		end

		else begin 

			RoutingComplete = 0;
		
		end
	end

endmodule 

		
			

			
	
	
	
	
	

	

	

