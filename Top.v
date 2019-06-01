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
module Top
#(
	//Global Timer resolution and limits
	parameter DELTAT_WIDTH = 4,                                                      //Resolution upto 0.1 ms can be supported 
	parameter BT_WIDTH_INT = 32,                                                     //2^32 supports 4,000M BT Units (ms) so for 500 ms exposure per example it can support 8M examples
	parameter BT_WIDTH_FRAC = DELTAT_WIDTH,                                          //BT Follows resolution 
	parameter BT_WIDTH = BT_WIDTH_INT + BT_WIDTH_FRAC,	

	//Data precision 
	parameter INTEGER_WIDTH = 32,                                                    //All Integer parameters should lie between +/- 2048
	parameter DATA_WIDTH_FRAC = 32,                                                  //Selected fractional precision for all status data
	parameter DATA_WIDTH = INTEGER_WIDTH + DATA_WIDTH_FRAC,
	parameter TREF_WIDTH = 5,                                                        //Refractory periods should lie between +/- 16 (integer)
	parameter EXTEND_WIDTH = (TREF_WIDTH+3)*2,                                       //For Refractory Value Arithmetic

	//Neuron counts and restrictions
	parameter NEURON_WIDTH_LOGICAL = 14,                                             //N For 2^N supported logical neurons
	parameter NEURON_WIDTH = NEURON_WIDTH_LOGICAL,
	parameter NEURON_WIDTH_INPUT = 11,                             		         //N For 2^N supported input neurons
	parameter NEURON_WIDTH_PHYSICAL = 2,                                             //N For 2^N physical neurons on-chip
	parameter TDMPOWER = NEURON_WIDTH_LOGICAL - NEURON_WIDTH_PHYSICAL,               //The degree of Time division multiplexing of logical to physical neurons
	parameter INPUT_NEURON_START = 0,                                                //Input neurons in Weight table starts from index: 0 
	parameter LOGICAL_NEURON_START = 2**NEURON_WIDTH_INPUT,                          //Logical neurons in Weight Table starts from index: 2048

	//On-chip Neuron status SRAMs
	parameter SPNR_WORD_WIDTH = ((DATA_WIDTH*6)+(TREF_WIDTH+3)+ NEURON_WIDTH_LOGICAL + 1 + 1),         //Format : |NID|Valid|Ntype|Vmem|Gex|Gin|RefVal|ExWeight|InWeight|Vth| 
	parameter SPNR_ADDR_WIDTH = TDMPOWER,                                                              //This many entries in each On-chip SRAM 
	
	//Off-Chip Weight RAM
	parameter WRAM_WORD_WIDTH = DATA_WIDTH,                                                            //Weight bit-width is same as all status data bit-width
	parameter WRAM_ROW_WIDTH = 15,
	parameter WRAM_NUM_ROWS = 2**NEURON_WIDTH_LOGICAL + 2**NEURON_WIDTH_INPUT,
	parameter WRAM_COLUMN_WIDTH = NEURON_WIDTH_LOGICAL,  
	parameter WRAM_NUM_COLUMNS = 2**NEURON_WIDTH_LOGICAL,	
	parameter WRAM_ADDR_WIDTH = WRAM_ROW_WIDTH + WRAM_COLUMN_WIDTH,                                    //ADDR_WIDTH = 2* NEURON_WIDTH + 1 (2*X^2 Synapses for X logical neurons and X input neurons) ?? Not Exactly but works in the present Configuration
	
	//Off-Chip Theta RAM
	parameter TRAM_WORD_WIDTH = DATA_WIDTH,                                           //Vth bit-width = status bit-wdth
	parameter TRAM_ADDR_WIDTH = NEURON_WIDTH_LOGICAL,                                 //Adaptive thresholds supported for all logical neurons
	parameter TRAM_NUM_ROWS = 2**NEURON_WIDTH_LOGICAL,
	parameter TRAM_NUM_COLUMNS = 1,

	//Queues
	parameter FIFO_WIDTH = 10,                                                         //64 FIFO Queue Entries 

	//Memory initialization binaries
	parameter WEIGHTFILE = "Weights_SCWN.mem",                                         //Binaries for Weights 
	parameter THETAFILE = "Theta_SCWN.mem"                                             //Binaries for adaptive thresholds

)
(	
	//Control Inputs
	input wire Clock,
	input wire Reset,
	input wire Initialize,                                                            //Starts Warm-up
	input wire ExternalEnqueue,                                                       //Assert to insert AER packet into input FIFO Queue
	input wire ExternalDequeue,                                                       //Assert to take out AER packet from output FIFO Queue
	input wire Run,                                                                   //Starts Network and operates for as long as asserted 

	//AER Inputs
	input wire [(BT_WIDTH-1):0] ExternalBTIn,						  				  //Input AER Packet
	input wire [(NEURON_WIDTH-1):0] ExternalNIDIn,                                    //"

	//Global Inputs
	input wire [(DELTAT_WIDTH-1):0] DeltaT,                                           //Neuron Update or Global Biological Time Resolution 


	//Network Information 
	input wire [(NEURON_WIDTH-1):0] ExRangeLOWER,					  //Excitatory Neuron Range
	input wire [(NEURON_WIDTH-1):0] ExRangeUPPER,                                     //"
	input wire [(NEURON_WIDTH-1):0] InRangeLOWER,                                     //Inhibitory Neuron Range		
	input wire [(NEURON_WIDTH-1):0] InRangeUPPER,                                     //"
	input wire [(NEURON_WIDTH-1):0] IPRangeLOWER,                                     //Input Neuron Range
	input wire [(NEURON_WIDTH-1):0] IPRangeUPPER,                                     //"
	input wire [(NEURON_WIDTH-1):0] OutRangeLOWER,                                    //Output Neuron Range
	input wire [(NEURON_WIDTH-1):0] OutRangeUPPER,                                    //"
	input wire [(NEURON_WIDTH-1):0] NeuStart,                                         //Minimum Actual NeuronID in current network 
	input wire [(NEURON_WIDTH-1):0] NeuEnd,                                           //Maximum Actual NeuronID in current Network

	
	//Status register initialization values
	input wire signed [(DATA_WIDTH-1):0] Vmem_Initial_EX,                             //Initial membrane voltage and conductances of Neurons for Pyramidal Cells			
	input wire signed [(DATA_WIDTH-1):0] gex_Initial_EX,                              //"
	input wire signed [(DATA_WIDTH-1):0] gin_Initial_EX,                              //"
	
	input wire signed [(DATA_WIDTH-1):0] Vmem_Initial_IN,                             //for Basket cells
	input wire signed [(DATA_WIDTH-1):0] gex_Initial_IN,                              //"	
	input wire signed [(DATA_WIDTH-1):0] gin_Initial_IN,                              //"


	//Neuron-specific characteristics	
	input wire signed [(INTEGER_WIDTH-1):0] RestVoltage_EX,                           //Neuron Specific Characteristics for Pyramidal Cells
	input wire signed [(INTEGER_WIDTH-1):0] Taumembrane_EX,                           
	input wire signed [(INTEGER_WIDTH-1):0] ExReversal_EX,                            
	input wire signed [(INTEGER_WIDTH-1):0] InReversal_EX,                            
	input wire signed [(INTEGER_WIDTH-1):0] TauExCon_EX,                              	
	input wire signed [(INTEGER_WIDTH-1):0] TauInCon_EX,                              
	input wire signed [(TREF_WIDTH-1):0] Refractory_EX,                               
	input wire signed [(INTEGER_WIDTH-1):0] ResetVoltage_EX,                          
	input wire signed [(DATA_WIDTH-1):0] Threshold_EX,                                
	
	input wire signed [(INTEGER_WIDTH-1):0] RestVoltage_IN,                           //for Basket Cells
	input wire signed [(INTEGER_WIDTH-1):0] Taumembrane_IN, 				
	input wire signed [(INTEGER_WIDTH-1):0] ExReversal_IN,						
	input wire signed [(INTEGER_WIDTH-1):0] InReversal_IN, 						
	input wire signed [(INTEGER_WIDTH-1):0] TauExCon_IN,						
	input wire signed [(INTEGER_WIDTH-1):0] TauInCon_IN,						
	input wire signed [(TREF_WIDTH-1):0] Refractory_IN,							
	input wire signed [(INTEGER_WIDTH-1):0] ResetVoltage_IN,					
	input wire signed [(DATA_WIDTH-1):0] Threshold_IN,							

	//AER Outputs
	output wire [(BT_WIDTH-1):0] ExternalBTOut,                                        //Output AER Packet
	output wire [(NEURON_WIDTH-1):0] ExternalNIDOut,								

	//Control Outputs
	output wire InitializationComplete,                                               //Cue for completion of warm-up and start Running
	output wire WChipEnable,
	output wire ThetaChipEnable,
	

	//Off-Chip RAM I/O
	output wire [(WRAM_ADDR_WIDTH-1):0] WRAMAddress,
	input wire [(WRAM_WORD_WIDTH-1):0] WeightData,
	output wire [(TRAM_ADDR_WIDTH-1):0] ThetaAddress,
	input wire [(TRAM_WORD_WIDTH-1):0] ThetaData,

	//On-Chip RAM I/O 
	output wire [(2**NEURON_WIDTH_PHYSICAL -1):0] SPNR_CE,
	output wire [(2**NEURON_WIDTH_PHYSICAL -1):0] SPNR_WE,
	output wire [(SPNR_ADDR_WIDTH)*(2**NEURON_WIDTH_PHYSICAL) - 1:0] SPNR_IA,
	output wire [(SPNR_WORD_WIDTH)*(2**NEURON_WIDTH_PHYSICAL) - 1:0] SPNR_ID,
	input wire [(SPNR_WORD_WIDTH)*(2**NEURON_WIDTH_PHYSICAL) - 1:0] SPNR_OD,

	//FIFO Controls

	//Input FIFO
	output wire InputReset,
	output wire InputQueueEnable,
	output wire InputEnqueue,
	output wire InputDequeue,
	output wire [(BT_WIDTH-1):0] InFIFOBTIn,
	output wire [(NEURON_WIDTH-1):0] InFIFONIDIn,

	input wire [(BT_WIDTH-1):0] InFIFOBTOut,
	input wire [(NEURON_WIDTH-1):0] InFIFONIDOut,
	input wire [(BT_WIDTH-1):0] InputBT_Head,
	input wire IsInputQueueEmpty,
	input wire IsInputQueueFull,

	//Aux FIFO
	output wire AuxReset,
	output wire AuxQueueEnable,
	output wire AuxEnqueue,
	output wire AuxDequeue,
	output wire [(BT_WIDTH-1):0] AuxFIFOBTIn,
	output wire [(NEURON_WIDTH-1):0] AuxFIFONIDIn,

	input wire [(BT_WIDTH-1):0] AuxFIFOBTOut,
	input wire [(NEURON_WIDTH-1):0] AuxFIFONIDOut,
	input wire [(BT_WIDTH-1):0] AuxBT_Head,
	input wire IsAuxQueueEmpty,
	input wire IsAuxQueueFull,

	//Out FIFO
	output wire OutReset,
	output wire OutQueueEnable,
	output wire OutEnqueue,
	output wire OutDequeue,
	output wire [(BT_WIDTH-1):0] OutFIFOBTIn,
	output wire [(NEURON_WIDTH-1):0] OutFIFONIDIn,

	input wire [(BT_WIDTH-1):0] OutFIFOBTOut,
	input wire [(NEURON_WIDTH-1):0] OutFIFONIDOut,
	input wire [(BT_WIDTH-1):0] OutBT_Head,
	input wire IsOutQueueEmpty,
	input wire IsOutQueueFull

	);

 
	wire [BT_WIDTH-1:0] InternalCurrent_BT;
	wire InputRouteInputSelect, InputRoutingComplete, InputRouteReset, InputRouteInitialize, InputRouteEnable, InternalRoutingComplete, InternalRouteReset, InternalRouteEnable;
	wire MapNeurons, MappingComplete, NeuronUnitReset, NeuronUnitInitialize, UpdateEnable, UpdateComplete;
	assign InFIFOBTIn = ExternalBTIn;
	assign InFIFONIDIn = ExternalNIDIn;
	assign ExternalBTOut = OutFIFOBTOut;
	assign ExternalNIDOut = OutFIFONIDOut;



	/***************************************************************
		SYSTEM CONTROLLER	
	***************************************************************/
	SysControl #(BT_WIDTH, DELTAT_WIDTH) SysCtrl
	(
		//External Inputs
		.Clock(Clock),
		.Reset(Reset),
		.Initialize(Initialize),
		.ExternalEnqueue(ExternalEnqueue),
		.ExternalDequeue(ExternalDequeue),
		.Run(Run),

		//Global Inputs
		.DeltaT(DeltaT),
	
		//Input FIFO I/O	
		.IsInputQueueFull(IsInputQueueFull),
		.IsInputQueueEmpty(IsInputQueueEmpty),
		.InputBT_Head(InputBT_Head),

		.InputReset(InputReset),
		.InputQueueEnable(InputQueueEnable),
		.InputEnqueue(InputEnqueue),
		.InputDequeue(InputDequeue),

		//Auxiliary FIFO I/O
		.IsAuxQueueFull(IsAuxQueueFull),
		.IsAuxQueueEmpty(IsAuxQueueEmpty),
		.AuxBT_Head(AuxBT_Head),

		.AuxReset(AuxReset),
		.AuxQueueEnable(AuxQueueEnable),
		.AuxDequeue(AuxDequeue),

		//Output FIFO I/O
		.IsOutQueueFull(IsOutQueueFull),
		.IsOutQueueEmpty(IsOutQueueEmpty),
		.OutBT_Head(OutBT_Head),

		.OutReset(OutReset),
		.OutQueueEnable(OutQueueEnable),
		.OutDequeue(OutDequeue),

		//Queue Selector switch
		.InputRouteInputSelect(InputRouteInputSelect),
	
		//Input Router I/O
		.InputRoutingComplete(InputRoutingComplete),
	
		.InputRouteReset(InputRouteReset),
		.InputRouteInitialize(InputRouteInitialize),
		.InputRouteEnable(InputRouteEnable),

		//Internal Router I/O
		.InternalRoutingComplete(InternalRoutingComplete),
	
		.InternalRouteReset(InternalRouteReset),
		.InternalCurrent_BT(InternalCurrent_BT),
		.InternalRouteEnable(InternalRouteEnable),
	
		//Neuron Unit I/O
		.MappingComplete(MappingComplete),
		.UpdateComplete(UpdateComplete),
		
		.NeuronUnitReset(NeuronUnitReset),
		.NeuronUnitInitialize(NeuronUnitInitialize),
		.MapNeurons(MapNeurons),
		.UpdateEnable(UpdateEnable),

		//Top level Outputs
		.InitializationComplete(InitializationComplete)

	);

	
	
	wire FromRouterEXChipEnable, FromRouterINChipEnable, FromRouterEXWriteEnable, FromRouterINWriteEnable; 
	wire [(NEURON_WIDTH-1):0] FromRouterEXAddress, FromRouterINAddress;
	wire signed [(DATA_WIDTH-1):0] FromRouterNewExWeightSum, FromRouterNewInWeightSum;
	wire signed [(DATA_WIDTH-1):0] ToRouterExWeightSum, ToRouterInWeightSum;
	


	wire [(NEURON_WIDTH-1):0] InputRouterNeuronID;
	assign InputRouterNeuronID = (InputRouteInputSelect == 1'b0) ? InFIFONIDOut : AuxFIFONIDOut; 
		
		
	/***************************************************************
			INPUT ROUTER 	
	***************************************************************/
	InputRouter #(INTEGER_WIDTH, DATA_WIDTH_FRAC, DATA_WIDTH, NEURON_WIDTH_LOGICAL, NEURON_WIDTH, NEURON_WIDTH_INPUT, WRAM_ROW_WIDTH, WRAM_COLUMN_WIDTH, WRAM_ADDR_WIDTH, INPUT_NEURON_START, LOGICAL_NEURON_START) IPRoute
	(
		//Control Signals
		.Clock(Clock),
		.Reset(InputRouteReset),
		.RouteEnable(InputRouteEnable),
		.Initialize(InputRouteInitialize),

		//Network Information
		.ExRangeLOWER(ExRangeLOWER),			
		.ExRangeUPPER(ExRangeUPPER),			
		.InRangeLOWER(InRangeLOWER),					
		.InRangeUPPER(InRangeUPPER),			
		.IPRangeLOWER(IPRangeLOWER),			
		.IPRangeUPPER(IPRangeUPPER),			
		.NeuStart(NeuStart),
		.NeuEnd(NeuEnd),						
	
		//QueueInputs
		.NeuronID(InputRouterNeuronID),				

		//Inputs from Synaptic RAM							
		.WeightData(WeightData),		

		//Outputs to Synaptic RAM			
		.WChipEnable(WChipEnable),									
		.WRAMAddress(WRAMAddress),				

		//Inputs from Neuron Unit			
		.ExWeightSum(ToRouterExWeightSum),			
		.InWeightSum(ToRouterInWeightSum),		
	
		//Outputs to Neuron Unit
		.EXChipEnable(FromRouterEXChipEnable),				
		.INChipEnable(FromRouterINChipEnable),				
		.EXWriteEnable(FromRouterEXWriteEnable),				
		.INWriteEnable(FromRouterINWriteEnable),				
		.EXAddress(FromRouterEXAddress),		
		.INAddress(FromRouterINAddress),		
		.NewExWeightSum(FromRouterNewExWeightSum),					
		.NewInWeightSum(FromRouterNewInWeightSum),		

	
		.RoutingComplete(InputRoutingComplete)
	);

	
	wire [(2**NEURON_WIDTH - 1):0] SpikeWord;

	/***************************************************************
		NEURON UNIT	
	***************************************************************/
	NeuronUnit #(INTEGER_WIDTH, DATA_WIDTH_FRAC, DATA_WIDTH, DELTAT_WIDTH, TREF_WIDTH, NEURON_WIDTH_LOGICAL, NEURON_WIDTH_PHYSICAL, NEURON_WIDTH, TDMPOWER, SPNR_WORD_WIDTH, SPNR_ADDR_WIDTH, EXTEND_WIDTH) CLIFNU
	(
		//Control Signals
		.Clock(Clock),
		.Reset(NeuronUnitReset),
		.UpdateEnable(UpdateEnable),
		.RouteEnable(InputRouteEnable),
		.Initialize(NeuronUnitInitialize),
		.MapNeurons(MapNeurons),


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

	
		//Network Information
		.ExRangeLOWER(ExRangeLOWER),			
		.ExRangeUPPER(ExRangeUPPER),			
		.InRangeLOWER(InRangeLOWER),					
		.InRangeUPPER(InRangeUPPER),			
		.IPRangeLOWER(IPRangeLOWER),			
		.IPRangeUPPER(IPRangeUPPER),			
		.NeuStart(NeuStart),			
		.NeuEnd(NeuEnd),

	
		//Global Inputs
		.DeltaT(DeltaT),


		//Inputs from Router 
		.FromRouterEXChipEnable(FromRouterEXChipEnable),
		.FromRouterINChipEnable(FromRouterINChipEnable),
		.FromRouterEXWriteEnable(FromRouterEXWriteEnable),
		.FromRouterINWriteEnable(FromRouterINWriteEnable),
		.FromRouterEXAddress(FromRouterEXAddress),
		.FromRouterINAddress(FromRouterINAddress),
		.FromRouterNewExWeightSum(FromRouterNewExWeightSum),					
		.FromRouterNewInWeightSum(FromRouterNewInWeightSum),

		
		//Inputs from Theta RAM
		.ThetaData(ThetaData),	

	
		//Outputs to Router 
		.ToRouterExWeightSum(ToRouterExWeightSum),
		.ToRouterInWeightSum(ToRouterInWeightSum),

		
		//Outputs to Theta RAM
		.ThetaChipEnable(ThetaChipEnable),
		.ThetaAddress(ThetaAddress),


		//Outputs to Internal Router
		.SpikeBufferOut(SpikeWord),

	
		//Control Outputs
		.MappingComplete(MappingComplete),
		.UpdateComplete(UpdateComplete),

		//Outputs to SPNR
		.SPNR_CE(SPNR_CE),
		.SPNR_WE(SPNR_WE),
		.SPNR_IA(SPNR_IA),
		.SPNR_ID(SPNR_ID),

		//Inputs from SPNR
		.SPNR_OD(SPNR_OD)

		

	);

	
	
	

	/***************************************************************
		INTERNAL ROUTER 	
	***************************************************************/
	InternalRouter #(NEURON_WIDTH_LOGICAL, NEURON_WIDTH, BT_WIDTH, DELTAT_WIDTH) INTRoute
	(
		//Control Signals
		.Clock(Clock),
		.Reset(InternalRouteReset),
		.RouteEnable(InternalRouteEnable),
		.Current_BT(InternalCurrent_BT),

		//Network Information
		.NeuStart(NeuStart),
		.OutRangeLOWER(OutRangeLOWER),
		.OutRangeUPPER(OutRangeUPPER),
	
		//Global Inputs
		.DeltaT(DeltaT),
	
		//Inputs from Neuron Unit
		.SpikeBuffer(SpikeWord),
	
		//To Auxiliary Queue
		.ToAuxEnqueueOut(AuxEnqueue),
		.ToAuxBTOut(AuxFIFOBTIn),
		.ToAuxNIDOut(AuxFIFONIDIn),
	
		//To Output Queue
		.ToOutEnqueueOut(OutEnqueue),
		.ToOutBTOut(OutFIFOBTIn),
		.ToOutNIDOut(OutFIFONIDIn),
	
		//Control Outputs
		.RoutingComplete(InternalRoutingComplete)
	);
	
		



endmodule
