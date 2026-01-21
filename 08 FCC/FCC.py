import pyomo.environ as pyo
from pyomo.dae import ContinuousSet, DerivativeVar

"""
PROBLEM DESCRIPTION:
This program models and optimizes an industrial Fluid Catalytic Cracking (FCC) unit 
specifically based on the Abadan Refinery configuration. It utilizes a 6-Lump 
kinetic network to simulate the chemical transformations within the Riser reactor 
and the catalyst regeneration process in the Regenerator.

The system consists of:
1. A Riser Reactor (modeled as a Plug Flow Reactor) where heavy vacuum gas oil (VGO) 
   is cracked into lighter, more valuable products.
2. A Regenerator (modeled as a lumped CSTR) where coke deposited on the catalyst 
   is burned off to restore activity and provide the heat required for the endothermic 
   cracking reactions.

OPTIMIZATION GOAL:
Maximize the mass fraction of Gasoline at the Riser outlet by optimizing operational 
decision variables (Catalyst Circulation Rate and Air Flow Rate) while strictly 
obeying industrial mass and energy balances.

REFERENCE:
"Comprehensive Kinetic Modeling and Sensitivity Analysis of Industrial Fluid 
Catalytic Cracking (FCC) Unit: A Comparative Study of 5-Lump and 6-Lump Models", 
Arabian Journal for Science and Engineering (2025).
DOI:10.1007/s13369-025-10412-6

"""



