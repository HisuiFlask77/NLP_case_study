$Title Multi-Period Refinery Crude Oil Scheduling Optimization
$Ontext
This is a simplified industrial-scale refinery scheduling model.


SCENARIO OVERVIEW:
1. Time Horizon: 10 Days (T1-T10), with each day representing a decision period.
2. Feedstock: 3 types of crude oil (Arabian Light, Heavy, Bonny) arriving via vessels on specific dates.
3. Storage: 4 crude mixing tanks where non-linear blending occurs.
4. Processing: 2 Crude Distillation Units (CDU) with varying capacities and yield profiles.
5. Objective: Maximize total profit (Product Value - Crude Cost - Inventory Holding Cost - Switching Costs).


Dynamic Tank Quality Balance:
V(t) * C(t) = V(t-1) * C(t-1) + Sum(F_in * C_in) - Sum(F_out * C(t))

$Offtext

* -----------------------------------------------------------------------------
* 1. Set Definitions
* -----------------------------------------------------------------------------
Sets
    T        "Time horizon (Days)"   / t1*t10 /
    Crude    "Crude oil categories" / AL "Arabian Light", AH "Arabian Heavy", BL "Bonny Light" /
    Tank     "Crude storage tanks"  / TK101, TK102, TK103, TK104 /
    CDU      "Crude Distillation Units" / CDU_A, CDU_B /
    Prop     "Quality attributes"       / Sulfur "Sulfur Content", Gravity "API Gravity" /;

* Alias set for handling time-lagged (t-1) calculations
Alias(T, tp);

* -----------------------------------------------------------------------------
* 2. Parameter Input
* -----------------------------------------------------------------------------
Parameters
* --- Crude Assay & Pricing ---
    Crude_Price(Crude)    "Crude unit price ($/bbl)"       / AL 70, AH 60, BL 75 /
    Crude_Qual(Crude,Prop)"Crude assay properties"
                          / AL.Sulfur 1.8,  AL.Gravity 33
                            AH.Sulfur 2.9,  AH.Gravity 27
                            BL.Sulfur 0.14, BL.Gravity 35 /

* --- Vessel Arrival Schedule ---
* Sparse parameter representing scheduled cargo arrivals
    Arrival_Vol(T, Crude) "Arriving crude volume (kbbl)"
    Arrival_Qual(T, Crude, Prop);

* Initialize vessel arrival data (Simulated)
    Arrival_Vol('t1', 'AL') = 500;
    Arrival_Vol('t3', 'AH') = 600;
    Arrival_Vol('t5', 'BL') = 400;
    Arrival_Vol('t8', 'AL') = 500;
    
* Assign quality to arriving crude based on assay standards
    Arrival_Qual(T, Crude, Prop)$(Arrival_Vol(T, Crude)>0) = Crude_Qual(Crude, Prop);

Parameters
* --- Tank Inventory Parameters ---
    Tank_Cap(Tank)        "Maximum tank capacity (kbbl)"    / TK101 400, TK102 400, TK103 400, TK104 400 /
    Tank_Min(Tank)        "Safe operating bottom (kbbl)"    / TK101 20,  TK102 20,  TK103 20,  TK104 20 /
    Initial_Vol(Tank)     "Initial inventory (kbbl)"        / TK101 50,  TK102 50,  TK103 0,   TK104 0 /
    Initial_Qual(Tank,Prop)"Initial inventory quality"
                          / TK101.Sulfur 1.8, TK101.Gravity 33
                            TK102.Sulfur 2.9, TK102.Gravity 27
                            TK103.Sulfur 1.0, TK103.Gravity 30
                            TK104.Sulfur 1.0, TK104.Gravity 30 /

* --- CDU Processing Parameters ---
    CDU_Cap(CDU)          "Unit daily capacity (kbbl/day)" / CDU_A 100, CDU_B 80 /
    CDU_Min(CDU)          "Unit minimum turndown rate"     / CDU_A 50,  CDU_B 40 /
    
* --- Product Value Estimation (Simplified Swing Cut Proxy) ---
* Revenue is estimated as a function of feed quality:
* Value = Base + (A * API) - (B * Sulfur)
    Val_Base      "Base margin ($/bbl)"          / 10 /
    Val_Sulfur    "Sulfur penalty ($/Sulfur %)"  / 2.5 /
    Val_API       "Light oil premium ($/API)"    / 0.5 /;

* -----------------------------------------------------------------------------
* 3. Variable Definitions
* -----------------------------------------------------------------------------
Positive Variables
* --- Flow Variables ---
    F_Unload(T, Crude, Tank)    "Vessel unloading flow to tanks"
    F_Feed(T, Tank, CDU)        "Tank charge flow to CDU"

* --- State Variables ---
    Vol(T, Tank)                "Inventory volume at end of period"
    Q_Tank(T, Tank, Prop)       "Tank quality at end of period (NLP Variable)"
    
    Q_CDU_Feed(T, CDU, Prop)    "Composite quality of CDU feed";

Variables
    Profit                      "Total net profit (Objective function)"
    Cost_Inventory              "Inventory carrying cost"
    Revenue_Product             "Gross product revenue";

* -----------------------------------------------------------------------------
* 4. Variable Initialization & Scaling
* -----------------------------------------------------------------------------
* Initial flow estimates to assist solver convergence
F_Unload.l(T, Crude, Tank)$(Arrival_Vol(T, Crude)>0) = Arrival_Vol(T, Crude) / 2;
F_Feed.l(T, Tank, CDU) = 20;

