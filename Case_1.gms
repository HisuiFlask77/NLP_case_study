$Title Refinery Hydrogen Network Optimization
$Ontext
SYSTEM OVERVIEW:
This model addresses a Refinery Hydrogen Management problem


PROBLEM DESCRIPTION:
The network is modeled as a Superstructure, where multiple sources, sinks, 
and purification units are interconnected:

1. Hydrogen Sources (Supply):
   - External/Fresh Sources (e.g., SMR): High purity, high marginal cost.
   - Internal By-product Sources (e.g., CCR): Purity depends on unit operation.

2. Hydrogen Sinks (Demand):
   - Processing units (HCU, DHT, etc.) require a specific total volume of 
     hydrogen and a minimum threshold of purity at the inlet to maintain 
     catalyst activity and partial pressure requirements.

3. Purification Unit (PSA - Pressure Swing Adsorption):
   - Acts as a "Source-Sink" intermediary. It accepts low-purity off-gas from 
     sinks and upgrades it to high-purity hydrogen, subject to a recovery 
     percentage (hydrogen loss in the tail gas).

4. Interconnection & Reuse:
   - "Off-gas" from higher-pressure/higher-purity sinks can be directly 
     recycled to lower-requirement sinks or sent to the PSA for upgrading. 
     Excess gas is sent to the Fuel Gas System (Waste).


MATHEMATICAL CHARACTERISTICS:
- Model Type: NLP.
- Core Complexity: The mixing of streams with different purities results in 
  "Bilinear Terms" (Flow Rate * Purity). This creates a non-convex 
  optimization space where local optima may exist.
- Objective: To minimize the TAC
  
$Offtext

* -----------------------------------------------------------------------------
* 1. Set Definitions
* -----------------------------------------------------------------------------
Sets
    H2_Source      "Hydrogen production units"  / SMR, CCR1, CCR2 /
    H2_Sink        "Hydrogen consumption units" / HCU, DHT, NHT, GHT /
    Purifier       "Purification units"         / PSA /;

Alias (H2_Sink, sink_in);
Alias (H2_Sink, sink_out);

* -----------------------------------------------------------------------------
* 2. Parameter Input - Based on typical refinery data
* -----------------------------------------------------------------------------
Parameters
* --- Source Data ---
    Y_Source(H2_Source)    "Hydrogen source purity (vol fraction)"
                           / SMR 0.999, CCR1 0.850, CCR2 0.800 /
    Cost_Source(H2_Source) "Hydrogen production cost ($/kmol)"
                           / SMR 5.0,   CCR1 0.5,   CCR2 0.5 /
    Max_Supply(H2_Source)  "Maximum supply capacity (kmol/h)"
                           / SMR 5000, CCR1 2000, CCR2 1500 /

* --- Sink Data (Constraints) ---
    F_Sink_Req(H2_Sink)    "Required standard flow rate at sink inlet (kmol/h)"
                           / HCU 3000, DHT 1500, NHT 800, GHT 600 /
    Y_Sink_Min(H2_Sink)    "Minimum purity requirement at sink inlet (vol fraction)"
                           / HCU 0.95, DHT 0.85, NHT 0.80, GHT 0.75 /
    
* --- Sink Outlet Data (For Reuse) ---

    F_Sink_Out(H2_Sink)    "Hydrogen sink outlet discharge flow (kmol/h)"
                           / HCU 2400, DHT 1200, NHT 600, GHT 450 /
    Y_Sink_Out(H2_Sink)    "Hydrogen sink outlet discharge purity (vol fraction)"
                           / HCU 0.88, DHT 0.75, NHT 0.65, GHT 0.50 /

* --- PSA Parameters ---
    PSA_Recovery           "PSA hydrogen recovery rate" / 0.90 /
    PSA_Purity_Out         "PSA product purity"         / 0.999 /;

* -----------------------------------------------------------------------------
* 3. Variable Definitions
* -----------------------------------------------------------------------------
Positive Variables
* --- Flow Variables ---
    F_Sr_Sk(H2_Source, H2_Sink)      "Source -> Sink (Fresh hydrogen)"
    F_Sr_PSA(H2_Source)              "Source -> PSA"
    
    F_Sk_Sk(sink_out, sink_in)       "Sink outlet -> Sink inlet (Direct reuse - Core complexity)"
    F_Sk_PSA(sink_out)               "Sink outlet -> PSA (Purification for reuse)"
    
    F_PSA_Sk(H2_Sink)                "PSA product -> Sink"
    F_Waste(sink_out)                "Sink outlet -> Fuel gas network (Waste)"
    
* --- State Variables ---
    Y_Inlet(H2_Sink)                 "Actual purity after mixing at sink inlet (NLP variable)";

Variables
    Total_Cost                       "Total cost (Objective function)";

* -----------------------------------------------------------------------------
* 4. Initialization & Scaling
* NLP Solving Key: Without initial values, division by zero or vanishing gradients 
* might cause solver failure.
* -----------------------------------------------------------------------------
* Assume all inlet purities initially meet requirements to provide a good starting point.
Y_Inlet.l(H2_Sink) = Y_Sink_Min(H2_Sink) + 0.01;
Y_Inlet.lo(H2_Sink) = 0;
Y_Inlet.up(H2_Sink) = 1.0;

