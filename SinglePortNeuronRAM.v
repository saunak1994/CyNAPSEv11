/*
-----------------------------------------------------
| Created on: 12.10.2018		            							
| Author: Saunak Saha				    
|                                                   
| Department of Electrical and Computer Engineering 
| Iowa State University                            
-----------------------------------------------------
*/



`timescale 1ns/1ns
module SinglePortNeuronRAM
#(
	parameter INTEGER_WIDTH = 16,
	parameter DATA_WIDTH_FRAC = 32,
	parameter DATA_WIDTH = INTEGER_WIDTH + DATA_WIDTH_FRAC,
	parameter TREF_WIDTH = 5,
	parameter NEURON_WIDTH_LOGICAL = 11,
	parameter WORD_WIDTH = (DATA_WIDTH*6)+(TREF_WIDTH+3)+(NEURON_WIDTH_LOGICAL)+2,				//Format: |NID|Valid|Ntype|Vmem|Gex|Gin|RefVal|ExWeight|InWeight|Vth|
	parameter ADDR_WIDTH = 9
)
(
	input Clock,
	input Reset,
	input ChipEnable,
	input WriteEnable,
	
	input [(WORD_WIDTH-1):0] InputData,
	input [(ADDR_WIDTH-1):0] InputAddress,

	output [(WORD_WIDTH-1):0] OutputData
);



	reg [(WORD_WIDTH - 1):0] OnChipRam [(2**ADDR_WIDTH - 1):0];
	reg [(ADDR_WIDTH - 1):0] RamAddress;
	integer i;

	/*
	initial begin 
	
		$display("Loading Neuron RAM");
		
		for(i = 0; i < 2**ADDR_WIDTH; i = i + 1)
			OnChipRam[i] = {WORD_WIDTH{1'b0}};
		$display("Finished Loading");
		

	end
	*/

	assign OutputData = OnChipRam[RamAddress]; 

	always @ (posedge Clock) begin
		if (Reset) begin 
			
			
			for (i=0;i<2**ADDR_WIDTH;i=i+1) begin 
				OnChipRam[i] <= {WORD_WIDTH{1'b0}};
			end
			
			RamAddress <= 0;	
		end	
		
		else if(ChipEnable) begin 		
			if(WriteEnable) begin 
				OnChipRam[InputAddress] <= InputData;
			end
			
			RamAddress <= InputAddress;
			
		end
		
		else begin 
			RamAddress <= RamAddress;
		end
				 
	end
	
endmodule
