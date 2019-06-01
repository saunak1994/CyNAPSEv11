/*
-----------------------------------------------------
| Created on: 12.21.2018		            							
| Author: Saunak Saha				    
|                                                   
| Department of Electrical and Computer Engineering  
| Iowa State University                             
-----------------------------------------------------
*/


`timescale 1ns/1ns
module SysControl
#(
	parameter BT_WIDTH = 36, 
	parameter DELTAT_WIDTH = 4
)

(
	//External Inputs
	input wire Clock,
	input wire Reset,
	input wire Initialize,
	input wire ExternalEnqueue,                                 //For Input Queue
	input wire ExternalDequeue,                                 //For Output Queue
	input wire Run,	
	
	//Global Inputs 
	input wire [(DELTAT_WIDTH-1):0] DeltaT,

	//Input FIFO Queue
	input wire IsInputQueueFull,
	input wire IsInputQueueEmpty,
	input wire [(BT_WIDTH-1):0] InputBT_Head,
	
	output wire InputReset,	
	output reg InputQueueEnable,
	output wire InputEnqueue,
	output wire InputDequeue,

	
	//Auxiliary Queue
	input wire IsAuxQueueFull,
	input wire IsAuxQueueEmpty,
	input wire [(BT_WIDTH-1):0] AuxBT_Head,

	output wire AuxReset,
	output reg AuxQueueEnable,
	//output reg AuxEnqueue,                                    --> Recieved directly from Internal Router to Auxiliary Queue
	output wire AuxDequeue,


	//Output Queue
	input wire IsOutQueueFull,
	input wire IsOutQueueEmpty,
	input wire [(BT_WIDTH-1):0] OutBT_Head,

	output wire OutReset,
	output reg OutQueueEnable,
	//output reg OutEnqueue,                                    --> Recieved directly from Internal Router to Output Queue
	output wire OutDequeue,
	
	//IRIS Switch
	output wire InputRouteInputSelect,                          //LOW - InputQueue ; HIGH - InternalQueue
	
	//Input Router 
	input wire InputRoutingComplete,
	
	output wire InputRouteReset,
	output wire InputRouteInitialize, 
	output wire InputRouteEnable,

	
	//Internal Router 
	input wire InternalRoutingComplete,

	output wire InternalRouteReset,
	output wire [(BT_WIDTH-1):0] InternalCurrent_BT,
	output wire InternalRouteEnable,
	

	//NeuronUnit
	
	input wire MappingComplete,
	input wire UpdateComplete,
	
	output wire NeuronUnitReset,
	output wire NeuronUnitInitialize,
	output wire MapNeurons,
	output wire UpdateEnable,        				
	//and also InputRouteEnable


	//Top level Output
	output wire InitializationComplete
);


	reg [(BT_WIDTH-1):0] Current_BT; 
	wire [(BT_WIDTH-1):0] DeltaT_Extended; 

	//Intermediates
	reg InDQ, AuxDQ, OutDQ, InREn, IntREn, UEn1, UEn2, UEn3, UEn, IRIS ; 
	
	//Resets
	assign InputReset = Reset;
	assign AuxReset = Reset;
	assign OutReset = Reset;
	assign InputRouteReset = Reset;
	assign InternalRouteReset = Reset;	
	assign NeuronUnitReset = Reset;
	
	//Initializes
	assign InputRouteInitialize = Initialize; 
	assign NeuronUnitInitialize = Initialize;
	assign MapNeurons = Initialize && ~MappingComplete;
	
	//Wire Select
	assign DeltaT_Extended = {{BT_WIDTH-DELTAT_WIDTH{1'b0}},DeltaT};              //pad integer bits 

	//Outputs
	assign InputEnqueue = ExternalEnqueue;
	assign InputDequeue = InDQ && ~InREn;
	assign AuxDequeue = AuxDQ && ~InREn;
	assign OutDequeue = OutDQ;
	assign InputRouteEnable = InREn && ~InputRoutingComplete;
	assign InternalRouteEnable = IntREn && ~InternalRoutingComplete;

	assign UpdateEnable = UEn;

	assign InputRouteInputSelect = IRIS;
	assign InternalCurrent_BT = Current_BT;
	
	assign InitializationComplete = MappingComplete;
			

	always @ (posedge Clock) begin 
		
		if (Reset) begin 

			//Enables low
			InputQueueEnable <= 0;
			AuxQueueEnable <= 0;
			OutQueueEnable <= 0;
			InDQ <= 0;
			AuxDQ <= 0;
			OutDQ <= 0;
			IRIS <= 0;
			InREn <= 0;
			IntREn <= 0;
			UEn <= 0;
			UEn1 <= 0;
			UEn2 <= 0;
			UEn3 <= 0;
			
			//Biologitcal Time intialized to zero						
			Current_BT <= {BT_WIDTH{1'b0}};
	
		end

		else if (Initialize) begin 
	
			//Enables low
			InputQueueEnable <= 1;
			AuxQueueEnable <= 1;
			OutQueueEnable <= 1;
			InDQ <= 0;
			AuxDQ <= 0;
			OutDQ <= 0;
			IRIS <= 0;
			InREn <= 0;
			IntREn <= 0;
			UEn <= 0;	
			UEn1 <= 0;
			UEn2 <= 0;
			UEn3 <= 0;
			
			//Biologitcal Time intialized to zero						
			Current_BT <= {BT_WIDTH{1'b0}};
		end
	
		else if (Run) begin
	
			//All queues enabled always during a run 
			InputQueueEnable <= 1;
			AuxQueueEnable <= 1;
			OutQueueEnable <= 1;
			
			//Enqueues are decided either by Syscontrol or by leaf modules
			//AuxEnqueue --> By Internal Router
			//OutEnqueue --> By Internal Router 
			
			//Dequeues happen when respective queues are selected by IRIS, not empty, head BT matches current BT and none of the other processes (Route or Update) are enabled OR externally asserted
			InDQ <= (InputBT_Head == Current_BT && ~InputRouteInputSelect && ~IsInputQueueEmpty && ~InREn && ~UEn && ~IntREn) ? 1'b1 : 1'b0;
			AuxDQ <= (AuxBT_Head == Current_BT && InputRouteInputSelect && ~IsAuxQueueEmpty && ~InREn && ~UEn && ~IntREn) ? 1'b1 : 1'b0;
			OutDQ <= ExternalDequeue && ~IsOutQueueEmpty;

			//When Input Queue head matches Current_BT, IRIS selects Input otherwise selects Auxiliary			
			IRIS <=  (InputBT_Head != Current_BT || ~IsAuxQueueEmpty) ? 1'b1 : 1'b0;

			if (InputDequeue || AuxDequeue) begin 
		
				InREn <= 1'b1;
			end
			else;
			
			if (InputRoutingComplete) begin 
		
				InREn <= 1'b0;
			end
			else;

			if ((InputBT_Head != Current_BT) && (IsAuxQueueEmpty) && ~InREn && ~IntREn) begin

				//System Controller provides finite HIATUS between Event Router and Neuron Unit Update Activity through Dummy Register buffers
				UEn1 <= 1'b1;
				UEn2 <= UEn1;
				UEn3 <= UEn2;
				UEn <= UEn3; 
				
			end
			else;			

			if (UpdateComplete) begin 
		
				UEn <= 1'b0;
				IntREn <= 1'b1;	
			end
			else;
				
			if(InternalRoutingComplete) begin 
		
				IntREn <= 1'b0;
				Current_BT <= Current_BT + DeltaT_Extended;

			end
			else;
				
		end

	end




endmodule
				

				
				
				
			
				 
			
				
				
		




	
