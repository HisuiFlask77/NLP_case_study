import pyomo.environ as aml
from pyomo.opt import SolverFactory

"""
Problem Description:
This model addresses the Multi-period Gasoline Blending and Pooling Problem, a classic
NLP in refinery operations.

Key Features:
1. Pooling: Feedstock components with known qualities (RON, Sulfur) are mixed into
   intermediate storage tanks (Pools). The resulting qualities of these pools are
   initially unknown and depend on the blend ratio.
2. Bilinearity: The quality balance and product specification constraints involve
   bilinear terms (Product of flow rate and pool quality), making the problem
   non-convex and challenging for solvers.
3. Multi-period: The model optimizes blending decisions across several time periods
   to maximize total profit while meeting product specifications for different
   grades of gasoline (Premium and Regular).

Objective:
Maximize total profit (Product Revenue minus Feedstock Cost) across all periods.
"""

def create_pooling_model():
    model = aml.ConcreteModel(name="Gasoline_Pooling_NLP")

    # --- Set Definitions ---
    model.I = aml.Set(initialize=['Alkylate', 'Reformate', 'FCC_Naphtha'])  # Feed components
    model.P = aml.Set(initialize=['Pool_1', 'Pool_2'])  # Intermediate Pools
    model.J = aml.Set(initialize=['Premium', 'Regular'])  # Final Products
    model.T = aml.Set(initialize=[1, 2, 3])  # Time Periods
    model.Q = aml.Set(initialize=['RON', 'Sulfur'])  # Quality Attributes

    # --- Data/Parameters ---
    # Qualities of input components
    input_quality = {
        ('Alkylate', 'RON'): 98, ('Alkylate', 'Sulfur'): 5,
        ('Reformate', 'RON'): 102, ('Reformate', 'Sulfur'): 10,
        ('FCC_Naphtha', 'RON'): 92, ('FCC_Naphtha', 'Sulfur'): 50
    }

    # Minimum specification requirements (e.g., Octane)
    spec_min = {('Premium', 'RON'): 95, ('Regular', 'RON'): 91}
    # Maximum specification limits (e.g., Contaminants)
    spec_max = {('Premium', 'Sulfur'): 15, ('Regular', 'Sulfur'): 30}

    # Costs and Prices ($/bbl)
    cost_i = {'Alkylate': 90, 'Reformate': 85, 'FCC_Naphtha': 70}
    price_j = {'Premium': 120, 'Regular': 105}

    # --- Variable Definitions ---
    # Flow from Input component i to Pool p in period t
    model.f_ip = aml.Var(model.I, model.P, model.T, domain=aml.NonNegativeReals)
    # Flow from Pool p to Product j in period t
    model.f_pj = aml.Var(model.P, model.J, model.T, domain=aml.NonNegativeReals)
    # Concentration/Quality of attribute q in Pool p in period t (State variables)
    model.q_p = aml.Var(model.P, model.Q, model.T, domain=aml.NonNegativeReals)

    # --- Constraint Definitions ---

    # 1. Pool Volumetric Flow Balance
    # Total flow into the pool must equal total flow out of the pool
    def pool_balance_rule(m, p, t):
        return sum(m.f_ip[i, p, t] for i in m.I) == sum(m.f_pj[p, j, t] for j in m.J)

    model.pool_bal = aml.Constraint(model.P, model.T, rule=pool_balance_rule)

    # 2. Pool Mass/Quality Balance (The core of the Pooling Problem)
    # Sum(Inflow * InputQuality) = Outflow * PoolQuality
    # This creates a bilinear term: q_p[p,q,t] * sum(f_ip)
    def pool_quality_rule(m, p, q, t):
        total_in_flow = sum(m.f_ip[i, p, t] for i in m.I)
        total_mass_in = sum(m.f_ip[i, p, t] * input_quality[i, q] for i in m.I)
        return total_mass_in == m.q_p[p, q, t] * total_in_flow

    model.pool_qual = aml.Constraint(model.P, model.Q, model.T, rule=pool_quality_rule)

    # 3. Product Specification Constraints
    # Lower bound specifications (e.g., RON)
    def product_spec_min_rule(m, j, q, t):
        if (j, q) in spec_min:
            total_mass = sum(m.f_pj[p, j, t] * m.q_p[p, q, t] for p in m.P)
            total_flow = sum(m.f_pj[p, j, t] for p in m.P)
            return total_mass >= spec_min[j, q] * total_flow
        return aml.Constraint.Skip

    model.spec_min_con = aml.Constraint(model.J, model.Q, model.T, rule=product_spec_min_rule)

    # Upper bound specifications (e.g., Sulfur)
    def product_spec_max_rule(m, j, q, t):
        if (j, q) in spec_max:
            total_mass = sum(m.f_pj[p, j, t] * m.q_p[p, q, t] for p in m.P)
            total_flow = sum(m.f_pj[p, j, t] for p in m.P)
            return total_mass <= spec_max[j, q] * total_flow
        return aml.Constraint.Skip

    model.spec_max_con = aml.Constraint(model.J, model.Q, model.T, rule=product_spec_max_rule)

    # --- Objective Function: Profit Maximization ---
    def obj_rule(m):
        revenue = sum(m.f_pj[p, j, t] * price_j[j] for p in m.P for j in m.J for t in m.T)
        cost = sum(m.f_ip[i, p, t] * cost_i[i] for i in m.I for p in m.P for t in m.T)
        return revenue - cost

    model.obj = aml.Objective(rule=obj_rule, sense=aml.maximize)

    return model


if __name__ == "__main__":
    model = create_pooling_model()

    # NLP problems are highly sensitive to initial values.
    # Providing a reasonable starting guess for pool qualities helps convergence.
    for p in model.P:
        for q in model.Q:
            for t in model.T:
                # Guess RON around 95 and Sulfur around 20
                model.q_p[p, q, t].value = 95 if q == 'RON' else 20

    # Using IPOPT solver
    solver = SolverFactory('ipopt')
    results = solver.solve(model, tee=True)

    # --- Reporting Results ---
    print("\n--- Blending Optimization Results ---")
    for t in model.T:
        print(f"Period {t}:")
        for j in model.J:
            total_vol = sum(aml.value(model.f_pj[p, j, t]) for p in model.P)
            if total_vol > 0.1:
                print(f"  Product {j}: {total_vol:.1f} bbl produced")

    print(f"\nTotal Optimized Profit: ${aml.value(model.obj):.2f}")