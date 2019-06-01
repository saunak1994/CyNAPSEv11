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
module Top_tb();

	//Global Timer resolution and limits
	localparam DELTAT_WIDTH = 4;																			//Resolution upto 0.1 ms can be supported 
	localparam BT_WIDTH_INT = 32;																			//2^32 supports 4,000M BT Units (ms) so for 500 ms exposure per example it can support 8M examples
	localparam BT_WIDTH_FRAC = DELTAT_WIDTH;																//BT Follows resolution 
	localparam BT_WIDTH = BT_WIDTH_INT + BT_WIDTH_FRAC;	

	//Data precision 
	localparam INTEGER_WIDTH = 32;																			//All Integer localparams should lie between +/- 2048
	localparam DATA_WIDTH_FRAC = 32;																		//Selected fractional precision for all status data
	localparam DATA_WIDTH = INTEGER_WIDTH + DATA_WIDTH_FRAC;
	localparam TREF_WIDTH = 5;																				//Refractory periods should lie between +/- 16 (integer)
	localparam EXTEND_WIDTH = (TREF_WIDTH+3)*2;																//For Refractory Value Arithmetic

	//Neuron counts and restrictions
	localparam NEURON_WIDTH_LOGICAL = 14;																	//For 2^14 = 16384 supported logical neurons
	localparam NEURON_WIDTH = NEURON_WIDTH_LOGICAL;
	localparam NEURON_WIDTH_INPUT = 11;																		//For 2^11 = 2048 supported input neurons
	localparam NEURON_WIDTH_PHYSICAL = 6;																	//For 2^6 = 64 physical neurons on-chip
	localparam TDMPOWER = NEURON_WIDTH_LOGICAL - NEURON_WIDTH_PHYSICAL;										//The degree of Time division multiplexing of logical to physical neurons
	localparam INPUT_NEURON_START = 0;																		//Input neurons in Weight table starts from index: 0 
	localparam LOGICAL_NEURON_START = 2**NEURON_WIDTH_INPUT;												//Logical neurons in Weight Table starts from index: 2048

	//On-chip Neuron status SRAMs
	localparam SPNR_WORD_WIDTH = ((DATA_WIDTH*6)+(TREF_WIDTH+3)+ NEURON_WIDTH_LOGICAL + 1 + 1);				//Format : |NID|Valid|Ntype|Vmem|Gex|Gin|RefVal|ExWeight|InWeight|Vth| 
	localparam SPNR_ADDR_WIDTH = TDMPOWER;																	//This many entries in each On-chip SRAM 
	
	//Off-Chip Weight RAM
	localparam WRAM_WORD_WIDTH = DATA_WIDTH;																//Weight bit-width is same as all status data bit-width
	localparam WRAM_ROW_WIDTH = 15;
	localparam WRAM_NUM_ROWS = 2**NEURON_WIDTH_LOGICAL + 2**NEURON_WIDTH_INPUT;
	localparam WRAM_COLUMN_WIDTH = NEURON_WIDTH_LOGICAL;  
	localparam WRAM_NUM_COLUMNS = 2**NEURON_WIDTH_LOGICAL;
	localparam WRAM_ADDR_WIDTH = WRAM_ROW_WIDTH + WRAM_COLUMN_WIDTH;										//ADDR_WIDTH = 2* NEURON_WIDTH + 1 (2*X^2 Synapses for X logical neurons and X input neurons) ?? Not Exactly but works in the present Configuration
	
	//Off-Chip Theta RAM
	localparam TRAM_WORD_WIDTH = DATA_WIDTH;																//Vth bit-width = status bit-wdth
	localparam TRAM_ADDR_WIDTH = NEURON_WIDTH_LOGICAL;														//Adaptive thresholds supported for all logical neurons
	localparam TRAM_NUM_ROWS = 2**NEURON_WIDTH_LOGICAL;
	localparam TRAM_NUM_COLUMNS = 1;
	
	
	//Queues
	localparam FIFO_WIDTH = 10;																				//1024 FIFO Queue Entries 

	//Memory initialization binaries
	localparam WEIGHTFILE = "./binaries/Weights_SCWN_bin.mem";												//Binaries for Weights 
	localparam THETAFILE = "./binaries/Theta_SCWN_bin.mem";	
	
	//Real datatype conversion
	localparam sfDATA = 2.0 **- 32.0;
	localparam sfBT = 2.0 **- 4.0;


	//Control Inputs
	reg  Clock;
	reg  Reset;
	reg  Initialize;
	reg  ExternalEnqueue;
	reg  ExternalDequeue;
	reg  Run;

	//AER Inputs
	reg  [(BT_WIDTH-1):0] ExternalBTIn;
	reg  [(NEURON_WIDTH-1):0] ExternalNIDIn;

	//Global Inputs
	reg  [(DELTAT_WIDTH-1):0] DeltaT = 4'b1000;																//DeltaT = 0.5ms  


	//Network Information 
	reg  [(NEURON_WIDTH-1):0] ExRangeLOWER = 784;							
	reg  [(NEURON_WIDTH-1):0] ExRangeUPPER = (784 + 400 -1);							
	reg  [(NEURON_WIDTH-1):0] InRangeLOWER = (784 + 400);							 	
	reg  [(NEURON_WIDTH-1):0] InRangeUPPER = (784 + 400 + 400 -1);							
	reg  [(NEURON_WIDTH-1):0] IPRangeLOWER = 0;							
	reg  [(NEURON_WIDTH-1):0] IPRangeUPPER = 783;							
	reg  [(NEURON_WIDTH-1):0] OutRangeLOWER = 784;							
	reg  [(NEURON_WIDTH-1):0] OutRangeUPPER = (784 + 400 - 1);							
	reg  [(NEURON_WIDTH-1):0] NeuStart = 784;							 
	reg  [(NEURON_WIDTH-1):0] NeuEnd = 1583;								 

	
	//Status register initialization values
	reg signed [(DATA_WIDTH-1):0] Vmem_Initial_EX = {-32'd105, 32'd0};
	reg signed [(DATA_WIDTH-1):0] gex_Initial_EX = {64'd0};
	reg signed [(DATA_WIDTH-1):0] gin_Initial_EX = {64'd0};
	
	reg signed [(DATA_WIDTH-1):0] Vmem_Initial_IN = {-32'd100, 32'd0};
	reg signed [(DATA_WIDTH-1):0] gex_Initial_IN = {64'd0};
	reg signed [(DATA_WIDTH-1):0] gin_Initial_IN = {64'd0};


	//Neuron-specific characteristics	
	reg signed [(INTEGER_WIDTH-1):0] RestVoltage_EX = {-32'd65}; 	
	reg signed [(INTEGER_WIDTH-1):0] Taumembrane_EX = {32'd100}; 	
	reg signed [(INTEGER_WIDTH-1):0] ExReversal_EX = {32'd0};	
	reg signed [(INTEGER_WIDTH-1):0] InReversal_EX = {-32'd100}; 	
	reg signed [(INTEGER_WIDTH-1):0] TauExCon_EX = {32'd1};	
	reg signed [(INTEGER_WIDTH-1):0] TauInCon_EX = {32'd2};	
	reg signed [(TREF_WIDTH-1):0] Refractory_EX = {5'd5};		
	reg signed [(INTEGER_WIDTH-1):0] ResetVoltage_EX = {-32'd65};	
	reg signed [(DATA_WIDTH-1):0] Threshold_EX = {-32'd52,32'd0};

	reg signed [(INTEGER_WIDTH-1):0] RestVoltage_IN = {-32'd60}; 	
	reg signed [(INTEGER_WIDTH-1):0] Taumembrane_IN = {32'd10}; 	
	reg signed [(INTEGER_WIDTH-1):0] ExReversal_IN = {32'd0};	
	reg signed [(INTEGER_WIDTH-1):0] InReversal_IN = {-32'd85}; 	
	reg signed [(INTEGER_WIDTH-1):0] TauExCon_IN = {32'd1};	
	reg signed [(INTEGER_WIDTH-1):0] TauInCon_IN = {32'd2};	
	reg signed [(TREF_WIDTH-1):0] Refractory_IN = {5'd2};		
	reg signed [(INTEGER_WIDTH-1):0] ResetVoltage_IN = {-32'd45};	
	reg signed [(DATA_WIDTH-1):0] Threshold_IN = {-32'd40, 32'd0};

	//AER Outputs
	wire [(BT_WIDTH-1):0] ExternalBTOut;
	wire [(NEURON_WIDTH-1):0] ExternalNIDOut;

	//Control Outputs 
	wire InitializationComplete;
	wire WChipEnable;
	wire ThetaChipEnable;

	//Off-Chip RAM I/O
	wire [(WRAM_ADDR_WIDTH-1):0] WRAMAddress;
	wire [(WRAM_WORD_WIDTH-1):0] WeightData;
	wire [(TRAM_ADDR_WIDTH-1):0] ThetaAddress;
	wire [(TRAM_WORD_WIDTH-1):0] ThetaData;

	//On-Chip RAM I/O 
	wire [(2**NEURON_WIDTH_PHYSICAL -1):0] SPNR_CE;
	wire [(2**NEURON_WIDTH_PHYSICAL -1):0] SPNR_WE;
	wire [(SPNR_ADDR_WIDTH)*(2**NEURON_WIDTH_PHYSICAL) - 1:0] SPNR_IA;
	wire [(SPNR_WORD_WIDTH)*(2**NEURON_WIDTH_PHYSICAL) - 1:0] SPNR_ID;
	wire [(SPNR_WORD_WIDTH)*(2**NEURON_WIDTH_PHYSICAL) - 1:0] SPNR_OD;

	
	//Input FIFO
	wire InputReset;
	wire InputQueueEnable;
	wire InputEnqueue;
	wire InputDequeue;
	wire [(BT_WIDTH-1):0] InFIFOBTIn;
	wire [(NEURON_WIDTH-1):0] InFIFONIDIn;

	wire [(BT_WIDTH-1):0] InFIFOBTOut;
	wire [(NEURON_WIDTH-1):0] InFIFONIDOut;
	wire [(BT_WIDTH-1):0] InputBT_Head;
	wire IsInputQueueEmpty;
	wire IsInputQueueFull;

	//Aux FIFO
	wire AuxReset;
	wire AuxQueueEnable;
	wire AuxEnqueue;
	wire AuxDequeue;
	wire [(BT_WIDTH-1):0] AuxFIFOBTIn;
	wire [(NEURON_WIDTH-1):0] AuxFIFONIDIn;

	wire [(BT_WIDTH-1):0] AuxFIFOBTOut;
	wire [(NEURON_WIDTH-1):0] AuxFIFONIDOut;
	wire [(BT_WIDTH-1):0] AuxBT_Head;
	wire IsAuxQueueEmpty;
	wire IsAuxQueueFull;

	//Out FIFO
	wire OutReset;
	wire OutQueueEnable;
	wire OutEnqueue;
	wire OutDequeue;
	wire [(BT_WIDTH-1):0] OutFIFOBTIn;
	wire [(NEURON_WIDTH-1):0] OutFIFONIDIn;

	wire [(BT_WIDTH-1):0] OutFIFOBTOut;
	wire [(NEURON_WIDTH-1):0] OutFIFONIDOut;
	wire [(BT_WIDTH-1):0] OutBT_Head;
	wire IsOutQueueEmpty;
	wire IsOutQueueFull;



	//I/O Files
	integer i,j;
	genvar phy;
	
	integer BTFile, NIDFile, ScanBT, ScanNID;
	integer outFile1, outFile2, outFile3, outFile4, outFile5, outFile6, outFile7;
	
	reg signed [(DATA_WIDTH-1):0] IDVmemEx;
	reg signed [(DATA_WIDTH-1):0] IDVmemIn; 
	reg signed [(DATA_WIDTH-1):0] IDGexEx; 
	reg signed [(DATA_WIDTH-1):0] IDGexIn;
	reg signed [(DATA_WIDTH-1):0] IDGinEx; 
	reg signed [(DATA_WIDTH-1):0] IDGinIn;

	//Per-physical (On-Chip) RAM Signal copies
	wire SPNRChipEnable [(2**NEURON_WIDTH_PHYSICAL -1):0]; 
	wire SPNRWriteEnable [(2**NEURON_WIDTH_PHYSICAL -1):0];
	wire [(SPNR_ADDR_WIDTH-1):0] SPNRInputAddress [(2**NEURON_WIDTH_PHYSICAL -1):0];
	wire [(SPNR_WORD_WIDTH-1):0] SPNRInputData [(2**NEURON_WIDTH_PHYSICAL -1):0]; 
	wire [(SPNR_WORD_WIDTH-1):0] SPNROutputData [(2**NEURON_WIDTH_PHYSICAL -1):0];

	for (phy=0; phy<2**NEURON_WIDTH_PHYSICAL;phy = phy+1) begin
		assign SPNRChipEnable[phy] = SPNR_CE[phy];
		assign SPNRWriteEnable[phy] = SPNR_WE[phy];
		assign SPNRInputAddress[phy] = SPNR_IA[((phy+1)*SPNR_ADDR_WIDTH)-1:SPNR_ADDR_WIDTH*phy];
		assign SPNRInputData[phy] = SPNR_ID[((phy+1)*SPNR_WORD_WIDTH)-1:SPNR_WORD_WIDTH*phy];

		assign SPNR_OD[((phy+1)*SPNR_WORD_WIDTH)-1:SPNR_WORD_WIDTH*phy] = SPNROutputData[phy];
	end





	//State Monitor
	localparam Monitor = 174;	//Change this 
	localparam MonitorIn = (Monitor+400);
	localparam ExPhysical = Monitor%(2**NEURON_WIDTH_PHYSICAL);
	localparam ExRow = Monitor>>(NEURON_WIDTH_PHYSICAL);
	localparam InPhysical = MonitorIn%(2**NEURON_WIDTH_PHYSICAL);
	localparam InRow = MonitorIn>>(NEURON_WIDTH_PHYSICAL);

	
	integer initStart, initEnd, BTStart, BTEnd, initCycles, BTCycles, numBT, AverageBTCycles;
	integer cycleTime = 10;

	
	
	initial begin 

		//$dumpfile("OneExample.vcd");
		//$dumpvars(0, Top_tb.CyNAPSE);
		//$dumpon;
		IDVmemEx = 0;
		IDVmemIn = 0;
		IDGexEx = 0;
		IDGexIn = 0;
		IDGinEx = 0;
		IDGinIn = 0;
		
		numBT = -1;
		AverageBTCycles = 0;
		
		
		
		//File Handling : Use for Bad Pointer Accesses and Open file issues  
	
		/*
		outFile1 = $fopen("OneExampleTestDump_EX.mem","w");
		outFile2 = $fopen("OneExampleTestDump_IN.mem","w");
		BTFile = $fopen("BTIn.mem","r");
		NIDFile = $fopen("NIDIn.mem","r");
		$fclose(BTFile);
		$fclose(NIDFile);
		$fclose(outFile1);
		$fclose(outFile2);

		$finish;
		*/

		//File Handling and Initialization : Use if no aforementioned Issues
		
		
		outFile1 = $fopen("OneExampleTestDump_EX_Vmem.mem","w");
		outFile2 = $fopen("OneExampleTestDump_EX_gex.mem","w");
		outFile3 = $fopen("OneExampleTestDump_EX_gin.mem","w");

		outFile4 = $fopen("OneExampleTestDump_IN_Vmem.mem","w");
		outFile5 = $fopen("OneExampleTestDump_IN_gex.mem","w");
		outFile6 = $fopen("OneExampleTestDump_IN_gin.mem","w");

		outFile7 = $fopen("OneExampleTestDump_OUTFIFO.mem","w");

		BTFile = $fopen("./binaries/BTIn.mem","r");
		NIDFile = $fopen("./binaries/NIDIn.mem","r");
		
		
		
		//Global Reset
		Clock = 0;
		Reset = 1;	
		Initialize = 0;
		ExternalEnqueue = 0;
		ExternalDequeue = 0;
		Run = 0;

		$display("At time:%t ns -> Begin Simulation", $time+15);
		initStart = $time+15;
		
		//Global Initialize 
		#13
		Reset = 0;
		Initialize = 1;
		

		#9000
		if (InitializationComplete) begin 
			Initialize = 0;
		end

		
		

		//One Example Test: Test against imported AER files that are one examples long

		
		/*
		while(!$feof(BTFile) && !$feof(NIDFile)) begin
			ScanBT = $fscanf(BTFile, "%b\n", InFIFOBTIn);
			ScanNID = $fscanf(NIDFile, "%b\n", InFIFONIDIn);
			#10;
			if(~CyNAPSE.InFIFO.IsQueueEmpty) begin
				Run = 1;
			end
		end	
		ExternalEnqueue = 0;
		*/

		#30
		if(~InFIFO.IsQueueEmpty) begin 
			$display("At time:%t ns -> Begin Run", $time);
			BTStart = $time;
			Run = 1;
		end
		
	
				

			
		
	end

	always begin 

		#5 Clock = ~Clock;
	
	end

	always @(posedge Clock) begin 
		
		if(~InFIFO.IsQueueFull && InitializationComplete) begin 
			if((!$feof(BTFile) && !$feof(NIDFile))) begin
				ScanBT = $fscanf(BTFile, "%b\n", ExternalBTIn);
				ScanNID = $fscanf(NIDFile, "%b\n", ExternalNIDIn);
				ExternalEnqueue = 1;
			end
			else begin 
				ExternalEnqueue = 0;
			end
		end
	end
	
	always @(posedge CyNAPSE.CLIFNU.UpdateComplete) begin
		if(Run) begin
			$display("At time: %t ns -> Update Done",$time);
			
			IDVmemEx = (genblk2[ExPhysical].SPNR_x.OnChipRam[ExRow][(6*DATA_WIDTH+TREF_WIDTH+3-1):(5*DATA_WIDTH+TREF_WIDTH+3)]);
			IDGexEx = (genblk2[ExPhysical].SPNR_x.OnChipRam[ExRow][(5*DATA_WIDTH+TREF_WIDTH+3-1):(4*DATA_WIDTH+TREF_WIDTH+3)]);
			IDGinEx = (genblk2[ExPhysical].SPNR_x.OnChipRam[ExRow][(4*DATA_WIDTH+TREF_WIDTH+3-1):(3*DATA_WIDTH+TREF_WIDTH+3)]);

			IDVmemIn = (genblk2[InPhysical].SPNR_x.OnChipRam[InRow][(6*DATA_WIDTH+TREF_WIDTH+3-1):(5*DATA_WIDTH+TREF_WIDTH+3)]);
			IDGexIn = (genblk2[InPhysical].SPNR_x.OnChipRam[InRow][(5*DATA_WIDTH+TREF_WIDTH+3-1):(4*DATA_WIDTH+TREF_WIDTH+3)]);
			IDGinIn = (genblk2[InPhysical].SPNR_x.OnChipRam[InRow][(4*DATA_WIDTH+TREF_WIDTH+3-1):(3*DATA_WIDTH+TREF_WIDTH+3)]);

			$fwrite(outFile1,"%f\n",$itor(IDVmemEx)*sfDATA);
			$fwrite(outFile2,"%f\n",$itor(IDGexEx)*sfDATA);
			$fwrite(outFile3,"%f\n",$itor(IDGinEx)*sfDATA);

			$fwrite(outFile4,"%f\n",$itor(IDVmemIn)*sfDATA);
			$fwrite(outFile5,"%f\n",$itor(IDGexIn)*sfDATA);
			$fwrite(outFile6,"%f\n",$itor(IDGinIn)*sfDATA);
			
			
		end
			
	end
	
	always @(posedge InitializationComplete) begin 
		$display("At time:%t ns -> Initialization Complete",$time);
		initEnd = $time;
		initCycles = (initEnd-initStart)/cycleTime;
		$display("Initialization Cycles: %d", initCycles);
	end

	
	always @(CyNAPSE.SysCtrl.Current_BT) begin 
		$display("At time:%t ns -> Current_BT = %f", $time, $itor(CyNAPSE.SysCtrl.Current_BT)*sfBT);
		if (numBT >= 0) begin
			BTEnd = $time;
			BTCycles = (BTEnd - BTStart)/cycleTime;
			
			BTStart = $time;
			AverageBTCycles = AverageBTCycles + BTCycles;
			
			$display("BT Cycles: %d",BTCycles);
		end
		numBT = numBT + 1;
		if(CyNAPSE.SysCtrl.Current_BT == 36'd32) begin									//record VCD only for 1 BTs
			//$dumpoff;
		end
		if(CyNAPSE.SysCtrl.Current_BT == 36'd1600) begin 								//Set BT Limit. For one example BT Limit = 351*16 = 5616
			Run = 0;
			$fclose(BTFile);
			$fclose(NIDFile);
			
			for (j = 0; j< 2**FIFO_WIDTH; j=j+1) begin
		
				$fwrite(outFile7,"%f %d\n",$itor(OutFIFO.FIFO_BT[j])*sfBT,OutFIFO.FIFO_NID[j]);
		
			end

			$fclose(outFile1);
			$fclose(outFile2);
			$fclose(outFile3);
			$fclose(outFile4);
			$fclose(outFile5);
			$fclose(outFile6);
			$fclose(outFile7);
			
			AverageBTCycles = AverageBTCycles/numBT;
			$display("----- RUNTIME STATISTICS: -----\n ");
			$display("Initialization cycles: %d", initCycles);
			$display("Average cycles per BT: %d", AverageBTCycles);
			$finish;
		end
	end
	
	
	Top #(DELTAT_WIDTH, BT_WIDTH_INT, BT_WIDTH_FRAC, BT_WIDTH, INTEGER_WIDTH, DATA_WIDTH_FRAC, DATA_WIDTH, TREF_WIDTH, EXTEND_WIDTH, NEURON_WIDTH_LOGICAL, NEURON_WIDTH, NEURON_WIDTH_INPUT, NEURON_WIDTH_PHYSICAL, TDMPOWER, INPUT_NEURON_START, LOGICAL_NEURON_START, SPNR_WORD_WIDTH, SPNR_ADDR_WIDTH, WRAM_WORD_WIDTH, WRAM_ROW_WIDTH, WRAM_COLUMN_WIDTH, WRAM_ADDR_WIDTH, TRAM_WORD_WIDTH, TRAM_ADDR_WIDTH, FIFO_WIDTH, WEIGHTFILE, THETAFILE) CyNAPSE
	(
		//Control Inputs
		.Clock(Clock),
		.Reset(Reset),
		.Initialize(Initialize),
		.ExternalEnqueue(ExternalEnqueue),
		.ExternalDequeue(ExternalDequeue),
		.Run(Run),

		//AER Inputs
		.ExternalBTIn(ExternalBTIn),
		.ExternalNIDIn(ExternalNIDIn),
	
		//Global Inputs 
		.DeltaT(DeltaT),
		
		//Network Information
		.ExRangeLOWER(ExRangeLOWER),			
		.ExRangeUPPER(ExRangeUPPER),			
		.InRangeLOWER(InRangeLOWER),					
		.InRangeUPPER(InRangeUPPER),			
		.IPRangeLOWER(IPRangeLOWER),			
		.IPRangeUPPER(IPRangeUPPER),
		.OutRangeLOWER(OutRangeLOWER),
		.OutRangeUPPER(OutRangeUPPER),			
		.NeuStart(NeuStart),			
		.NeuEnd(NeuEnd),

		//Status register initialization values 
		.Vmem_Initial_EX(Vmem_Initial_EX),
		.gex_Initial_EX(gex_Initial_EX),
		.gin_Initial_EX(gin_Initial_EX),
	
		.Vmem_Initial_IN(Vmem_Initial_IN),
		.gex_Initial_IN(gex_Initial_IN),
		.gin_Initial_IN(gin_Initial_IN),

		//Neuron-specific characteristics
		.RestVoltage_EX(RestVoltage_EX), 	
		.Taumembrane_EX(Taumembrane_EX), 	
		.ExReversal_EX(ExReversal_EX),	
		.InReversal_EX(InReversal_EX), 	
		.TauExCon_EX(TauExCon_EX),	
		.TauInCon_EX(TauInCon_EX),	
		.Refractory_EX(Refractory_EX),		
		.ResetVoltage_EX(ResetVoltage_EX),	
		.Threshold_EX(Threshold_EX),
	
		.RestVoltage_IN(RestVoltage_IN), 	
		.Taumembrane_IN(Taumembrane_IN), 	
		.ExReversal_IN(ExReversal_IN),	
		.InReversal_IN(InReversal_IN), 	
		.TauExCon_IN(TauExCon_IN),	
		.TauInCon_IN(TauInCon_IN),	
		.Refractory_IN(Refractory_IN),		
		.ResetVoltage_IN(ResetVoltage_IN),	
		.Threshold_IN(Threshold_IN),

		//AEROutputs
		.ExternalBTOut(OutFIFOBTOut),
		.ExternalNIDOut(OutFIFONIDOut),

		//Control Outputs
		.InitializationComplete(InitializationComplete),
		.WChipEnable(WChipEnable),
		.ThetaChipEnable(ThetaChipEnable),

		//Off-Chip RAM I/O
		.WRAMAddress(WRAMAddress),
		.WeightData(WeightData),
		.ThetaAddress(ThetaAddress),
		.ThetaData(ThetaData),

		//On-Chip RAM I/O
		.SPNR_CE(SPNR_CE),
		.SPNR_WE(SPNR_WE),
		.SPNR_IA(SPNR_IA),
		.SPNR_ID(SPNR_ID),
		.SPNR_OD(SPNR_OD),

		//FIFO Controls

		//Input FIFO
		.InputReset(InputReset),
		.InputQueueEnable(InputQueueEnable),
		.InputEnqueue(InputEnqueue),
		.InputDequeue(InputDequeue),
		.InFIFOBTIn(InFIFOBTIn),
		.InFIFONIDIn(InFIFONIDIn),

		.InFIFOBTOut(InFIFOBTOut),
		.InFIFONIDOut(InFIFONIDOut),
		.InputBT_Head(InputBT_Head),
		.IsInputQueueEmpty(IsInputQueueEmpty),
		.IsInputQueueFull(IsInputQueueFull),

		//Aux FIFO
		.AuxReset(AuxReset),
		.AuxQueueEnable(AuxQueueEnable),
		.AuxEnqueue(AuxEnqueue),
		.AuxDequeue(AuxDequeue),
		.AuxFIFOBTIn(AuxFIFOBTIn),
		.AuxFIFONIDIn(AuxFIFONIDIn),

		.AuxFIFOBTOut(AuxFIFOBTOut),
		.AuxFIFONIDOut(AuxFIFONIDOut),
		.AuxBT_Head(AuxBT_Head),
		.IsAuxQueueEmpty(IsAuxQueueEmpty),
		.IsAuxQueueFull(IsAuxQueueFull),

		//Out FIFO
		.OutReset(OutReset),
		.OutQueueEnable(OutQueueEnable),
		.OutEnqueue(OutEnqueue),
		.OutDequeue(OutDequeue),
		.OutFIFOBTIn(OutFIFOBTIn),
		.OutFIFONIDIn(OutFIFONIDIn),

		.OutFIFOBTOut(OutFIFOBTOut),
		.OutFIFONIDOut(OutFIFONIDOut),
		.OutBT_Head(OutBT_Head),
		.IsOutQueueEmpty(IsOutQueueEmpty),
		.IsOutQueueFull(IsOutQueueFull)


	);

	/***************************************************************
		WEIGHT RAM 	
	***************************************************************/
	SinglePortOffChipRAM #(WRAM_WORD_WIDTH, WRAM_ADDR_WIDTH, WRAM_NUM_ROWS, WRAM_NUM_COLUMNS, WEIGHTFILE) WeightRAM
	(
		//Controls Signals
		.Clock(Clock),	
		.Reset(InternalRouteReset),
		.ChipEnable(WChipEnable),
		.WriteEnable(1'b0),

		//Inputs from Router		
		.InputData({WRAM_WORD_WIDTH{1'b0}}),
		.InputAddress(WRAMAddress),

		//Outputs to Router 
		.OutputData(WeightData)

	);

	
	
	/***************************************************************
		THETA RAM 	
	***************************************************************/
	
	SinglePortOffChipRAM #(TRAM_WORD_WIDTH, TRAM_ADDR_WIDTH, TRAM_NUM_ROWS, TRAM_NUM_COLUMNS, THETAFILE) ThetaRAM
	(
		//Controls Signals
		.Clock(Clock),	
		.Reset(Reset),
		.ChipEnable(ThetaChipEnable),			
		.WriteEnable(1'b0),			

		//Inputs from Router		
		.InputData({TRAM_WORD_WIDTH{1'b0}}),		
		.InputAddress(ThetaAddress),	

		//Outputs to Router 
		.OutputData(ThetaData)		

	);


	/***************************************************************
		ON-CHIP RAMs	
	***************************************************************/

	generate 
		genvar x;
		for (x = 0; x< (2**NEURON_WIDTH_PHYSICAL); x = x+1) begin

			//On-Chip Neuron Status RAMs
			SinglePortNeuronRAM #(INTEGER_WIDTH, DATA_WIDTH_FRAC, DATA_WIDTH, TREF_WIDTH, NEURON_WIDTH_LOGICAL, SPNR_WORD_WIDTH, SPNR_ADDR_WIDTH) SPNR_x(
					.Clock(Clock),
	 				.Reset(Reset),
				 	.ChipEnable(SPNRChipEnable[x]),
					.WriteEnable(SPNRWriteEnable[x]),
					.InputData(SPNRInputData[x]),
				 	.InputAddress(SPNRInputAddress[x]),

 					.OutputData(SPNROutputData[x])
				);

		end
	endgenerate 

	/***************************************************************
			INPUT FIFO
	***************************************************************/
	InputFIFO #(BT_WIDTH, NEURON_WIDTH_LOGICAL, NEURON_WIDTH, FIFO_WIDTH) InFIFO
	(
		//Control Signals
		.Clock(Clock),
		.Reset(InputReset),
		.QueueEnable(InputQueueEnable),
		.Dequeue(InputDequeue),
		.Enqueue(InputEnqueue),

		//ExternalInputs
		.BTIn(InFIFOBTIn),	
		.NIDIn(InFIFONIDIn),
		
		//To Router via IRIS Selector
		.BTOut(InFIFOBTOut),
		.NIDOut(InFIFONIDOut),

		//Control Outputs
		.BT_Head(InputBT_Head),
		.IsQueueEmpty(IsInputQueueEmpty),
		.IsQueueFull(IsInputQueueFull)

	);

	/***************************************************************
			AUXILIARY FIFO
	***************************************************************/
	InputFIFO #(BT_WIDTH, NEURON_WIDTH_LOGICAL, NEURON_WIDTH, FIFO_WIDTH) AuxFIFO
	(
		//Control Signals
		.Clock(Clock),
		.Reset(AuxReset),
		.QueueEnable(AuxQueueEnable),
		.Dequeue(AuxDequeue),

		//From Internal Router
		.Enqueue(AuxEnqueue),

		//Internal ROUTER iNPUTS
		.BTIn(AuxFIFOBTIn),	
		.NIDIn(AuxFIFONIDIn),

		//To Router via IRIS Selector
		.BTOut(AuxFIFOBTOut),
		.NIDOut(AuxFIFONIDOut),

		//Control Inputs
		.BT_Head(AuxBT_Head),
		.IsQueueEmpty(IsAuxQueueEmpty),
		.IsQueueFull(IsAuxQueueFull)

	);

	/***************************************************************
			OUTPUT FIFO
	***************************************************************/
	InputFIFO #(BT_WIDTH, NEURON_WIDTH_LOGICAL, NEURON_WIDTH, FIFO_WIDTH) OutFIFO
	(
		//Control Signals
		.Clock(Clock),
		.Reset(OutReset),
		.QueueEnable(OutQueueEnable),
		.Dequeue(OutDequeue),

		//From Internal Router
		.Enqueue(OutEnqueue),

		//Internal ROUTER Inputs
		.BTIn(OutFIFOBTIn),	
		.NIDIn(OutFIFONIDIn),

		//To External 
		.BTOut(OutFIFOBTOut),
		.NIDOut(OutFIFONIDOut),

		//Control Inputs
		.BT_Head(OutBT_Head),
		.IsQueueEmpty(IsOutQueueEmpty),
		.IsQueueFull(IsOutQueueFull)

	);






endmodule
