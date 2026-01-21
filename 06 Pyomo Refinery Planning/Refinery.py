import pyomo.environ as aml
from pyomo.opt import SolverFactory

"""
Problem Description:
This model represents a NLP approach to refinery production planning.
The objective is to maximize daily profit by optimizing the selection of crude oil types,
unit throughputs, and critical operating parameters—specifically the Crude Distillation Unit (CDU)
operating temperature.

Key Nonlinear Features:
1. Nonlinear Yields: Gasoline output is modeled as a quadratic function of the CDU
   operating temperature and a linear function of the weighted average API gravity
   of the crude feedstock.
2. Variable Operating Costs: Energy consumption and operating costs are modeled as
   increasing functions of the operating temperature.

The model accounts for crude purchasing costs, unit processing capacities,
material balances, and product sales revenue.
"""




def create_refinery_model():
    model = aml.ConcreteModel(name="Refinery_Production_Planning")

    # --- Set Definitions ---
    model.CRUDES = aml.Set(initialize=['Light_Crude', 'Heavy_Crude'])
    model.PRODUCTS = aml.Set(initialize=['Gasoline', 'Diesel', 'JetFuel', 'FuelOil'])
    model.UNITS = aml.Set(initialize=['CDU', 'FCC'])

    # --- Parameter Definitions ---
    # Crude oil prices ($/bbl)
    crude_price = {'Light_Crude': 75.0, 'Heavy_Crude': 60.0}

    # Product sales prices ($/bbl)
    prod_price = {'Gasoline': 110.0, 'Diesel': 95.0, 'JetFuel': 105.0, 'FuelOil': 50.0}

    # Crude properties (API gravity)
    crude_api = {'Light_Crude': 35.0, 'Heavy_Crude': 22.0}

    # Unit processing capacities (bbl/day)
    capacity = {'CDU': 100000, 'FCC': 40000}

    # --- Variable Definitions ---
    # Feed rate for each crude type
    model.feed = aml.Var(model.CRUDES, domain=aml.NonNegativeReals, bounds=(0, 80000))

    # Total throughput for processing units
    model.unit_throughput = aml.Var(model.UNITS, domain=aml.NonNegativeReals)

    # Output quantity for each product
    model.prod_out = aml.Var(model.PRODUCTS, domain=aml.NonNegativeReals)

    # Nonlinear operating variable: Average CDU operating temperature (influences yield)
    model.cdu_temp = aml.Var(domain=aml.NonNegativeReals, bounds=(300, 450))

    # --- Constraint Definitions ---

    # 1. CDU Feed Balance
    def cdu_feed_rule(m):
        return m.unit_throughput['CDU'] == sum(m.feed[c] for c in m.CRUDES)

    model.cdu_feed_con = aml.Constraint(rule=cdu_feed_rule)

    # 2. Nonlinear Yield Equations (NLP Core)
    # Assumption: Gasoline yield is a quadratic function of temperature and influenced by feedstock API
    # Yield_Factor = a * Temp^2 + b * Temp + c * API + d
    def gasoline_yield_rule(m):
        # Calculate weighted average API of the current crude mix
        avg_api = sum(m.feed[c] * crude_api[c] for c in m.CRUDES) / (m.unit_throughput['CDU'] + 1e-6)

        # Nonlinear relationship: temperature squared and the product of API/Temp with throughput
        return m.prod_out['Gasoline'] == m.unit_throughput['CDU'] * (
                -0.000005 * m.cdu_temp ** 2 + 0.004 * m.cdu_temp + 0.005 * avg_api - 0.5
        )

    model.gasoline_yield_con = aml.Constraint(rule=gasoline_yield_rule)

    # Simplified linear yields for other refinery products
    model.diesel_yield_con = aml.Constraint(expr=model.prod_out['Diesel'] == 0.35 * model.unit_throughput['CDU'])
    model.jet_yield_con = aml.Constraint(expr=model.prod_out['JetFuel'] == 0.15 * model.unit_throughput['CDU'])
    model.fuel_oil_con = aml.Constraint(expr=model.prod_out['FuelOil'] == 0.10 * model.unit_throughput['CDU'])

    # 3. Capacity Constraints
    def cap_rule(m, u):
        return m.unit_throughput[u] <= capacity[u]

    model.cap_con = aml.Constraint(model.UNITS, rule=cap_rule)

    # --- Objective Function: Profit Maximization ---
    def obj_rule(m):
        # Total Revenue from product sales
        revenue = sum(m.prod_out[p] * prod_price[p] for p in m.PRODUCTS)

        # Total Cost of crude purchase
        cost = sum(m.feed[c] * crude_price[c] for c in m.CRUDES)

        # Nonlinear Operating Cost: Costs increase as temperature rises due to utility consumption
        op_cost = m.unit_throughput['CDU'] * 2.0 + (m.cdu_temp - 300) * 0.05

        return revenue - cost - op_cost

    model.obj = aml.Objective(rule=obj_rule, sense=aml.maximize)

    return model


if __name__ == "__main__":
    model = create_refinery_model()
    solver = SolverFactory('ipopt')
    results = solver.solve(model, tee=True)

    # --- Optimization Results ---
    print("\n--- Optimization Results ---")
    for c in model.CRUDES:
        print(f"Crude Feed {c}: {aml.value(model.feed[c]):.2f} bbl/day")

    print(f"CDU Operating Temperature: {aml.value(model.cdu_temp):.2f} F")

    for p in model.PRODUCTS:
        print(f"Product Output {p}: {aml.value(model.prod_out[p]):.2f} bbl/day")

    print(f"Total Daily Profit: ${aml.value(model.obj):.2f}")