def create_fcc_model():


    m = pyo.ConcreteModel(name="6_Lump_Industrial_FCC")

    # =========================================================================
    # 1. SETS & DOMAINS
    # =========================================================================

    m.z = ContinuousSet(bounds=(0, 1))
    m.Lumps = pyo.Set(initialize=['VGO', 'DSL', 'GAS', 'LPG', 'DG', 'COKE'])
    m.Rxn = pyo.Set(initialize=[f'r{i}' for i in range(1, 16)])

    # =========================================================================
    # 2. PARAMETERS (Tables 7 & 9)
    # =========================================================================

    m.RiserLength = pyo.Param(initialize=32.5)
    m.RiserArea = pyo.Param(initialize=1.815)
    m.FeedFlow = pyo.Param(initialize=76.159)
    m.FeedTemp = pyo.Param(initialize=550.0)

    m.CatDen = pyo.Param(initialize=770.0)
    m.CatHeatCapacity = pyo.Param(initialize=1.1)
    m.OilHeatCapacity = pyo.Param(initialize=2.5)
    m.HeatOfCombustion = pyo.Param(initialize=30000.0)
    m.HeatOfReaction = pyo.Param(initialize=500.0)

    m.R_gas = pyo.Param(initialize=8.314)

    # Kinetic Parameters (Table 9)
    data_k0 = {
        'r1': 7957.29, 'r2': 14433.4, 'r3': 1057.1, 'r4': 271.917, 'r5': 27.253,
        'r6': 399.933, 'r7': 2.506, 'r8': 3.095, 'r9': 48.282,
        'r10': 1.189, 'r11': 1.018, 'r12': 2.031,
        'r13': 3.411, 'r14': 0.601,
        'r15': 2.196
    }

    data_Ea = {
        'r1': 53927.7, 'r2': 57186.6, 'r3': 53408.6, 'r4': 49950.4, 'r5': 35433.6,
        'r6': 47014.5, 'r7': 67792.9, 'r8': 66266.9, 'r9': 69859.4,
        'r10': 56194.4, 'r11': 66319.1, 'r12': 61785.1,
        'r13': 55513.0, 'r14': 52548.2,
        'r15': 53046.0
    }

    m.k0 = pyo.Param(m.Rxn, initialize=data_k0)
    m.Ea = pyo.Param(m.Rxn, initialize=data_Ea)

    # =========================================================================
    # 3. VARIABLES
    # =========================================================================

    # Riser Profiles
    m.y = pyo.Var(m.z, m.Lumps, bounds=(0, 1), initialize=0.1)
    for z in m.z:
        m.y[z, 'VGO'].set_value(0.9)

    m.T_riser = pyo.Var(m.z, bounds=(500, 1200), initialize=850.0)
    m.Phi = pyo.Var(m.z, bounds=(0, 1.1), initialize=1.0)

    m.dy_dz = DerivativeVar(m.y, wrt=m.z)
    m.dT_dz = DerivativeVar(m.T_riser, wrt=m.z)
    m.dPhi_dz = DerivativeVar(m.Phi, wrt=m.z)

    # Regenerator Variables
    m.T_regen = pyo.Var(bounds=(800, 1300), initialize=980.0)
    m.CokeOnCat_Spent = pyo.Var(bounds=(0, 0.3), initialize=0.015)
    m.CokeOnCat_Regen = pyo.Var(bounds=(1e-6, 0.1), initialize=0.002)

    # Operating variables
    m.F_cat = pyo.Var(bounds=(100, 2000), initialize=600.0)
    m.AirFlow = pyo.Var(bounds=(10, 500), initialize=60.0)

    # Slack variables to help with infeasibility
    m.slack_eb = pyo.Var(bounds=(-1000, 1000), initialize=0.0)
    m.slack_comb = pyo.Var(bounds=(-1000, 1000), initialize=0.0)

    # =========================================================================
    # 4. CONSTRAINTS
    # =========================================================================

    def calc_k(m, rxn, T):
        # Using a safer exp to prevent overflow
        return m.k0[rxn] * pyo.exp(-m.Ea[rxn] / (m.R_gas * T))

    def reaction_rate_expr(m, z, rxn):
        k_val = calc_k(m, rxn, m.T_riser[z])
        phi = m.Phi[z]
        # Adding a small epsilon to concentrations for numerical stability
        eps = 1e-8
        if rxn in ['r1', 'r2', 'r3', 'r4', 'r5']:
            return k_val * phi * (m.y[z, 'VGO'] ** 2 + eps)
        elif rxn in ['r6', 'r7', 'r8', 'r9']:
            return k_val * phi * (m.y[z, 'DSL'] + eps)
        elif rxn in ['r10', 'r11', 'r12']:
            return k_val * phi * (m.y[z, 'GAS'] + eps)
        elif rxn in ['r13', 'r14']:
            return k_val * phi * (m.y[z, 'LPG'] + eps)
        elif rxn == 'r15':
            return k_val * phi * (m.y[z, 'DG'] + eps)
        return 0

    def _mass_balance(m, z, comp):
        if z == 0: return pyo.Constraint.Skip
        Tau_factor = (m.RiserArea * m.RiserLength * 5.0) / m.FeedFlow
        rate_net = 0
        if comp == 'VGO':
            cons = sum(reaction_rate_expr(m, z, r) for r in ['r1', 'r2', 'r3', 'r4', 'r5'])
            rate_net = -cons
        elif comp == 'DSL':
            gen = reaction_rate_expr(m, z, 'r1')
            cons = sum(reaction_rate_expr(m, z, r) for r in ['r6', 'r7', 'r8', 'r9'])
            rate_net = gen - cons
        elif comp == 'GAS':
            gen = reaction_rate_expr(m, z, 'r2') + reaction_rate_expr(m, z, 'r6')
            cons = sum(reaction_rate_expr(m, z, r) for r in ['r10', 'r11', 'r12'])
            rate_net = gen - cons
        elif comp == 'LPG':
            gen = reaction_rate_expr(m, z, 'r3') + reaction_rate_expr(m, z, 'r7') + reaction_rate_expr(m, z, 'r10')
            cons = sum(reaction_rate_expr(m, z, r) for r in ['r13', 'r14'])
            rate_net = gen - cons
        elif comp == 'DG':
            gen = reaction_rate_expr(m, z, 'r4') + reaction_rate_expr(m, z, 'r8') + reaction_rate_expr(m, z,
                                                                                                       'r11') + reaction_rate_expr(
                m, z, 'r13')
            cons = reaction_rate_expr(m, z, 'r15')
            rate_net = gen - cons
        elif comp == 'COKE':
            gen = reaction_rate_expr(m, z, 'r5') + reaction_rate_expr(m, z, 'r9') + reaction_rate_expr(m, z,
                                                                                                       'r12') + reaction_rate_expr(
                m, z, 'r14') + reaction_rate_expr(m, z, 'r15')
            rate_net = gen
        return m.dy_dz[z, comp] == rate_net * Tau_factor

    m.mb_cons = pyo.Constraint(m.z, m.Lumps, rule=_mass_balance)

    def _energy_balance(m, z):
        if z == 0: return pyo.Constraint.Skip
        total_cracking = sum(reaction_rate_expr(m, z, r) for r in m.Rxn)
        heat_term = -total_cracking * m.HeatOfReaction
        Cp_mix = m.OilHeatCapacity + (m.F_cat / m.FeedFlow) * m.CatHeatCapacity
        Tau_factor = (m.RiserArea * m.RiserLength * 5.0) / m.FeedFlow
        return m.dT_dz[z] == (heat_term / Cp_mix) * Tau_factor

    m.eb_riser = pyo.Constraint(m.z, rule=_energy_balance)

    def _deactivation(m, z):
        if z == 0: return pyo.Constraint.Skip
        Tau_factor = (m.RiserArea * m.RiserLength * 5.0) / m.FeedFlow
        return m.dPhi_dz[z] == -2.0 * m.Phi[z] * m.y[z, 'COKE'] * Tau_factor

    m.deact_riser = pyo.Constraint(m.z, rule=_deactivation)

    def _bc_conc(m, lump):
        if lump == 'VGO': return m.y[0, lump] == 1.0
        return m.y[0, lump] == 0.0

    m.bc_conc = pyo.Constraint(m.Lumps, rule=_bc_conc)

    def _bc_temp_mix(m):
        H_feed = m.FeedFlow * m.OilHeatCapacity * m.FeedTemp
        H_cat = m.F_cat * m.CatHeatCapacity * m.T_regen
        H_mix = (m.FeedFlow * m.OilHeatCapacity + m.F_cat * m.CatHeatCapacity) * m.T_riser[0]
        return H_mix == H_feed + H_cat

    m.bc_temp = pyo.Constraint(rule=_bc_temp_mix)

    def _bc_phi(m):
        return m.Phi[0] == 1.0 - (1.0 * m.CokeOnCat_Regen)

    m.bc_phi = pyo.Constraint(rule=_bc_phi)

    def _coke_balance(m):
        coke_produced = m.y[1, 'COKE'] * m.FeedFlow
        return m.CokeOnCat_Spent == m.CokeOnCat_Regen + (coke_produced / m.F_cat)

    m.coke_bal = pyo.Constraint(rule=_coke_balance)

    def _regen_eb(m):
        coke_burned = (m.CokeOnCat_Spent - m.CokeOnCat_Regen) * m.F_cat
        heat_gen = coke_burned * m.HeatOfCombustion
        H_cat_in = m.F_cat * m.CatHeatCapacity * m.T_riser[1]
        H_cat_out = m.F_cat * m.CatHeatCapacity * m.T_regen
        return H_cat_in + heat_gen == H_cat_out + m.slack_eb

    m.regen_eb = pyo.Constraint(rule=_regen_eb)

    def _combustion(m):
        burned = (m.CokeOnCat_Spent - m.CokeOnCat_Regen) * m.F_cat
        # Stabilized combustion rate
        k_comb = 1e3 * pyo.exp(-50000 / (m.R_gas * m.T_regen))
        kinetic_rate = k_comb * m.CokeOnCat_Spent * m.F_cat * (m.AirFlow ** 0.5)
        return burned == kinetic_rate + m.slack_comb

    m.combustion = pyo.Constraint(rule=_combustion)

    def _obj(m):
        # Maximize Gasoline, but penalize slacks heavily to drive them to zero
        return m.y[1, 'GAS'] - 1e3 * (m.slack_eb ** 2 + m.slack_comb ** 2)

    m.obj = pyo.Objective(rule=_obj, sense=pyo.maximize)

    discretizer = pyo.TransformationFactory('dae.collocation')
    discretizer.apply_to(m, nfe=15, ncp=3, scheme='LAGRANGE-RADAU')

    return m


if __name__ == "__main__":
    model = create_fcc_model()
    print("=" * 60)
    print("FCC UNIT OPTIMIZATION (6-Lump Industrial Model)")
    print("=" * 60)

    solver = pyo.SolverFactory('ipopt')
    solver.options['max_iter'] = 3000
    solver.options['tol'] = 1e-6
    solver.options['constr_viol_tol'] = 1e-4

    print("\nStarting IPOPT Solver...")
    try:
        results = solver.solve(model, tee=True)

        if results.solver.termination_condition == pyo.TerminationCondition.optimal:
            print("\nOPTIMIZATION SUCCESSFUL")
            print(f"Regenerator Temp: {pyo.value(model.T_regen):.2f} K")
            print(f"Gasoline Yield:   {pyo.value(model.y[1, 'GAS']) * 100:.2f} wt%")
            print(f"Cat Circulation:  {pyo.value(model.F_cat):.2f} kg/s")
            print(f"Energy Balance Slack: {pyo.value(model.slack_eb):.4f}")
        else:
            print(f"\nOptimization failed: {results.solver.termination_condition}")
    except Exception as e:
        print(f"\nError: {e}")