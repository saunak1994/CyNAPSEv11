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
module NeuronUnit
#( 
	parameter INTEGER_WIDTH = 32, 
	parameter DATA_WIDTH_FRAC = 32,
	parameter DATA_WIDTH = INTEGER_WIDTH + DATA_WIDTH_FRAC,
	parameter DELTAT_WIDTH = 4, 
	parameter TREF_WIDTH = 5, 
	parameter NEURON_WIDTH_LOGICAL = 14,
	parameter NEURON_WIDTH_PHYSICAL = 6,
	parameter NEURON_WIDTH = NEURON_WIDTH_LOGICAL,
	parameter TDMPOWER = NEURON_WIDTH_LOGICAL - NEURON_WIDTH_PHYSICAL,
	parameter SPNR_WORD_WIDTH = ((DATA_WIDTH*6)+(TREF_WIDTH+3)+ NEURON_WIDTH_LOGICAL + 1 + 1),        //Format : |NID|Valid|Ntype|Vmem|Gex|Gin|RefVal|ExWeight|InWeight|Vth| 
	parameter SPNR_ADDR_WIDTH = TDMPOWER,
	parameter EXTEND_WIDTH = (TREF_WIDTH+3)*2
)
(

	//Control Signals
	input wire Clock,
	input wire Reset,
	input wire UpdateEnable,
	input wire RouteEnable,
	input wire Initialize,
	input wire MapNeurons,


	//Status register initialization values
	input wire signed [(DATA_WIDTH-1):0] Vmem_Initial_EX,
	input wire signed [(DATA_WIDTH-1):0] gex_Initial_EX,
	input wire signed [(DATA_WIDTH-1):0] gin_Initial_EX,
	
	input wire signed [(DATA_WIDTH-1):0] Vmem_Initial_IN,
	input wire signed [(DATA_WIDTH-1):0] gex_Initial_IN,
	input wire signed [(DATA_WIDTH-1):0] gin_Initial_IN,
	

	//Neuron-specific characteristics	
	input wire signed [(INTEGER_WIDTH-1):0] RestVoltage_EX, 	
	input wire signed [(INTEGER_WIDTH-1):0] Taumembrane_EX, 	
	input wire signed [(INTEGER_WIDTH-1):0] ExReversal_EX,	
	input wire signed [(INTEGER_WIDTH-1):0] InReversal_EX, 	
	input wire signed [(INTEGER_WIDTH-1):0] TauExCon_EX,	
	input wire signed [(INTEGER_WIDTH-1):0] TauInCon_EX,	
	input wire signed [(TREF_WIDTH-1):0] Refractory_EX,		
	input wire signed [(INTEGER_WIDTH-1):0] ResetVoltage_EX,	
	input wire signed [(DATA_WIDTH-1):0] Threshold_EX,
	
	input wire signed [(INTEGER_WIDTH-1):0] RestVoltage_IN, 	
	input wire signed [(INTEGER_WIDTH-1):0] Taumembrane_IN, 	
	input wire signed [(INTEGER_WIDTH-1):0] ExReversal_IN,	
	input wire signed [(INTEGER_WIDTH-1):0] InReversal_IN, 	
	input wire signed [(INTEGER_WIDTH-1):0] TauExCon_IN,	
	input wire signed [(INTEGER_WIDTH-1):0] TauInCon_IN,	
	input wire signed [(TREF_WIDTH-1):0] Refractory_IN,		
	input wire signed [(INTEGER_WIDTH-1):0] ResetVoltage_IN,	
	input wire signed [(DATA_WIDTH-1):0] Threshold_IN,

	
	//Network Information
	input wire [(NEURON_WIDTH-1):0] ExRangeLOWER,			
	input wire [(NEURON_WIDTH-1):0] ExRangeUPPER,			
	input wire [(NEURON_WIDTH-1):0] InRangeLOWER,					
	input wire [(NEURON_WIDTH-1):0] InRangeUPPER,			
	input wire [(NEURON_WIDTH-1):0] IPRangeLOWER,			
	input wire [(NEURON_WIDTH-1):0] IPRangeUPPER,			
	input wire [(NEURON_WIDTH-1):0] NeuStart,			
	input wire [(NEURON_WIDTH-1):0] NeuEnd,

	
	//Global Inputs
	input wire [(DELTAT_WIDTH-1):0] DeltaT,


	//Inputs from Router 
	input wire FromRouterEXChipEnable,
	input wire FromRouterINChipEnable,
	input wire FromRouterEXWriteEnable,
	input wire FromRouterINWriteEnable,
	input wire [(NEURON_WIDTH - 1):0] FromRouterEXAddress,
	input wire [(NEURON_WIDTH - 1):0] FromRouterINAddress,
	input wire signed [(DATA_WIDTH-1):0] FromRouterNewExWeightSum,					
	input wire signed [(DATA_WIDTH-1):0] FromRouterNewInWeightSum,	

	//Inputs from Theta RAM
	input wire signed [(DATA_WIDTH-1):0] ThetaData,
	
	//Outputs to Router 
	output wire signed [(DATA_WIDTH-1):0] ToRouterExWeightSum,
	output wire signed [(DATA_WIDTH-1):0] ToRouterInWeightSum,
	
	//Outputs to Theta RAM
	output wire ThetaChipEnable,
	output wire [(NEURON_WIDTH-1):0] ThetaAddress,

	//Outputs to Internal Router
	output reg [(2**NEURON_WIDTH -1):0] SpikeBufferOut,

	//Control Outputs
	output reg MappingComplete,
	output wire UpdateComplete,



	//Outputs to SPNR
	output wire [(2**NEURON_WIDTH_PHYSICAL -1):0] SPNR_CE,
	output wire [(2**NEURON_WIDTH_PHYSICAL -1):0] SPNR_WE,
	output wire [(SPNR_ADDR_WIDTH)*(2**NEURON_WIDTH_PHYSICAL) - 1:0] SPNR_IA,
	output wire [(SPNR_WORD_WIDTH)*(2**NEURON_WIDTH_PHYSICAL) - 1:0] SPNR_ID,

	//Inputs from SPNR
	input wire [(SPNR_WORD_WIDTH)*(2**NEURON_WIDTH_PHYSICAL) - 1:0] SPNR_OD
	
);

	integer j;
	genvar i,k,phy;
	

	
	

	//Per-physical (On-Chip) RAM Signal copies
	reg SPNRChipEnable [(2**NEURON_WIDTH_PHYSICAL -1):0]; 
	reg SPNRWriteEnable [(2**NEURON_WIDTH_PHYSICAL -1):0];
	reg [(SPNR_ADDR_WIDTH-1):0] SPNRInputAddress [(2**NEURON_WIDTH_PHYSICAL -1):0];
	reg [(SPNR_WORD_WIDTH-1):0] SPNRInputData [(2**NEURON_WIDTH_PHYSICAL -1):0]; 
	wire [(SPNR_WORD_WIDTH-1):0] SPNROutputData [(2**NEURON_WIDTH_PHYSICAL -1):0];


	//Routed outside the test area because SRAM not intra-DUT
	for (phy=0; phy<2**NEURON_WIDTH_PHYSICAL;phy = phy+1) begin
		assign SPNR_CE[phy] = SPNRChipEnable[phy];
		assign SPNR_WE[phy] = SPNRWriteEnable[phy];
		assign SPNR_IA[((phy+1)*SPNR_ADDR_WIDTH)-1:SPNR_ADDR_WIDTH*phy] = SPNRInputAddress[phy];
		assign SPNR_ID[((phy+1)*SPNR_WORD_WIDTH)-1:SPNR_WORD_WIDTH*phy] = SPNRInputData[phy];

		assign SPNROutputData[phy] = SPNR_OD[((phy+1)*SPNR_WORD_WIDTH)-1:SPNR_WORD_WIDTH*phy];
	end

	 
	
	//Initialization Intermediates
	reg [(NEURON_WIDTH_LOGICAL-1):0] IDNID;
	reg IDValid;
	reg IDNtype;
	reg signed [(DATA_WIDTH-1):0] IDVmem;
	reg signed [(DATA_WIDTH-1):0] IDGex;
	reg signed [(DATA_WIDTH-1):0] IDGin;	
	reg [(TREF_WIDTH+3-1):0] IDRefVal;
	reg signed [(DATA_WIDTH-1):0] IDExWeight;
	reg signed [(DATA_WIDTH-1):0] IDInWeight;
	reg signed [(DATA_WIDTH-1):0] IDVth;
	
	reg [(NEURON_WIDTH_LOGICAL-1):0] CurrentLogical;
	reg [(NEURON_WIDTH_PHYSICAL-1):0] CurrentPhysical; 
	reg [(NEURON_WIDTH_LOGICAL-1):0] CurrentVTLogical; 

	//Initialization Controls
	reg MappingAlmostComplete, MappingReallyComplete;
	

	//Update Intermediates 

	wire [(NEURON_WIDTH_LOGICAL-1):0] CurrentNID [(2**NEURON_WIDTH_PHYSICAL -1):0];
	wire CurrentValid [(2**NEURON_WIDTH_PHYSICAL -1):0];
	wire CurrentNtype [(2**NEURON_WIDTH_PHYSICAL -1):0];
	wire signed [(DATA_WIDTH-1):0] Threshold [(2**NEURON_WIDTH_PHYSICAL -1):0];

	//Input registers for Physical Neurons 
	wire signed [(DATA_WIDTH-1):0] Vmem [(2**NEURON_WIDTH_PHYSICAL -1):0];
	wire signed [(DATA_WIDTH-1):0] gex [(2**NEURON_WIDTH_PHYSICAL -1):0];
	wire signed [(DATA_WIDTH-1):0] gin [(2**NEURON_WIDTH_PHYSICAL -1):0];
	wire [(TREF_WIDTH+3-1):0] RefVal [(2**NEURON_WIDTH_PHYSICAL -1):0];
	wire signed [(DATA_WIDTH-1):0] ExWeightSum [(2**NEURON_WIDTH_PHYSICAL -1):0]; 
	wire signed [(DATA_WIDTH-1):0] InWeightSum [(2**NEURON_WIDTH_PHYSICAL -1):0];

	//Output Registers for Physical Neurons
	wire signed [(DATA_WIDTH-1):0] VmemOut [(2**NEURON_WIDTH_PHYSICAL -1):0];
	wire signed [(DATA_WIDTH-1):0] gexOut [(2**NEURON_WIDTH_PHYSICAL -1):0];
	wire signed [(DATA_WIDTH-1):0] ginOut [(2**NEURON_WIDTH_PHYSICAL -1):0];
	wire [(TREF_WIDTH+3-1):0] RefValOut [(2**NEURON_WIDTH_PHYSICAL -1):0];
	wire SpikeBuffer [(2**NEURON_WIDTH_PHYSICAL -1):0];
	

	//Update Controls
	reg IUE1, IUE2, IUE3; 
	reg DoneRead, DoneWrite, Next;
	wire PhysicalUpdateEnable;
	wire IndividualUpdateEnable [(2**NEURON_WIDTH_PHYSICAL -1):0];
	reg IndividualComplete [(2**NEURON_WIDTH_PHYSICAL -1):0];
	wire [(2**NEURON_WIDTH_PHYSICAL -1):0] AllComplete;

	

	//Update Intermediates and Controls combinational logic (following aforementioned Format for SPNR WORD)
	for (i=0; i<2**NEURON_WIDTH_PHYSICAL;i = i+1) begin
		assign CurrentNID[i] = SPNROutputData[i][(6*DATA_WIDTH+TREF_WIDTH+3+2+NEURON_WIDTH_LOGICAL-1):(6*DATA_WIDTH+TREF_WIDTH+3+2)];
		assign CurrentValid[i] = SPNROutputData[i][(6*DATA_WIDTH+TREF_WIDTH+3+1)];
		assign CurrentNtype[i] = SPNROutputData[i][6*DATA_WIDTH+TREF_WIDTH+3]; 

		assign Vmem[i] = SPNROutputData[i][(6*DATA_WIDTH+TREF_WIDTH+3-1):(5*DATA_WIDTH+TREF_WIDTH+3)];	
		assign gex[i] = SPNROutputData[i][(5*DATA_WIDTH+TREF_WIDTH+3-1):(4*DATA_WIDTH+TREF_WIDTH+3)];
		assign gin[i] = SPNROutputData[i][(4*DATA_WIDTH+TREF_WIDTH+3-1):(3*DATA_WIDTH+TREF_WIDTH+3)];			
		assign RefVal[i] = SPNROutputData[i][(3*DATA_WIDTH+TREF_WIDTH+3-1):3*DATA_WIDTH];

		assign ExWeightSum[i] = SPNROutputData[i][(3*DATA_WIDTH -1):2*DATA_WIDTH];
		assign InWeightSum[i] = SPNROutputData[i][(2*DATA_WIDTH -1):DATA_WIDTH];

		assign Threshold[i] = SPNROutputData[i][(DATA_WIDTH-1):0];

		assign IndividualUpdateEnable[i] = IUE3 && ~DoneRead && ~DoneWrite && ~Next && CurrentValid[i];
	end

	//Update completion control
	for (k=0;k<2**NEURON_WIDTH_PHYSICAL;k=k+1) begin 
		assign AllComplete[k] = IndividualComplete[k];
	end

	//Update control
	assign PhysicalUpdateEnable = IUE3 && ~DoneRead && ~DoneWrite && ~Next;
	assign UpdateComplete = (AllComplete == 2**(2**NEURON_WIDTH_PHYSICAL) - 1) ? 1'b1 : 1'b0;
	
	//Global Theta (Off-Chip) RAM Control Signals
	assign ThetaChipEnable = 1;
	assign ThetaAddress = CurrentVTLogical+1;

	//Routing Control
	reg NRE1, NRE2;
	reg signed [(SPNR_WORD_WIDTH-1):0] CurrentStatus;
	wire [(NEURON_WIDTH_PHYSICAL -1):0] ExWeightAddressPhysical;
	wire [(NEURON_WIDTH_PHYSICAL -1):0] InWeightAddressPhysical;
	wire [(SPNR_ADDR_WIDTH-1):0] ExWeightAddressRow;
	wire [(SPNR_ADDR_WIDTH-1):0] InWeightAddressRow;

	//Routing Control combinational logic
	assign ExWeightAddressPhysical = FromRouterEXAddress%(2**NEURON_WIDTH_PHYSICAL);
	assign ExWeightAddressRow = FromRouterEXAddress>>(NEURON_WIDTH_PHYSICAL);
	assign InWeightAddressPhysical = FromRouterINAddress%(2**NEURON_WIDTH_PHYSICAL);
	assign InWeightAddressRow = FromRouterINAddress>>(NEURON_WIDTH_PHYSICAL);
	assign ToRouterExWeightSum = CurrentStatus[(3*DATA_WIDTH-1):(2*DATA_WIDTH)];
	assign ToRouterInWeightSum = CurrentStatus[(2*DATA_WIDTH-1):(DATA_WIDTH)];


	


	
	always @ (posedge Clock) begin 
	
		if (Reset) begin 
			
			for (j=0; j<2**NEURON_WIDTH_PHYSICAL; j=j+1) begin 

				//RAM Controls Reset
				SPNRChipEnable[j] <= 0;
				SPNRWriteEnable[j] <= 0;
				SPNRInputAddress[j] <= 0;
				SPNRInputData[j] <= {SPNR_WORD_WIDTH{1'b0}};

				//Per physical Update Control Registers Reset
				IndividualComplete[j] <= 0;
			end

			//Initialization Intermediates Reset
			IDNID <= 0;
			IDValid <= 0;
			IDNtype <= 0;
			IDVmem <= 0;
			IDGex <= 0;
			IDGin <= 0;
			IDRefVal <= 0;
			IDExWeight <= 0;
			IDInWeight <= 0;
			IDVth <= 0;	
			CurrentLogical <= 0;
			CurrentPhysical <= 0;
			CurrentVTLogical <= 0;	
			
			//Initialization Controls Reset
			MappingAlmostComplete <= 0;
			MappingReallyComplete <= 0;
			MappingComplete <= 0;

			//Update Controls Reset
			IUE1 <= 0;
			IUE2 <= 0;
			IUE3 <= 0;
			DoneRead <= 0;
			DoneWrite <= 0;
			Next <= 0;
			

			//Routing Controls Reset
			NRE1 <= 0;
			NRE2 <= 0;
			CurrentStatus <= 0;
			
		end


		

		else if (Initialize && ~UpdateEnable && ~RouteEnable) begin
	
						
			if (MapNeurons) begin 
		
				
				CurrentPhysical <= CurrentLogical%(2**NEURON_WIDTH_PHYSICAL);
				SPNRChipEnable[CurrentPhysical] <= 1;
				SPNRWriteEnable[CurrentPhysical] <= 1;
				SPNRInputAddress[CurrentPhysical] <= (CurrentLogical == 0) ? 0 : CurrentLogical-1>>(NEURON_WIDTH_PHYSICAL);		

				IDNID <= (CurrentLogical+NeuStart <= NeuEnd) ? CurrentLogical+NeuStart : 0;
				IDValid <= (CurrentLogical+NeuStart <= NeuEnd)? 1 : 0;
				IDNtype <= ((CurrentLogical+NeuStart >= ExRangeLOWER) && (CurrentLogical+NeuStart <= ExRangeUPPER)) ? 0 : 1;
				IDVmem <= ((CurrentLogical+NeuStart >= ExRangeLOWER) && (CurrentLogical+NeuStart <= ExRangeUPPER)) ? Vmem_Initial_EX : Vmem_Initial_IN;
				IDGex <= ((CurrentLogical+NeuStart >= ExRangeLOWER) && (CurrentLogical+NeuStart <= ExRangeUPPER)) ? gex_Initial_EX : gex_Initial_IN;
				IDGin <= ((CurrentLogical+NeuStart >= ExRangeLOWER) && (CurrentLogical+NeuStart <= ExRangeUPPER)) ? gin_Initial_EX : gin_Initial_IN;
				IDRefVal <= 0;
				IDExWeight <= 0;
				IDInWeight <= 0;
				IDVth <= ThetaData;
			

				SPNRInputData[CurrentPhysical] <= {IDNID, IDValid, IDNtype, IDVmem, IDGex, IDGin, IDRefVal, IDExWeight, IDInWeight, IDVth};
				CurrentLogical <= (CurrentLogical + NeuStart < NeuEnd) ? CurrentLogical + 1 : CurrentLogical; 
				CurrentVTLogical <= (CurrentVTLogical + NeuStart < NeuEnd) ? CurrentVTLogical + 1 : CurrentVTLogical;
				MappingAlmostComplete <= (CurrentLogical + NeuStart >= NeuEnd) ? 1 : MappingAlmostComplete;
				MappingReallyComplete <= MappingAlmostComplete;
				MappingComplete <= MappingReallyComplete;
				
			
			end
			
		end

		else if (UpdateEnable && ~RouteEnable) begin 

				IUE1 <= UpdateEnable;
				IUE2 <= IUE1; 
				IUE3 <= IUE2 && ~DoneRead && ~DoneWrite && ~Next; 
				DoneRead <= PhysicalUpdateEnable && ~DoneWrite;
				DoneWrite <= DoneRead && ~Next;
				Next <= DoneWrite;

				for (j=0; j<2**NEURON_WIDTH_PHYSICAL;j = j+1) begin 
		
					SPNRChipEnable[j] <= 1;
					SPNRWriteEnable[j] <= (CurrentValid[j] == 1 && DoneRead) ? 1 : 0;

					//Values Don't Change
					SPNRInputData[j][(6*DATA_WIDTH+TREF_WIDTH+3+2+NEURON_WIDTH_LOGICAL-1):(6*DATA_WIDTH+TREF_WIDTH+3+2)] <= (CurrentValid[j] == 1) ? CurrentNID[j] : SPNRInputData[j][(6*DATA_WIDTH+TREF_WIDTH+3+2+NEURON_WIDTH_LOGICAL-1):(6*DATA_WIDTH+TREF_WIDTH+3+2)];
					SPNRInputData[j][(6*DATA_WIDTH+TREF_WIDTH+3+1)] <= (CurrentValid[j] == 1) ? CurrentValid[j] : SPNRInputData[j][(6*DATA_WIDTH+TREF_WIDTH+3+1)];
					SPNRInputData[j][6*DATA_WIDTH+TREF_WIDTH+3] <= (CurrentValid[j] == 1) ? CurrentNtype[j] : SPNRInputData[j][6*DATA_WIDTH+TREF_WIDTH+3];

					//Values Change 
					SPNRInputData[j][(6*DATA_WIDTH+TREF_WIDTH+3-1):(5*DATA_WIDTH+TREF_WIDTH+3)] <= (CurrentValid[j] == 1) ? VmemOut[j] : SPNRInputData[j][(6*DATA_WIDTH+TREF_WIDTH+3-1):(5*DATA_WIDTH+TREF_WIDTH+3)];
					SPNRInputData[j][(5*DATA_WIDTH+TREF_WIDTH+3-1):(4*DATA_WIDTH+TREF_WIDTH+3)] <= (CurrentValid[j] == 1) ? gexOut[j] : SPNRInputData[j][(5*DATA_WIDTH+TREF_WIDTH+3-1):(4*DATA_WIDTH+TREF_WIDTH+3)];
					SPNRInputData[j][(4*DATA_WIDTH+TREF_WIDTH+3-1):(3*DATA_WIDTH+TREF_WIDTH+3)] <= (CurrentValid[j] == 1) ? ginOut[j] : SPNRInputData[j][(4*DATA_WIDTH+TREF_WIDTH+3-1):(3*DATA_WIDTH+TREF_WIDTH+3)];
					SPNRInputData[j][(3*DATA_WIDTH+TREF_WIDTH+3-1):3*DATA_WIDTH] <= (CurrentValid[j] == 1) ? RefValOut[j] : SPNRInputData[j][(3*DATA_WIDTH+TREF_WIDTH+3-1):3*DATA_WIDTH];

					//Values Flushed after Update
					SPNRInputData[j][(3*DATA_WIDTH -1):2*DATA_WIDTH] <= (CurrentValid[j] == 1) ? {DATA_WIDTH{1'b0}} : SPNRInputData[j][(3*DATA_WIDTH -1):2*DATA_WIDTH];
					SPNRInputData[j][(2*DATA_WIDTH -1):DATA_WIDTH] <= (CurrentValid[j] == 1) ? {DATA_WIDTH{1'b0}} : SPNRInputData[j][(2*DATA_WIDTH -1):DATA_WIDTH];

					//Values Don't Change 
					SPNRInputData[j][(DATA_WIDTH-1):0] <= (CurrentValid[j] == 1) ? Threshold[j] : SPNRInputData[j][(DATA_WIDTH-1):0];
					
					

					if (Next) begin 
						SPNRInputAddress[j] <= (CurrentValid[j] == 1) ? SPNRInputAddress[j] + 1 : SPNRInputAddress[j];

					end
					IndividualComplete[j] <= (CurrentValid[j] == 0) ? 1 : IndividualComplete[j];
					
				end
			
				for (j = 0; j<2**NEURON_WIDTH_PHYSICAL; j=j+1) begin 
		
					SpikeBufferOut[CurrentNID[j]-NeuStart] <= SpikeBuffer[j];

				end
				

		end	 

		
		else if (RouteEnable && ~UpdateEnable) begin 

			NRE1 <= RouteEnable;
			NRE2 <= NRE1;

			for (j = 0; j<2**NEURON_WIDTH_PHYSICAL; j=j+1) begin 
					SPNRChipEnable[j] <= (j == ExWeightAddressPhysical) ? 1'b1 : 1'b0;
			end
			for (j = 0; j<2**NEURON_WIDTH_PHYSICAL; j=j+1) begin 
					SPNRChipEnable[j] <= (j == InWeightAddressPhysical) ? 1'b1 : 1'b0;
			end 
			
			if(FromRouterEXChipEnable) begin 
				
				SPNRInputAddress[ExWeightAddressPhysical] <= ExWeightAddressRow;
				CurrentStatus <= SPNROutputData[ExWeightAddressPhysical];
				DoneRead <= NRE2 && ~DoneWrite;
				if(FromRouterEXWriteEnable) begin 
					for (j = 0; j<2**NEURON_WIDTH_PHYSICAL; j=j+1) begin 
						SPNRWriteEnable[j] <= (j == ExWeightAddressPhysical) ? 1'b1 : 1'b0;
					end
					SPNRInputData[ExWeightAddressPhysical] <= {CurrentStatus[(6*DATA_WIDTH+TREF_WIDTH+3+2+NEURON_WIDTH_LOGICAL-1):3*DATA_WIDTH],FromRouterNewExWeightSum,CurrentStatus[(2*DATA_WIDTH -1):0]};
					
					DoneWrite <= DoneRead;
				end
			end
			else if(FromRouterINChipEnable) begin
				
				SPNRInputAddress[InWeightAddressPhysical] <= InWeightAddressRow;
				CurrentStatus <= SPNROutputData[InWeightAddressPhysical];
				DoneRead <= NRE2 && ~DoneWrite;
				if(FromRouterINWriteEnable) begin
					for (j = 0; j<2**NEURON_WIDTH_PHYSICAL; j=j+1) begin 
						SPNRWriteEnable[j] <= (j == InWeightAddressPhysical) ? 1'b1 : 1'b0;
					end 
					SPNRInputData[InWeightAddressPhysical] <= {CurrentStatus[(6*DATA_WIDTH+TREF_WIDTH+3+2+NEURON_WIDTH_LOGICAL-1):2*DATA_WIDTH],FromRouterNewInWeightSum,CurrentStatus[(DATA_WIDTH -1):0]};
					
					DoneWrite <= DoneRead;
				end
			end
		end
		
		else begin 

			for (j=0; j<2**NEURON_WIDTH_PHYSICAL;j = j+1) begin 
					SPNRInputAddress[j] <= 0;
					SPNRInputData[j] <= 0;
					SPNRWriteEnable[j] <= 0;
					IndividualComplete[j] <= 0;
			end
			IUE1 <= 0;
			IUE2 <= 0;
			IUE3 <= 0;
			NRE1 <= 0;
			NRE2 <= 0;
			DoneRead <= 0;
			DoneWrite <= 0;
			Next <= 0;
			
	

		end


	end





	generate 
		genvar x;
		for (x = 0; x< (2**NEURON_WIDTH_PHYSICAL); x = x+1) begin 

			//Conductance LIF Neurons
			ConductanceLIFNeuronUnit #(INTEGER_WIDTH, DATA_WIDTH_FRAC, DATA_WIDTH, DELTAT_WIDTH, TREF_WIDTH, EXTEND_WIDTH) CLIF_x
				(
					.Clock(Clock),
					.Reset(Reset),
					.UpdateEnable(IndividualUpdateEnable[x]),
					.Initialize(Initialize),

					.NeuronType(CurrentNtype[x]),

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

					.Threshold(Threshold[x]),

					.Vmem(Vmem[x]),
					.gex(gex[x]),
					.gin(gin[x]),
					.RefVal(RefVal[x]),

					.DeltaT(DeltaT),

					.ExWeightSum(ExWeightSum[x]),
					.InWeightSum(InWeightSum[x]),
	
					.SpikeBuffer(SpikeBuffer[x]),
					.VmemOut(VmemOut[x]),
					.gexOut(gexOut[x]),
					.ginOut(ginOut[x]),
					.RefValOut(RefValOut[x])
				);
	
			//On-Chip Neuron Status RAMs -> Now Pulled Out of DUT Area
			/*
			SinglePortNeuronRAM #(INTEGER_WIDTH, DATA_WIDTH_FRAC, DATA_WIDTH, TREF_WIDTH, NEURON_WIDTH_LOGICAL, SPNR_WORD_WIDTH, SPNR_ADDR_WIDTH) SPNR_x(
					.Clock(Clock),
	 				.Reset(Reset),
				 	.ChipEnable(SPNRChipEnable[x]),
					.WriteEnable(SPNRWriteEnable[x]),
					.InputData(SPNRInputData[x]),
				 	.InputAddress(SPNRInputAddress[x]),

 					.OutputData(SPNROutputData[x])
				);
			*/

			
		
		end
	endgenerate

endmodule
