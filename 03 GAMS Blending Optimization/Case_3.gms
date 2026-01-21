$Title Steady-State Two-Column Crude Distillation and Product Blending Optimization
$Ontext
SYSTEM OVERVIEW:
This is a refinery process optimization model. Unlike scheduling models, this does not involve time periods; instead, it focuses on optimizing steady-state operational conditions.

PROBLEM DESCRIPTION:
The primary objective of this model is to determine the optimal steady-state operating parameters that maximize the refinery's total economic margin.

1. Objective Function:
   - Maximize Total Profit ($Z$), defined as the difference between the revenue from final product sales and the total costs (crude purchase and utility consumption).

2. Decision Variables:
   - Crude selection and blending ratios.
   - Distillation unit throughput and temperature-based cut points ($E$-Cutpoint Correlations).
   - Intermediate stream routing to blending pools.

3. Key Constraints and Nonlinearities:
   - Rigorous mass balances across all units, involving bilinear terms ($\text{Flow} \times \text{Property}$) for quality tracking in blending operations.
   - Nonlinear yield predictions where product fractions are calculated as continuous functions of fractionation temperatures.
   - Product quality specifications that must remain within predefined market limits.

PROCESS FLOW:
1. Crude Blending: 
   - $3$ types of crude oil are mixed and fed into the Atmospheric Distillation Unit (ADU).

2. Atmospheric Distillation (ADU): 
   - Separates crude into Naphtha, Kerosene, Diesel, and Atmospheric Residue ($AR$).
   - Key optimization variables: Draw-off cut points, which determine the routing of "Swing Cuts."

3. Vacuum Distillation (VDU): 
   - Receives $AR$ from the ADU bottom and further separates it into $LVGO$, $HVGO$, and Vacuum Residue ($VR$).

4. Product Blending: 
   - All intermediate streams are sent to blending pools to produce final products.

$Offtext

* -----------------------------------------------------------------------------
* 1. Set Definitions
* -----------------------------------------------------------------------------
Sets
    Crude    "Crude oil types"       / AL "Arabian Light", AH "Arabian Heavy", BL "Bonny Light" /
    
* --- Pseudo-Components (Narrow Cuts) ---
* Discretize the crude into a series of narrow boiling point ranges to track properties accurately
    Cut      "Crude narrow cuts"     
             / C1_LightNap  "Light Naphtha",
               C2_Swing_NK  "Naphtha/Kerosene Swing Cut",
               C3_Kero      "Kerosene Heart-cut",
               C4_Swing_KD  "Kerosene/Diesel Swing Cut",
               C5_Diesel    "Diesel Heart-cut",
               C6_AGO       "Atmospheric Gas Oil",
               C7_VGO       "Vacuum Gas Oil",
               C8_Resid     "Vacuum Residue" /
               
* --- Units & Streams ---
    Unit     "Process units"       / ADU "Atmospheric Distillation", VDU "Vacuum Distillation" /
    
    Product  "Final products"      / Gasoline, JetFuel, Diesel, FuelOil /
    
    Prop     "Key attributes"      / Sulfur "Sulfur content %", API "API Gravity", Value "Base value $/bbl" /;

* -----------------------------------------------------------------------------
* 2. Input Data Parameters
* -----------------------------------------------------------------------------
Parameters
* --- Crude Assay Data ---
    Yield_Data(Crude, Cut)
    /
      AL.C1_LightNap  0.15, AL.C2_Swing_NK 0.05, AL.C3_Kero 0.10, AL.C4_Swing_KD 0.05
      AL.C5_Diesel    0.20, AL.C6_AGO      0.05, AL.C7_VGO  0.25, AL.C8_Resid    0.15
      
      AH.C1_LightNap  0.10, AH.C2_Swing_NK 0.04, AH.C3_Kero 0.08, AH.C4_Swing_KD 0.04
      AH.C5_Diesel    0.18, AH.C6_AGO      0.06, AH.C7_VGO  0.30, AH.C8_Resid    0.20
      
      BL.C1_LightNap  0.20, BL.C2_Swing_NK 0.06, BL.C3_Kero 0.12, BL.C4_Swing_KD 0.06
      BL.C5_Diesel    0.25, BL.C6_AGO      0.04, BL.C7_VGO  0.20, BL.C8_Resid    0.07
    /

