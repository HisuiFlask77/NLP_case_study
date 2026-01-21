$TITLE FCC Unit Optimization (6-Lump Model)

* PROBLEM DESCRIPTION:
* This GAMS model optimizes an industrial Fluid Catalytic Cracking unit 
* based on the Abadan Refinery configuration. It uses a 6-Lump kinetic network 
* (VGO, Diesel, Gasoline, LPG, Dry Gas, Coke). The riser is discretized using 
* a Finite Difference scheme to solve for spatial profiles of mass fractions,
* temperature, and catalyst activity.
*
* OBJECTIVE FUNCTION:
* The primary objective is to maximize the Gasoline Yield at the riser outlet
* while satisfying rigorous mass and energy balances across the reactor-regenerator
* loop.
*
* REFERENCE:
* Khaksar, S.A.N., Esmaeilzadeh, F., Farsi, M., et al. (2025). "Comprehensive 
* Kinetic Modeling and Sensitivity Analysis of Industrial Fluid Catalytic Cracking
* Unit: A Comparative Study of 5-Lump and 6-Lump Models." Arabian Journal for Science and Engineering, 50, 20943–20966. 
* https://doi.org/10.1007/s13369-025-10412-6


SETS
    lump    /VGO, DSL, GAS, LPG, DG, COKE/
    rxn     /r1*r15/
    z       /z0*z30/ ;

* Subsets for reaction groupings to handle kinetic orders
SETS
    rxn_vgo(rxn) /r1, r2, r3, r4, r5/
    rxn_dsl(rxn) /r6, r7, r8, r9/
    rxn_gas(rxn) /r10, r11, r12/
    rxn_lpg(rxn) /r13, r14/
    rxn_dg(rxn)  /r15/ ;

* Define boundary subsets for controlled set access
SETS
    z_start(z)
    z_end(z)   ;

z_start(z) = yes$(ord(z) = 1);
z_end(z)   = yes$(ord(z) = card(z));

SCALARS
    RiserLength     /32.5/
    RiserArea       /1.815/
    FeedFlow        /76.159/
    FeedTemp        /550.0/
    CatCp           /1.1/
    OilCp           /2.5/
    HeatComb        /30000.0/
    HeatRxn         /500.0/
    R_gas           /8.314/
    dz              ;

dz = 1.0 / (card(z) - 1);

* --- Kinetic Parameters Consolidated ---
PARAMETERS
    k0(rxn) / r1 7957.29, r2 14433.4, r3 1057.1, r4 271.917, r5 27.253, r6 399.933, r7 2.506, r8 3.095, r9 48.282, r10 1.189, r11 1.018, r12 2.031, r13 3.411, r14 0.601, r15 2.196 /
    Ea(rxn) / r1 53927.7, r2 57186.6, r3 53408.6, r4 49950.4, r5 35433.6, r6 47014.5, r7 67792.9, r8 66266.9, r9 69859.4, r10 56194.4, r11 66319.1, r12 61785.1, r13 55513.0, r14 52548.2, r15 53046.0 / ;

* Stoichiometric Matrix nu(rxn, lump)
PARAMETER nu(rxn, lump);
nu(rxn, lump) = 0;
nu('r1','VGO') = -1; nu('r1','DSL')  = 1;
nu('r2','VGO') = -1; nu('r2','GAS')  = 1;
nu('r3','VGO') = -1; nu('r3','LPG')  = 1;
nu('r4','VGO') = -1; nu('r4','DG')   = 1;
nu('r5','VGO') = -1; nu('r5','COKE') = 1;
nu('r6','DSL') = -1; nu('r6','GAS')  = 1;
nu('r7','DSL') = -1; nu('r7','LPG')  = 1;
nu('r8','DSL') = -1; nu('r8','DG')   = 1;
nu('r9','DSL') = -1; nu('r9','COKE') = 1;
nu('r10','GAS') = -1; nu('r10','LPG') = 1;
nu('r11','GAS') = -1; nu('r11','DG')  = 1;
nu('r12','GAS') = -1; nu('r12','COKE') = 1;
nu('r13','LPG') = -1; nu('r13','DG')   = 1;
nu('r14','LPG') = -1; nu('r14','COKE') = 1;
nu('r15','DG')  = -1; nu('r15','COKE') = 1;

VARIABLES
    y(z, lump)      Mass fraction
    T_riser(z)      Temperature (K)
    Phi(z)          Activity
    T_regen         Regen Temp (K)
    Coke_Spent      Spent Coke
    Coke_Regen      Regen Coke
    F_cat           Cat Flow (kg per s)
    AirFlow         Air Flow (kg per s)
    slack_eb        Penalty Slack Energy
    slack_comb      Penalty Slack Kinetics
    obj             Objective ;

* --- Bounds and Initialization ---
y.lo(z, lump) = 0.0; y.up(z, lump) = 1.0; y.l(z, 'VGO') = 0.9;
T_riser.lo(z) = 500.0; T_riser.up(z) = 1200.0; T_riser.l(z) = 850.0;
Phi.lo(z) = 0.0; Phi.up(z) = 1.1; Phi.l(z) = 1.0;
T_regen.lo = 800.0; T_regen.up = 1300.0; T_regen.l = 1000.0;
F_cat.lo = 100.0; F_cat.up = 2000.0; F_cat.l = 600.0;
AirFlow.lo = 10.0; AirFlow.up = 500.0; AirFlow.l = 60.0;
Coke_Spent.lo = 0.0; Coke_Spent.up = 0.3; Coke_Regen.lo = 1e-6; Coke_Regen.up = 0.1;

