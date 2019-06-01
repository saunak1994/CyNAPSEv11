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
module InputFIFO
#(
	parameter BT_WIDTH = 36,  
	parameter NEURON_WIDTH_LOGICAL = 11,
	parameter NEURON_WIDTH = NEURON_WIDTH_LOGICAL,
	parameter FIFO_WIDTH = NEURON_WIDTH_LOGICAL
) 
//BT_WIDTH = 32INT, 4 FRACTIONAL for upto 0.1ms resolution and total network time of upto 4000M, by default FIFO_WIDTH = NEURON_WIDTH_LOGICAL but it can be changed to inspect effect (Works fine for smaller FIFO)

(
	//Control Inputs
	input wire Clock,
	input wire Reset,
	input wire QueueEnable,
	input wire Dequeue,
	input wire Enqueue,


	//Inputs from Router/External
	input wire [(BT_WIDTH-1):0] BTIn,
	input wire [(NEURON_WIDTH-1):0] NIDIn,

	  
	
	//Outputs to Router 
	output reg [(BT_WIDTH-1):0] BTOut,
	output reg [(NEURON_WIDTH-1):0] NIDOut,
	


	//Control Outputs
	output wire [(BT_WIDTH-1):0] BT_Head,
	output reg IsQueueEmpty,
	output reg IsQueueFull
);


	reg [(FIFO_WIDTH-1):0] Count;
	reg [(FIFO_WIDTH-1):0] readCounter, writeCounter; 

	reg [(BT_WIDTH-1):0] FIFO_BT [(2**FIFO_WIDTH-1):0];
	reg [(NEURON_WIDTH-1):0] FIFO_NID [(2**FIFO_WIDTH-1):0];

	reg AlmostFull, AlmostEmpty, InitialEmpty;
	integer i;
	
	assign BT_Head = FIFO_BT[readCounter]; 	
		
	always @ (posedge Clock) begin 
		
		if (Reset) begin 
			
			Count = 0;
			readCounter = 0;
			writeCounter = 0;
			AlmostFull = 0;
			AlmostEmpty = 0;
			IsQueueEmpty = 0;
			IsQueueFull = 0;
			InitialEmpty = 1;
				
			for (i=0; i< 2**FIFO_WIDTH; i=i+1) begin 
				FIFO_BT[i] = 0;
				FIFO_NID[i] = 0;
			end
		end

		else if (QueueEnable) begin 

			AlmostFull = (Count == (2**FIFO_WIDTH - 1)) ? 1'b1 : 1'b0;
			AlmostEmpty = (Count == 1) ? 1'b1 : 1'b0;

			if (Dequeue == 1'b1 && ~IsQueueEmpty) begin 
				
				
				
				
				BTOut = FIFO_BT[readCounter];
				NIDOut = FIFO_NID[readCounter];
				FIFO_BT[readCounter] = 0;
				FIFO_NID[readCounter] = 0;
				readCounter = readCounter + 1;
				
				if(AlmostEmpty) IsQueueEmpty = 1'b1;
				else;
				if(IsQueueFull) IsQueueFull = 1'b0;
				else;
			end

			else if (Enqueue == 1'b1 && ~IsQueueFull) begin 

				
				if(AlmostFull) IsQueueFull = 1'b1;
				else;
				if (IsQueueEmpty) IsQueueEmpty = 1'b0;
				else;
				
				FIFO_BT[writeCounter] = BTIn;
				FIFO_NID[writeCounter] = NIDIn;

				writeCounter = writeCounter + 1;
			end

			else;
			
		end

		
		//Circular Buffer: Head of Buffer is wherever readCounter points to! 
		if (writeCounter == 2**FIFO_WIDTH) writeCounter = 0;
		else if (readCounter == 2**FIFO_WIDTH) readCounter = 0;
		else;

		if(readCounter > writeCounter) Count = (2**FIFO_WIDTH) - (readCounter - writeCounter);
		else if (writeCounter > readCounter) Count = writeCounter - readCounter;
		else; 
		
		if (Count > 0) InitialEmpty = 0;
		else;
		if (InitialEmpty) IsQueueEmpty = 1'b1;
		else;
		
	end



endmodule


	
