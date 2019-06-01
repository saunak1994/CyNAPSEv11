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
module SinglePortOffChipRAM
#(
	parameter WORD_WIDTH = 32+32,
	parameter ADDR_WIDTH = 25, 	
	parameter NUM_ROWS = 0,
	parameter NUM_COLS = 0,								
	parameter FILENAME = "weights_bin.mem"
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



	reg [(WORD_WIDTH - 1):0] OnChipRam [(NUM_ROWS*NUM_COLS - 1):0];
	reg [(ADDR_WIDTH - 1):0] RamAddress;

	
	initial begin 
	
		$display("Loading Data into Off-Chip RAM");
		$readmemb(FILENAME, OnChipRam);
		$display("Finished Loading");
		

	end
	

	assign OutputData = OnChipRam[RamAddress]; 

	always @ (posedge Clock) begin
		if (Reset) begin 
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