* Upper bounds on flows to assist convergence
F_Sr_Sk.up(H2_Source, H2_Sink) = 5000;
F_Sk_Sk.up(sink_out, sink_in)  = 5000;

* -----------------------------------------------------------------------------
* 5. Equation Definitions
* -----------------------------------------------------------------------------
Equations
    Eq_Obj                      "Objective function"
    
* --- Mass Balance (Sink Inlet) ---
    Eq_Sink_FlowBal(H2_Sink)    "Sink inlet flow balance"
    Eq_Sink_SpecBal(H2_Sink)    "Sink inlet component balance (Bilinear NLP)"
    
* --- Mass Balance (Sink Outlet) ---
    Eq_Sink_OutSplit(H2_Sink)   "Sink outlet distribution balance"
    
* --- PSA Balance ---
    Eq_PSA_Bal                  "PSA total mass balance (based on recovery)"
    
* --- Constraints ---
    Eq_Purity_Limit(H2_Sink)    "Purity constraint: mixed purity >= minimum requirement"
    Eq_Source_Limit(H2_Source)  "Hydrogen source capacity limit";

* 1. Objective: Minimize hydrogen purchase cost (could include compression power; 
* simplified here to material cost only)
Eq_Obj..
    Total_Cost =e= sum((H2_Source, H2_Sink), F_Sr_Sk(H2_Source, H2_Sink) * Cost_Source(H2_Source))
                 + sum(H2_Source, F_Sr_PSA(H2_Source) * Cost_Source(H2_Source));

* 2. Sink inlet flow balance: 
* Total Inlet Flow = From Sources + From Other Sink Reuse + From PSA
Eq_Sink_FlowBal(H2_Sink)..
    F_Sink_Req(H2_Sink) =e= sum(H2_Source, F_Sr_Sk(H2_Source, H2_Sink))
                          + sum(sink_out, F_Sk_Sk(sink_out, H2_Sink))
                          + F_PSA_Sk(H2_Sink);

* 3. Sink inlet component balance (NLP Core):
* Flow * Purity = Component Amount
Eq_Sink_SpecBal(H2_Sink)..
    sum(H2_Source, F_Sr_Sk(H2_Source, H2_Sink) * Y_Source(H2_Source))
  + sum(sink_out,  F_Sk_Sk(sink_out, H2_Sink) * Y_Sink_Out(sink_out))
  + F_PSA_Sk(H2_Sink) * PSA_Purity_Out
    =e= 
    F_Sink_Req(H2_Sink) * Y_Inlet(H2_Sink);

* 4. Purity Hard Constraint
Eq_Purity_Limit(H2_Sink)..
    Y_Inlet(H2_Sink) =g= Y_Sink_Min(H2_Sink);

* 5. Sink outlet distribution (Splitter):
* Total outlet from a unit = Reused to other units + To PSA + To Waste
Eq_Sink_OutSplit(sink_out)..
    F_Sink_Out(sink_out) =e= sum(sink_in, F_Sk_Sk(sink_out, sink_in))
                           + F_Sk_PSA(sink_out)
                           + F_Waste(sink_out);

* 6. PSA Unit Model (Simplified black-box model):
* Pure hydrogen output = (Pure hydrogen in feed) * Recovery
Eq_PSA_Bal..
    sum(H2_Sink, F_PSA_Sk(H2_Sink)) * PSA_Purity_Out 
    =e= 
    (
      sum(H2_Source, F_Sr_PSA(H2_Source) * Y_Source(H2_Source)) +
      sum(sink_out,  F_Sk_PSA(sink_out) * Y_Sink_Out(sink_out))
    ) * PSA_Recovery;

* 7. Supply Limit
Eq_Source_Limit(H2_Source)..
    sum(H2_Sink, F_Sr_Sk(H2_Source, H2_Sink)) + F_Sr_PSA(H2_Source) =l= Max_Supply(H2_Source);

* -----------------------------------------------------------------------------
* 6. Model Solution
* -----------------------------------------------------------------------------
Model Hydrogen_Network /all/;

* Scaling is critical here: Flows are magnitude 1000, purities are magnitude 0.1.
* Good solvers handle this automatically, but manual adjustment may be needed.
Hydrogen_Network.optfile = 1;

Solve Hydrogen_Network using NLP minimizing Total_Cost;

* -----------------------------------------------------------------------------
* 7. Results Reporting
* -----------------------------------------------------------------------------
Display Total_Cost.l, Y_Inlet.l;

Parameter Purity_Check(H2_Sink);
Purity_Check(H2_Sink) = Y_Inlet.l(H2_Sink) - Y_Sink_Min(H2_Sink);
Display Purity_Check;

* Generate flow matrix report for easier visualization of reuse patterns
Parameter Network_Matrix(sink_out, sink_in);
Network_Matrix(sink_out, sink_in) = F_Sk_Sk.l(sink_out, sink_in);
Display Network_Matrix;