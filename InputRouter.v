/*
-----------------------------------------------------
| Created on: 12.15.2018		            							
| Author: Saunak Saha				    
|                                                   
| Department of Electrical and Computer Engineering 
| Iowa State University                             
-----------------------------------------------------
*/



`timescale 1ns/1ns
module InputRouter
#(
	parameter INTEGER_WIDTH = 32,
	parameter DATA_WIDTH_FRAC = 32,
	parameter DATA_WIDTH = INTEGER_WIDTH + DATA_WIDTH_FRAC, 
	parameter NEURON_WIDTH_LOGICAL = 14, 
	parameter NEURON_WIDTH = NEURON_WIDTH_LOGICAL,
	parameter NEURON_WIDTH_INPUT = 11,
	parameter ROW_WIDTH = NEURON_WIDTH_INPUT + NEURON_WIDTH_LOGICAL,
	parameter COLUMN_WIDTH = NEURON_WIDTH_LOGICAL,  
	parameter ADDR_WIDTH = ROW_WIDTH + COLUMN_WIDTH,                
	parameter INPUT_NEURON_START = 0,
	parameter LOGICAL_NEURON_START = 2**NEURON_WIDTH_INPUT										
)																				


(
	//Control Inputs
	input Clock,
	input Reset,
	input RouteEnable,
	input wire Initialize,

	//Network Information: Neuron Ranges
	input wire [(NEURON_WIDTH-1):0] ExRangeLOWER,                   //Neuron Type Ranges
	input wire [(NEURON_WIDTH-1):0] ExRangeUPPER,			
	input wire [(NEURON_WIDTH-1):0] InRangeLOWER,					
	input wire [(NEURON_WIDTH-1):0] InRangeUPPER,			
	input wire [(NEURON_WIDTH-1):0] IPRangeLOWER,			
	input wire [(NEURON_WIDTH-1):0] IPRangeUPPER,			
	input wire [(NEURON_WIDTH-1):0] NeuStart,                       //Minimum Logical NeuronID in current network 
	input wire [(NEURON_WIDTH-1):0] NeuEnd,                         //Maximum Logical NeuronID in current Network
	
	//Queue Inputs
	input wire [(NEURON_WIDTH-1):0] NeuronID,                       //ID of spiked neuron 
	
	//Inputs from Synaptic RAM
	input wire signed [(DATA_WIDTH-1):0] WeightData,                //OutputData from WRAM

	//Outputs to Synaptic RAM
	output reg WChipEnable,                                         //Read Weight Data	
	output [(ADDR_WIDTH-1):0] WRAMAddress,                          //Address for Weights	

	//Inputs from Dendritic RAM
	input wire signed [(DATA_WIDTH-1):0] ExWeightSum,               //OutputData from ExWeightSum 	
	input wire signed [(DATA_WIDTH-1):0] InWeightSum,               //OutputData from InWeightSum 
	
	//Outputs to Dendritic RAM (via Neuron Unit)
	output reg EXChipEnable,                                        //Read ExWeightSum Data
	output reg INChipEnable,                                        //Read InWeightSum Data
	output reg EXWriteEnable,                                       //Write ExWeightSum Data
	output reg INWriteEnable,                                       //Write InWeightSum Data
	output wire [(NEURON_WIDTH-1):0] EXAddress,                     //Address of affected neuron if spiked neuron is Ex
	output wire [(NEURON_WIDTH-1):0] INAddress,                     //Address of affected neuron if spiked neuron is In
	output wire signed [(DATA_WIDTH-1):0] NewExWeightSum,           //Modified Weight-sum 			
	output wire signed [(DATA_WIDTH-1):0] NewInWeightSum,           //Modified Weight-sum 

	//Control Outputs
	output reg RoutingComplete                                      //Back to System control for next wave of route/update

		
);

	
	reg [(NEURON_WIDTH-1):0] Current_Affected, NID;
	
	
	wire Spiked_ExOrIn; 
	reg DoneRead, DoneWrite, Next;
	wire signed [(DATA_WIDTH-1):0] CurrentWeight, CurrentEx, CurrentIn;


	//Address Generation 
	assign WRAMAddress[(ADDR_WIDTH-1):(ADDR_WIDTH-ROW_WIDTH)] = (NID >= IPRangeLOWER && NID <= IPRangeUPPER) ? NID + INPUT_NEURON_START : NID - NeuStart + LOGICAL_NEURON_START;					
	assign WRAMAddress[(COLUMN_WIDTH-1):0] = Current_Affected;
	assign EXAddress = Current_Affected;
	assign INAddress = Current_Affected;
	
	
	
	//Routing Choice
	assign Spiked_ExOrIn = RouteEnable && ((NID >= ExRangeLOWER && NID <= ExRangeUPPER) || (NID >= IPRangeLOWER && NID <= IPRangeUPPER)) ? 1'b0 : 1'b1 ;      //Signal is 0 -> Ex , 1 -> In

	//New Read Data
	assign CurrentWeight = WeightData;
	assign CurrentEx = ExWeightSum;
	assign CurrentIn = InWeightSum;
		
	//New Modified Data
	assign NewExWeightSum = (~Spiked_ExOrIn)? CurrentEx + CurrentWeight : 0;
	assign NewInWeightSum = (Spiked_ExOrIn)? CurrentIn + CurrentWeight : 0;
	
	

	
	always @ (posedge Clock) begin 
	
		if(Reset) begin 
	
			//Outputs Reset
			WChipEnable <= 1'b0;
			EXChipEnable <= 1'b0;
			INChipEnable <= 1'b0;
			EXWriteEnable <= 0;
			INWriteEnable <= 0;
			RoutingComplete <= 0;	
	
			//Intermediates Reset
			Current_Affected <= 0;
			DoneRead <= 0;
			DoneWrite <= 0;
			Next <= 0;
	
		end

		else if(Initialize && ~RouteEnable) begin 


			//Outputs Initialize
			WChipEnable <= 1'b0;
			EXChipEnable <= 1'b0;
			INChipEnable <= 1'b0;
			EXWriteEnable <= 0;
			INWriteEnable <= 0;
			RoutingComplete <= 0;


			//Intermediates Initialize
			Current_Affected <= 0;
			DoneRead <= 0;	
			DoneWrite <= 0;
			Next <= 0;
			
		end
		
		else if(RouteEnable) begin

			WChipEnable <= 1'b1;
			EXChipEnable <= ~Spiked_ExOrIn;
			INChipEnable <= Spiked_ExOrIn;

			DoneRead <= WChipEnable && ~DoneWrite && ~Next;
			EXWriteEnable <= DoneRead && ~Spiked_ExOrIn && ~DoneWrite;
			INWriteEnable <= DoneRead && Spiked_ExOrIn && ~DoneWrite;
			DoneWrite <= DoneRead && ~Next;
			Next <= DoneRead;
			if (DoneWrite) begin 
				
				Current_Affected <= (Current_Affected < NeuEnd - NeuStart) ? Current_Affected + 1 : 0;
				RoutingComplete <= (Current_Affected < NeuEnd - NeuStart) ? 1'b0 : 1'b1;
			end
			else begin 
		
				Current_Affected <= Current_Affected;
			end
			 
		end
	
		else begin 
			
			//Outputs Reset
			WChipEnable <= 1'b0;
			EXChipEnable <= 1'b0;
			INChipEnable <= 1'b0;
			EXWriteEnable <= 0;
			INWriteEnable <= 0;
			RoutingComplete <= 0;


			//Intermediates Reset
			Current_Affected <= 0;
			DoneRead <= 0;	
			DoneWrite <= 0;
			Next <= 0;
		
		end
		

	end	
	
	//Hold Neuron Input Value for entire routing period
	always @ (posedge RouteEnable) begin 
		
		NID <= NeuronID;
	end


endmodule
		
		
				


	
	