EQUATIONS
    obj_eqn, bc_vgo(z), bc_others(z, lump), bc_temp, bc_phi, 
    mass_bal(z, lump), energy_bal(z), deact_bal(z),
    coke_bal_eq, regen_eb_eq, combustion_eq ;

* --- Riser Model (Backward Euler) ---
mass_bal(z, lump)$(ord(z) > 1)..
    y(z, lump) =e= y(z-1, lump) + dz * (RiserArea * RiserLength * 5.0 / FeedFlow) * (
        sum(rxn_vgo, nu(rxn_vgo, lump) * k0(rxn_vgo) * exp(-Ea(rxn_vgo)/(R_gas * T_riser(z))) * Phi(z) * sqr(y(z, 'VGO')))
      + sum(rxn_dsl, nu(rxn_dsl, lump) * k0(rxn_dsl) * exp(-Ea(rxn_dsl)/(R_gas * T_riser(z))) * Phi(z) * y(z, 'DSL'))
      + sum(rxn_gas, nu(rxn_gas, lump) * k0(rxn_gas) * exp(-Ea(rxn_gas)/(R_gas * T_riser(z))) * Phi(z) * y(z, 'GAS'))
      + sum(rxn_lpg, nu(rxn_lpg, lump) * k0(rxn_lpg) * exp(-Ea(rxn_lpg)/(R_gas * T_riser(z))) * Phi(z) * y(z, 'LPG'))
      + sum(rxn_dg,  nu(rxn_dg,  lump) * k0(rxn_dg)  * exp(-Ea(rxn_dg) /(R_gas * T_riser(z))) * Phi(z) * y(z, 'DG'))
    );

energy_bal(z)$(ord(z) > 1)..
    T_riser(z) =e= T_riser(z-1) + dz * (RiserArea * RiserLength * 5.0 / FeedFlow) * (
        -HeatRxn * (
          sum(rxn_vgo, k0(rxn_vgo) * exp(-Ea(rxn_vgo)/(R_gas * T_riser(z))) * Phi(z) * sqr(y(z, 'VGO')))
        + sum(rxn_dsl, k0(rxn_dsl) * exp(-Ea(rxn_dsl)/(R_gas * T_riser(z))) * Phi(z) * y(z, 'DSL'))
        + sum(rxn_gas, k0(rxn_gas) * exp(-Ea(rxn_gas)/(R_gas * T_riser(z))) * Phi(z) * y(z, 'GAS'))
        + sum(rxn_lpg, k0(rxn_lpg) * exp(-Ea(rxn_lpg)/(R_gas * T_riser(z))) * Phi(z) * y(z, 'LPG'))
        + sum(rxn_dg,  k0(rxn_dg)  * exp(-Ea(rxn_dg) /(R_gas * T_riser(z))) * Phi(z) * y(z, 'DG'))
        )
    ) / (OilCp + (F_cat/FeedFlow)*CatCp);

deact_bal(z)$(ord(z) > 1)..
    Phi(z) =e= Phi(z-1) + dz * (RiserArea * RiserLength * 5.0 / FeedFlow) * (-2.0 * Phi(z) * y(z, 'COKE'));

* --- Controlled Set Boundary Conditions ---
bc_vgo(z)$z_start(z).. y(z, 'VGO') =e= 1.0;
bc_others(z, lump)$(z_start(z) and not sameas(lump, 'VGO')).. y(z, lump) =e= 0.0;
bc_temp.. (FeedFlow * OilCp + F_cat * CatCp) * sum(z_start(z), T_riser(z)) =e= (FeedFlow * OilCp * FeedTemp) + (F_cat * CatCp * T_regen);
bc_phi.. sum(z_start(z), Phi(z)) =e= 1.0 - (1.0 * Coke_Regen);

* --- Regenerator (Controlled Indexing) ---
coke_bal_eq.. Coke_Spent =e= Coke_Regen + (sum(z_end(z), y(z, 'COKE')) * FeedFlow / F_cat);
regen_eb_eq.. F_cat * CatCp * sum(z_end(z), T_riser(z)) + (Coke_Spent - Coke_Regen) * F_cat * HeatComb =e= F_cat * CatCp * T_regen + slack_eb;
combustion_eq.. (Coke_Spent - Coke_Regen) * F_cat =e= 1e3 * exp(-50000 / (R_gas * T_regen)) * Coke_Spent * F_cat * sqrt(AirFlow) + slack_comb;
obj_eqn.. obj =e= sum(z_end(z), y(z, 'GAS')) - 1000 * (sqr(slack_eb) + sqr(slack_comb));

MODEL FCC_MOD /ALL/;
OPTION NLP = CONOPT;
SOLVE FCC_MOD MAXIMIZING obj USING NLP;
DISPLAY y.l, T_riser.l, T_regen.l, F_cat.l, AirFlow.l;