* Inventory bounds and starting values
Vol.l(T, Tank) = Initial_Vol(Tank);
Vol.up(T, Tank) = Tank_Cap(Tank);
Vol.lo(T, Tank) = Tank_Min(Tank);

* Quality bounds and starting values (Crucial for NLP stability)
Q_Tank.l(T, Tank, 'Sulfur') = 1.5;
Q_Tank.l(T, Tank, 'Gravity') = 30;
Q_Tank.lo(T, Tank, 'Sulfur') = 0.1; 
Q_Tank.up(T, Tank, 'Sulfur') = 5.0;
Q_Tank.lo(T, Tank, 'Gravity') = 10;
Q_Tank.up(T, Tank, 'Gravity') = 60;

* -----------------------------------------------------------------------------
* 5. Equation Definitions
* -----------------------------------------------------------------------------
Equations
    Eq_Obj                      "Objective function"
    
* --- Material Balance ---
    Eq_Tank_Vol_Bal(T, Tank)    "Bulk volume balance (V_t = V_t-1 + In - Out)"
    Eq_Arrival_Bal(T, Crude)    "Unloading allocation balance"
    
* --- Quality Balance (NLP) ---
    Eq_Tank_Prop_Bal(T, Tank, Prop) "Property mass balance (Core bilinear equation)"
    Eq_CDU_Prop_Mix(T, CDU, Prop)   "CDU feed quality calculation"
    
* --- Capacity Constraints ---
    Eq_CDU_Cap_Max(T, CDU)      "Maximum distillation capacity"
    Eq_CDU_Cap_Min(T, CDU)      "Minimum distillation turndown";

* 1. Objective: Maximize Revenue minus Crude Costs
Eq_Obj..
    Profit =e= 
    sum((T, Tank, CDU), 
        F_Feed(T, Tank, CDU) * (
            Val_Base + 
            Val_API * Q_Tank(T, Tank, 'Gravity') - 
            Val_Sulfur * Q_Tank(T, Tank, 'Sulfur')
        )
    )
    - sum((T, Crude, Tank), F_Unload(T, Crude, Tank) * Crude_Price(Crude));

* 2. Vessel Unloading Balance
Eq_Arrival_Bal(T, Crude)..
    sum(Tank, F_Unload(T, Crude, Tank)) =e= Arrival_Vol(T, Crude);

* 3. Tank Inventory Volume Balance (Difference Equation)
Eq_Tank_Vol_Bal(T, Tank)..
    Vol(T, Tank) =e= 
      sum(Crude, F_Unload(T, Crude, Tank))
      - sum(CDU, F_Feed(T, Tank, CDU))
      + Vol(T-1, Tank)
      + Initial_Vol(Tank) * (1$(ord(T)=1));

* 4. Tank Property Balance (Core NLP Mixing Equation)
Eq_Tank_Prop_Bal(T, Tank, Prop)..
    Vol(T, Tank) * Q_Tank(T, Tank, Prop) =e=
    sum(Crude, F_Unload(T, Crude, Tank) * Arrival_Qual(T, Crude, Prop))
    - sum(CDU, F_Feed(T, Tank, CDU)) * Q_Tank(T, Tank, Prop)
    + Vol(T-1, Tank) * Q_Tank(T-1, Tank, Prop)
    + (Initial_Vol(Tank) * Initial_Qual(Tank,Prop)) * (1$(ord(T)=1));

* 5. CDU Feed Blending Property Calculation
Eq_CDU_Prop_Mix(T, CDU, Prop)..
    sum(Tank, F_Feed(T, Tank, CDU)) * Q_CDU_Feed(T, CDU, Prop) =e=
    sum(Tank, F_Feed(T, Tank, CDU) * Q_Tank(T, Tank, Prop));

* 6. Operational Constraints
Eq_CDU_Cap_Max(T, CDU).. sum(Tank, F_Feed(T, Tank, CDU)) =l= CDU_Cap(CDU);
Eq_CDU_Cap_Min(T, CDU).. sum(Tank, F_Feed(T, Tank, CDU)) =g= CDU_Min(CDU);

* -----------------------------------------------------------------------------
* 6. Model Solution
* -----------------------------------------------------------------------------
Model Refinery_Sched /all/;

* Set solver performance limits
Refinery_Sched.iterlim = 50000;
Refinery_Sched.reslim = 1000;

* Define Nonlinear solver
Option NLP = CONOPT;

Solve Refinery_Sched using NLP maximizing Profit;

* -----------------------------------------------------------------------------
* 7. Results Reporting
* -----------------------------------------------------------------------------
Parameter Report_Tank_Vol(T, Tank);
Report_Tank_Vol(T, Tank) = Vol.l(T, Tank);
Display Report_Tank_Vol;

Parameter Report_Tank_Sulfur(T, Tank);
Report_Tank_Sulfur(T, Tank) = Q_Tank.l(T, Tank, 'Sulfur');
Display Report_Tank_Sulfur;

Parameter Report_CDU_Feed(T, CDU, Tank);
Report_CDU_Feed(T, CDU, Tank) = F_Feed.l(T, Tank, CDU);
Display Report_CDU_Feed;