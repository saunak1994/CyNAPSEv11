**The CyNAPSE Neuromorphic Accelerator Verilog repository**
Authors: 
1. Saunak Saha, Graduate student, Iowa State University
2. Dr. Henry Duwe, Assistant Professor, Iowa State University
3. Dr. Joseph Zambreno, Professor, Iowa State University


This repository is part of a paper titled: 
"*An Adaptive Memory Management Strategy Towards Energy Efficient Machine Inference in Event-Driven Neuromorphic Accelerators*" (2019)
Please use the following to cite our paper: 
"
Will be updated soon .. 
"

**Architecture Hierarchy:** (Refer to figure CyNAPSE_Arch.pdf)

**Fully synthesizable modules:**

1. (GexLeakUnit.v , GinLeakUnit.v, VmemLeakUnit.v, EPSCUnit.v, IPSCUnit.v, ThresholdUnit.v, SynapticIntegrationUnit.v) -> ConductanceLIFNeuronUnit.v : An implementation of the LIF Neuron with conductanc-based synapses and inhibitory+excitatory synapses for competitive learning
2. (InputFIFO.v) : An implementation of a circular FIFO queue used in our architecture as input, output and auxiliary queues 
3. (InputRouter.v): An implementation of the Input Spike Routing Finite State Machine used in our architecture.
4. (InternalRouter.v): An implementation of the internal event routing module to the auxiliary queue
5. (ConductanceLIFNeuronUnit.v) -> NeuronUnit.v: multiple physical neurons into the Neuron Unit
6. (SysControl.v) -> System Controller and global timer
7. (NeuronUnit.v, InputFIFO.v, InputRouter.v, InternalRouter.v, SysControl.v) -> Top.v : Top module of our architecture

**Non-synthesizable modules**:

1. (SinglePortNeuronRAM.v) -> Model of Dendritic tree scratchpad SRAMs
2. (SinglePortOffChipRAM.v) -> Model of external synaptic store 
3. (Top_tb.v) -> A testbench for testing one of our benchmarks. Change binaries to test SDBN, SCWN OR SCNN accuracy. 


**Binaries**: 
Download the binaries here: https://drive.google.com/file/d/1tf28bhk9uzxP5EPs3OrcLNsgeVLS7aII/view?usp=sharing
CyNAPSEbin.tar.gz contains binaries for the Weights, Input AER Events (BTIn and NIDIn) and the Homeostatic thresholds Theta (only for SCWN) for each of the benchmarks
Use the appropriate one in the benchmark testbench Top_tb.v


For help, questions or comments please read our paper or feel free to reach out to:
saunak.0313@gmail.com