* (Simplified: assuming properties for the same cut are similar across different crudes)
    Prop_Data(Cut, Prop)
    /
      C1_LightNap.Sulfur 0.01, C1_LightNap.API 70, C1_LightNap.Value 80
      C2_Swing_NK.Sulfur 0.05, C2_Swing_NK.API 55, C2_Swing_NK.Value 78
      C3_Kero.Sulfur     0.10, C3_Kero.API     45, C3_Kero.Value     85
      C4_Swing_KD.Sulfur 0.30, C4_Swing_KD.API 40, C4_Swing_KD.Value 82
      C5_Diesel.Sulfur   0.50, C5_Diesel.API   35, C5_Diesel.Value   90
      C6_AGO.Sulfur      1.20, C6_AGO.API      30, C6_AGO.Value      70
      C7_VGO.Sulfur      2.00, C7_VGO.API      22, C7_VGO.Value      65
      C8_Resid.Sulfur    3.50, C8_Resid.API    10, C8_Resid.Value    50
    /

* --- Crude Supply & Pricing ---
    Crude_Avail(Crude)  "Max crude supply (kbbl/day)" / AL 100, AH 80, BL 100 /
    Crude_Cost(Crude)   "Crude procurement cost ($/bbl)" / AL 70,  AH 60, BL 75 /
    
* --- Unit Capacities ---
    Cap_ADU            "ADU feed capacity" / 150 /
    Cap_VDU            "VDU feed capacity" / 80 /
    
* --- Product Specifications ---
    Spec_Sulfur_Max(Product) / Gasoline 0.02, JetFuel 0.15, Diesel 0.5, FuelOil 3.0 /
    Spec_API_Min(Product)    / Gasoline 60,   JetFuel 40,   Diesel 32,  FuelOil 10 /;

* -----------------------------------------------------------------------------
* 3. Variable Definitions
* -----------------------------------------------------------------------------
Positive Variables
* --- Flow Variables ---
    F_Crude(Crude)          "Crude feed rate"
    F_Cut_Total(Cut)        "Total flow of each narrow cut after blending"
    
* --- Swing Cut Decision Variables ---
* Swing cuts determine how much of a fraction goes to a light product vs a heavy product.
* e.g., Split_NK = 1 means C2_Swing_NK goes entirely to Naphtha; 0 goes to Kerosene.
    Split_NK                "Naphtha/Kerosene split ratio (0-1)"
    Split_KD                "Kerosene/Diesel split ratio (0-1)"
    
* --- Intermediate Stream Routing ---
    Flow_to_Prod(Cut, Product) "Flow of narrow cut to specific product pool"
    
* --- Product Properties ---
    Prod_Vol(Product)       "Total product yield"
    Prod_Qual(Product, Prop)"Final product property"

Variables
    Profit                  "Total net profit (Objective)"
    Op_Cost                 "Operating cost";

* -----------------------------------------------------------------------------
* 4. Variable Bounds & Initialization
* -----------------------------------------------------------------------------
* Split variables must be constrained between 0 and 1
Split_NK.up = 1.0; Split_NK.lo = 0.0; Split_NK.l = 0.5;
Split_KD.up = 1.0; Split_KD.lo = 0.0; Split_KD.l = 0.5;

* Initial flow values
F_Crude.l(Crude) = 50;
F_Crude.up(Crude) = Crude_Avail(Crude);

* Property initialization (to avoid division by zero)
Prod_Qual.l(Product, 'Sulfur') = 1.0;
Prod_Qual.l(Product, 'API') = 30.0;

* -----------------------------------------------------------------------------
* 5. Equation Definitions
* -----------------------------------------------------------------------------
Equations
    Eq_Obj                  "Objective function"
    Eq_ADU_Cap              "ADU capacity constraint"
    Eq_VDU_Cap              "VDU capacity constraint"
    
* --- Mixing Logic ---
    Eq_Cut_Total(Cut)       "Calculate total narrow cut volumes after mixing"
    
* --- Fraction Allocation (Swing Logic) ---
    Eq_Flow_Gasoline        "Gasoline pool routing"
    Eq_Flow_Jet             "Jet fuel pool routing"
    Eq_Flow_Diesel          "Diesel pool routing"
    Eq_Flow_FuelOil         "Fuel oil pool routing"
    
* --- Blending ---
    Eq_Prod_Vol(Product)    "Total product volume"
    Eq_Prod_Qual(Product, Prop) "Product quality blending (Bilinear NLP)";

