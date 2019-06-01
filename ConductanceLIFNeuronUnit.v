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
module ConductanceLIFNeuronUnit
#( 
	parameter INTEGER_WIDTH = 32,
	parameter DATA_WIDTH_FRAC = 32,
	parameter DATA_WIDTH = INTEGER_WIDTH + DATA_WIDTH_FRAC, 
	parameter DELTAT_WIDTH = 4, 
	parameter TREF_WIDTH = 5, 
	parameter EXTEND_WIDTH = 16
)

(
	//Control Signals
	input wire Clock,
	input wire Reset,
	input wire UpdateEnable,
	input wire Initialize,

	//Neuron-specific characteristics
	input wire signed NeuronType,                                            //0 -> Excitatory : 1 -> Inhibitory

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
	
	input wire signed [(DATA_WIDTH-1):0] Threshold,

	//Status Inputs
	input wire signed [(DATA_WIDTH-1):0] Vmem,
	input wire signed [(DATA_WIDTH-1):0] gex,
	input wire signed [(DATA_WIDTH-1):0] gin,
	input wire [(TREF_WIDTH+3-1):0] RefVal,
	
	//Global Inputs
	input wire [(DELTAT_WIDTH-1):0] DeltaT,

	//Synaptic Inputs
	input wire signed [(DATA_WIDTH-1):0] ExWeightSum,
	input wire signed [(DATA_WIDTH-1):0] InWeightSum,
	
	//Status Outputs
	output reg SpikeBuffer,				
	output reg signed [(DATA_WIDTH-1):0] VmemOut,	
	output reg signed [(DATA_WIDTH-1):0] gexOut,
	output reg signed [(DATA_WIDTH-1):0] ginOut,
	output reg [(TREF_WIDTH+3-1):0] RefValOut		
	

);

	//Status Registers
	

	//Intermediate Signals
	wire LeakPSCEnable; 
	wire SpikeOut_Threshold;
	wire signed [(DATA_WIDTH-1):0] Vmem_Added, Vmem_Leaked, EPSCOut, IPSCOut, Vmem_Thresholded, gex_Leaked, gin_Leaked, gex_Integrated, gin_Integrated;
	wire signed [EXTEND_WIDTH-1:0] DeltaT_Extended, tRef_Extended, tRef_Actual;				
	wire signed [(EXTEND_WIDTH*3/2)-1:0] Dividend, Quotient;



	//Neuron parameter registers		
	wire signed [(INTEGER_WIDTH-1):0] Vrest; 	
	wire signed [(INTEGER_WIDTH-1):0] Taumem; 	
	wire signed [(INTEGER_WIDTH-1):0] Eex;		
	wire signed [(INTEGER_WIDTH-1):0] Ein; 	
	wire signed [(INTEGER_WIDTH-1):0] Taugex;		
	wire signed [(INTEGER_WIDTH-1):0] Taugin;		
	wire signed [(TREF_WIDTH-1):0] tRef;		
	wire signed [(INTEGER_WIDTH-1):0] Vreset;	

	wire signed [(DATA_WIDTH-1):0] Vth;	

	assign Vrest = (NeuronType == 0) ? RestVoltage_EX : RestVoltage_IN;
	assign Taumem = (NeuronType == 0) ? Taumembrane_EX : Taumembrane_IN;
	assign Eex = (NeuronType == 0) ? ExReversal_EX : ExReversal_IN;
	assign Ein = (NeuronType == 0)? InReversal_EX : InReversal_IN;
	assign Taugex = (NeuronType == 0) ? TauExCon_EX : TauExCon_IN;
	assign Taugin = (NeuronType == 0) ? TauInCon_EX : TauInCon_IN;
	assign tRef = (NeuronType == 0) ? Refractory_EX : Refractory_IN;
	assign Vreset = (NeuronType == 0) ? ResetVoltage_EX : ResetVoltage_IN;
	assign Vth = (NeuronType == 0) ? Threshold_EX : Threshold_IN; 

							


	//Wire Select and/or padding for Fixed-point Arithmetic for Refractory period Calculation
	assign DeltaT_Extended = {{EXTEND_WIDTH/2{1'b0}},DeltaT,{(EXTEND_WIDTH/2)-DELTAT_WIDTH{1'b0}}};      //pad some int bits and some frac bits (****NOTE: DeltaT MUST BE POSITIVE VALUE****) 
	assign tRef_Extended = {{(EXTEND_WIDTH/2)-TREF_WIDTH{1'b0}},tRef,{EXTEND_WIDTH/2{1'b0}}};            //pad some int bits and some frac bits (****NOTE: tREF MUST BE POSITIVE VALUE****)
	assign Dividend = {tRef_Extended,{EXTEND_WIDTH/2{1'b0}}};                                            //Shifting frac bit places before Division 
	assign Quotient = Dividend/DeltaT_Extended;
	assign tRef_Actual = Quotient[(EXTEND_WIDTH-1):0];                                                   //Take lower order 16 bits of Quotient`


	//Neuron Sequential Logic
 
	always @(posedge Clock) begin
		if (Reset) begin

			//Outputs Reset
			VmemOut <= 0;
			gexOut <= 0;
			ginOut <= 0;
			RefValOut <= 0;
			SpikeBuffer <= 0;
		
	

		end	 	
		 
		
		
		else if (UpdateEnable) begin 
	
			VmemOut <= (RefVal <= 0) ? Vmem_Thresholded : Vmem;
			gexOut <= gex_Integrated;
			ginOut <= gin_Integrated;
			SpikeBuffer <= SpikeOut_Threshold;

			if (RefVal > 0) begin
				RefValOut <= (SpikeOut_Threshold == 1) ? tRef_Actual[(EXTEND_WIDTH-1):(EXTEND_WIDTH/2)] - 1 : RefVal - 1;
			end
			else if (RefVal == 0) begin
				RefValOut <= (SpikeOut_Threshold == 1) ? tRef_Actual[(EXTEND_WIDTH-1):(EXTEND_WIDTH/2)] - 1 : RefVal;
			end

			else;
		end

		else;	
	 
			
	end
	

	

	//Signal to decide whether to leak and integrate PSCs or in refractory state 
	assign LeakPSCEnable = (UpdateEnable && (RefVal <= 0)) ? 1'b1 : 1'b0;
	

	//Membrane Leak produced leaked Membrane Voltage 
	VmemLeakUnit #(INTEGER_WIDTH, DATA_WIDTH_FRAC, DATA_WIDTH, DELTAT_WIDTH) VLU

	(

		
		.Vrest(Vrest),
		.Vmem(Vmem),
		.DeltaT(DeltaT),
		.Taumem(Taumem),
	

		.VmemOut(Vmem_Leaked)
	);

	//Excitatory Post-Synaptic Current 
	EPSCUnit #(INTEGER_WIDTH, DATA_WIDTH_FRAC, DATA_WIDTH, DELTAT_WIDTH) EPSCU

	(

		.Eex(Eex),
		.Vmem(Vmem),
		.gex(gex),
		.DeltaT(DeltaT),
		.Taumem(Taumem),
	

		.EPSCOut(EPSCOut)
	);

	//Inhibitory Post-Synaptic Current 
	IPSCUnit #(INTEGER_WIDTH, DATA_WIDTH_FRAC, DATA_WIDTH, DELTAT_WIDTH) IPSCU
	
	(
		
		.Ein(Ein),
		.Vmem(Vmem),
		.gin(gin),
		.DeltaT(DeltaT),
		.Taumem(Taumem),
	

		.IPSCOut(IPSCOut)
	);

	assign Vmem_Added = (LeakPSCEnable) ? Vmem_Leaked + EPSCOut + IPSCOut : Vmem; 

	//Thresholding of Integrated Membrane Voltage
	ThresholdUnit #(INTEGER_WIDTH, DATA_WIDTH_FRAC, DATA_WIDTH) THU

	(

		
		.Vth(Threshold),
		.Vmem(Vmem_Added),
		.Vreset(Vreset),

		.VmemOut(Vmem_Thresholded),
		.SpikeOut(SpikeOut_Threshold)
	);


	//Conductance leak units controlled by Neuron UpdateEnable signal
	GexLeakUnit #(INTEGER_WIDTH, DATA_WIDTH_FRAC, DATA_WIDTH, DELTAT_WIDTH) GexLU

	(

		.gex(gex),
		.DeltaT(DeltaT),
		.Taugex(Taugex),

		.gexOut(gex_Leaked)
	);

	GinLeakUnit #(INTEGER_WIDTH, DATA_WIDTH_FRAC, DATA_WIDTH, DELTAT_WIDTH) GinLU

	(

		.gin(gin),
		.DeltaT(DeltaT),
		.Taugin(Taugin),

		.ginOut(gin_Leaked)
	);

	//Synaptic Integration of collected Weights
	SynapticIntegrationUnit #(INTEGER_WIDTH, DATA_WIDTH_FRAC, DATA_WIDTH) SIU

	(

		
		.gex(gex_Leaked),
		.gin(gin_Leaked),

		.ExWeightSum(ExWeightSum),
		.InWeightSum(InWeightSum),

		.gexOut(gex_Integrated),
		.ginOut(gin_Integrated)
	);



	


endmodule


