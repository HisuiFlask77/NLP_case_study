import pyomo.environ as pyo
from pyomo.dae import ContinuousSet, DerivativeVar
import matplotlib.pyplot as plt
import numpy as np


def create_collision_model():
    m = pyo.ConcreteModel()

    # Simulation time from 0 to 2 seconds
    m.t = ContinuousSet(bounds=(0, 2))
    m.mass = 1.0  # Mass of the ball
    m.radius = 0.1  # Radius of the ball
    m.k_contact = 200.0  # Contact stiffness coefficient (higher means harder balls and shorter collisions)

    # Identifiers for the three balls
    balls = ['b1', 'b2', 'b3']

    # 3. Define time-varying variables (x: position, v: velocity)
    # --------------------------------------------------
    m.x = pyo.Var(balls, m.t)
    m.v = pyo.Var(balls, m.t)

    # Define derivative variables (dxdt = v, dvdt = a)
    m.dxdt = DerivativeVar(m.x, wrt=m.t)
    m.dvdt = DerivativeVar(m.v, wrt=m.t)

    # 4. Set initial conditions (t=0)
    # --------------------------------------------------
    # Ball 1: Located on the left (-1.0), sprinting to the right (5.0 m/s)
    m.x['b1', 0].fix(-1.0)
    m.v['b1', 0].fix(5.0)

    # Ball 2: Located in the middle (0.0), stationary
    m.x['b2', 0].fix(0.0)
    m.v['b2', 0].fix(0.0)

    # Ball 3: Located on the right (1.0), stationary
    m.x['b3', 0].fix(1.0)
    m.v['b3', 0].fix(0.0)

    # --------------------------------------------------
    # 5. Define dynamics equations (Differential Equation constraints)
    # --------------------------------------------------

    # Helper function: Calculate the contact force between two balls
    # If dist < 2*radius, a collision occurs, generating a repulsive force
    def contact_force(m, t, b_left, b_right):
        dist = m.x[b_right, t] - m.x[b_left, t]
        overlap = 2 * m.radius - dist

        # Use a smooth approximation to simulate max(0, overlap) to avoid discontinuities.
        # This is simplified for conceptual demonstration. If overlap > 0, Force = k * overlap.
        # To make it easier for the solver, pyo.tanh could be used to smooth the onset of contact force.
        # Or simply: force only takes effect when physical distance is within the overlap range.
        # Here we use a simple "soft contact" formula: F = k * max(0, overlap)
        # For solver stability, we construct the expression using Expr_if:
        return pyo.Expr_if(overlap > 0, m.k_contact * overlap, 0)

    # Kinematic constraint: dx/dt = v
    def _ode_pos(m, b, t):
        return m.dxdt[b, t] == m.v[b, t]

    m.ode_pos = pyo.Constraint(balls, m.t, rule=_ode_pos)

    # Dynamic constraint: m * dv/dt = F_total
    def _ode_vel(m, b, t):
        # Calculate net force
        force = 0

        if b == 'b1':
            # Ball 1 can only hit Ball 2 (b1 is left, b2 is right, force acts left)
            force -= contact_force(m, t, 'b1', 'b2')
        elif b == 'b2':
            # Ball 2 hit by Ball 1 (force acts right) + Ball 2 hits Ball 3 (force acts left)
            force += contact_force(m, t, 'b1', 'b2')
            force -= contact_force(m, t, 'b2', 'b3')
        elif b == 'b3':
            # Ball 3 hit by Ball 2 (force acts right)
            force += contact_force(m, t, 'b2', 'b3')

        return m.mass * m.dvdt[b, t] == force

    m.ode_vel = pyo.Constraint(balls, m.t, rule=_ode_vel)

    # --------------------------------------------------
    # 6. Discretization
    # --------------------------------------------------
    # This is the magic of Pyomo.DAE. It automatically converts
    # differential equations into hundreds of algebraic equations.
    # nfe=500 means slicing time into 500 segments. For fast
    # processes like collisions, a fine mesh is required.
    discretizer = pyo.TransformationFactory('dae.collocation')
    discretizer.apply_to(m, nfe=500, ncp=3, scheme='LAGRANGE-RADAU')

    # --------------------------------------------------
    # 7. Solving
    # --------------------------------------------------
    # Since there is no specific objective function (just simulating a physical process), set it to 0
    m.obj = pyo.Objective(expr=0)

    solver = pyo.SolverFactory('ipopt')
    # Increase tolerance because the contact force model is quite "stiff"
    solver.options['tol'] = 1e-6
    solver.options['max_iter'] = 3000
    print("Solving the differential equation system... (may take a few seconds)")
    results = solver.solve(m, tee=True)

    return m


# Run the model
model = create_collision_model()

# --------------------------------------------------
# 8. Visualize results
# --------------------------------------------------
time = [t for t in model.t]
pos_b1 = [pyo.value(model.x['b1', t]) for t in time]
pos_b2 = [pyo.value(model.x['b2', t]) for t in time]
pos_b3 = [pyo.value(model.x['b3', t]) for t in time]

plt.figure(figsize=(10, 6))
plt.plot(time, pos_b1, label='Ball 1 (Left)', linewidth=2)
plt.plot(time, pos_b2, label='Ball 2 (Middle)', linewidth=2)
plt.plot(time, pos_b3, label='Ball 3 (Right)', linewidth=2)

plt.title('Simulation of 3-Ball Collision using Pyomo.DAE')
plt.xlabel('Time (s)')
plt.ylabel('Position (m)')
plt.grid(True)
plt.legend()
plt.show()