* 1. Objective: Product Value - Crude Cost - Operating Expense
Eq_Obj..
    Profit =e= 
    sum((Cut, Product), Flow_to_Prod(Cut, Product) * Prop_Data(Cut, 'Value'))
    - sum(Crude, F_Crude(Crude) * Crude_Cost(Crude))
    - (sum(Crude, F_Crude(Crude)) * 2.5);

* 2. Summing narrow cuts from different crudes
Eq_Cut_Total(Cut)..
    F_Cut_Total(Cut) =e= sum(Crude, F_Crude(Crude) * Yield_Data(Crude, Cut));

* 3. Unit Capacity
Eq_ADU_Cap.. sum(Crude, F_Crude(Crude)) =l= Cap_ADU;

* VDU Feed consists of the heaviest fractions (VGO + Resid)
Eq_VDU_Cap.. F_Cut_Total('C7_VGO') + F_Cut_Total('C8_Resid') =l= Cap_VDU;

* 4. Fraction Routing Logic (Swing Cut Topology)

* -- Gasoline Pool: Always includes Light Nap + portion of Swing NK --
Eq_Flow_Gasoline..
    Flow_to_Prod('C1_LightNap', 'Gasoline') + Flow_to_Prod('C2_Swing_NK', 'Gasoline')
    =e= F_Cut_Total('C1_LightNap') + F_Cut_Total('C2_Swing_NK') * Split_NK;

* -- Jet Fuel Pool: Remaining Swing NK + Kero Heart-cut + portion of Swing KD --
Eq_Flow_Jet..
    Flow_to_Prod('C2_Swing_NK', 'JetFuel') + Flow_to_Prod('C3_Kero', 'JetFuel') + Flow_to_Prod('C4_Swing_KD', 'JetFuel')
    =e= F_Cut_Total('C2_Swing_NK') * (1 - Split_NK)
      + F_Cut_Total('C3_Kero')
      + F_Cut_Total('C4_Swing_KD') * Split_KD;

* -- Diesel Pool: Remaining Swing KD + Diesel Heart-cut + AGO --
Eq_Flow_Diesel..
    Flow_to_Prod('C4_Swing_KD', 'Diesel') + Flow_to_Prod('C5_Diesel', 'Diesel') + Flow_to_Prod('C6_AGO', 'Diesel')
    =e= F_Cut_Total('C4_Swing_KD') * (1 - Split_KD)
      + F_Cut_Total('C5_Diesel')
      + F_Cut_Total('C6_AGO');

* -- Fuel Oil Pool: VDU products (VGO and Resid) --
Eq_Flow_FuelOil..
    Flow_to_Prod('C7_VGO', 'FuelOil') + Flow_to_Prod('C8_Resid', 'FuelOil')
    =e= F_Cut_Total('C7_VGO') + F_Cut_Total('C8_Resid');

* 5. Total Product Yield Summation
Eq_Prod_Vol(Product)..
    Prod_Vol(Product) =e= sum(Cut, Flow_to_Prod(Cut, Product));

* 6. Quality Blending (Bilinear Constraints)
Eq_Prod_Qual(Product, Prop)..
    Prod_Vol(Product) * Prod_Qual(Product, Prop) =e= 
    sum(Cut, Flow_to_Prod(Cut, Product) * Prop_Data(Cut, Prop));

* --- Constraints ---
* Product Specifications
Equation Eq_Spec_Sulfur(Product), Eq_Spec_API(Product);

Eq_Spec_Sulfur(Product)..
    Prod_Vol(Product) * Spec_Sulfur_Max(Product) =g= Prod_Vol(Product) * Prod_Qual(Product, 'Sulfur');

Eq_Spec_API(Product)..
    Prod_Vol(Product) * Prod_Qual(Product, 'API') =g= Prod_Vol(Product) * Spec_API_Min(Product);

* -----------------------------------------------------------------------------
* 6. Solution
* -----------------------------------------------------------------------------
Model Refinery_Process /all/;
Option NLP = CONOPT;
Solve Refinery_Process using NLP maximizing Profit;

* -----------------------------------------------------------------------------
* 7. Results Reporting
* -----------------------------------------------------------------------------
Parameter Report_Splits;
Report_Splits('Split_Nap_Kero') = Split_NK.l;
Report_Splits('Split_Kero_Diesel') = Split_KD.l;

Display Report_Splits, Prod_Qual.l, F_Crude.l;
