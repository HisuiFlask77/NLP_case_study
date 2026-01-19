import casadi as ca
import numpy as np
import matplotlib.pyplot as plt
import time


class VPSA_Simulator:
    def __init__(self, N=20):
        """
        VPSA Simulator Base Class
        """
        self.N = N
        self.P_scale = 1.0e5  # Pressure scaling factor
        self.setup_parameters()
        self.build_model()

    def setup_parameters(self):
        # --- Physical Parameters (Aligned with MATLAB script) ---
        self.L = 1.0
        self.r_in = 0.1445
        self.A = np.pi * self.r_in ** 2
        self.eps = 0.37
        self.eps_p = 0.0      # Aligned with MATLAB: epsilon_p = 0
        self.r_p = 1.0e-3
        self.rho_s = 1130.0

        self.R_gas = 8.314
        self.T_ref = 298.15
        self.Cp_g = 30.7
        self.Cp_s = 1070.0
        self.mu = 1.72e-5

        # Updated Heat of Adsorption to match MATLAB precision
        # MATLAB: dH_b_CO2 = -36165.935, dH_b_N2 = -15800.0
        self.DeltaH = np.array([-36165.935, -15800.0])

        # Dual-site Langmuir (CO2)
        self.q_sb0 = 3.09
        self.b0_0 = 8.65e-7
        self.dU_b0 = -36641.21
        self.q_sd0 = 2.54
        self.d0_0 = 2.63e-8   # Updated from 2.63e-3 to 2.63e-8 to match MATLAB d0_CO2
        self.dU_d0 = -35690.66

        # Dual-site Langmuir (N2)
        self.q_sb1 = 5.84
        self.b0_1 = 2.50e-6
        self.dU_b1 = -1.58e4

        # --- UPDATED KINETICS ---
        # Instead of calculating via Dp/tau, we use the fixed MTC from MATLAB
        # MATLAB: MTC_CO2 = 0.02477876
        self.k_LDF = 0.02477876

        # Darcy Constant (Ergun equation viscous coefficient EA=150)
        self.K_darcy = (self.r_p * 2) ** 2 * self.eps ** 3 / (150 * (1 - self.eps) ** 2 * self.mu)

    def get_isotherm(self, c_total, y_co2, T):
        c0 = c_total * y_co2
        c1 = c_total * (1 - y_co2)

        b0 = self.b0_0 * ca.exp(-self.dU_b0 / (self.R_gas * T))
        d0 = self.d0_0 * ca.exp(-self.dU_d0 / (self.R_gas * T))
        b1 = self.b0_1 * ca.exp(-self.dU_b1 / (self.R_gas * T))

        denom1 = 1 + b0 * c0 + b1 * c1
        denom2 = 1 + d0 * c0

        q0 = self.q_sb0 * b0 * c0 / denom1 + self.q_sd0 * d0 * c0 / denom2
        q1 = self.q_sb1 * b1 * c1 / denom1
        return q0, q1

    def get_isotherm_numeric(self, P, y_co2, T):
        """ Helper for python-side initialization """
        c_total = P / (self.R_gas * T)
        c0 = c_total * y_co2
        c1 = c_total * (1 - y_co2)

        b0 = self.b0_0 * np.exp(-self.dU_b0 / (self.R_gas * T))
        d0 = self.d0_0 * np.exp(-self.dU_d0 / (self.R_gas * T))
        b1 = self.b0_1 * np.exp(-self.dU_b1 / (self.R_gas * T))

        denom1 = 1 + b0 * c0 + b1 * c1
        denom2 = 1 + d0 * c0

        q0 = self.q_sb0 * b0 * c0 / denom1 + self.q_sd0 * d0 * c0 / denom2
        q1 = self.q_sb1 * b1 * c1 / denom1
        return q0, q1

    def build_model(self):
        pass

    def run_step(self, x0, type_id, duration, P_L, P_H):
        pass


class VPSA_Robust(VPSA_Simulator):
    def build_model(self):
        N = self.N
        nx = 5 * N
        x = ca.SX.sym('x', nx)
        y = x[0 * N:1 * N]
        P_bar = x[1 * N:2 * N]
        T = x[2 * N:3 * N]
        q0 = x[3 * N:4 * N]
        q1 = x[4 * N:5 * N]
        P = P_bar * self.P_scale

        u = ca.SX.sym('u', 5)  # [type, duration, dummy, P_L, P_H]
        step_type = u[0]
        duration = u[1]
        P_low = u[3]
        P_high = u[4]

        # Time Scaling
        tau = ca.SX.sym('tau')
        t_phys = tau * duration

        # --- Smooth BC (Continuous derivatives) ---
        lam = 5.0 / (duration + 1e-3)
        P_bound_press = P_high - (P_high - P_low) * ca.exp(-lam * t_phys)
        P_bound_blow = P_low + (P_high - P_low) * ca.exp(-lam * t_phys)
        P_vac = P_low * 0.5
        P_bound_evac = P_vac + (P_low - P_vac) * ca.exp(-lam * t_phys)

        P_bound = ca.if_else(step_type < 0.5, P_bound_press,
                             ca.if_else(step_type < 1.5, P_high,
                                        ca.if_else(step_type < 2.5, P_bound_blow, P_bound_evac)))

        dz = self.L / N
        C_total = P / (self.R_gas * T)

        # --- Smooth Velocity Calculation ---
        v_face = ca.SX.zeros(N + 1)
        v_max = 5.0

        for i in range(1, N):
            grad_P = (P[i] - P[i - 1]) / dz
            v_face[i] = v_max * ca.tanh(-self.K_darcy * grad_P / v_max)

        v_in_raw = -self.K_darcy * (P[0] - P_bound) / (dz / 2)
        v_out_raw = -self.K_darcy * (P_bound - P[N - 1]) / (dz / 2)
        v_in = v_max * ca.tanh(v_in_raw / v_max)
        v_out = v_max * ca.tanh(v_out_raw / v_max)

        v0 = ca.if_else(step_type < 0.5, v_in,
                        ca.if_else(step_type < 1.5, 1.0,
                                   ca.if_else(step_type < 2.5, 0.0, v_in)))
        vN = ca.if_else(step_type < 0.5, 0.0,
                        ca.if_else(step_type < 1.5, v_out,
                                   ca.if_else(step_type < 2.5, v_out, 0.0)))
        v_face[0] = v0
        v_face[N] = vN

        # --- ODE Construction ---
        dy_dt = []
        dP_dt = []
        dT_dt = []
        dq0_dt = []
        dq1_dt = []
        q0_star, q1_star = self.get_isotherm(C_total, y, T)
        rate0 = self.k_LDF * (q0_star - q0)
        rate1 = self.k_LDF * (q1_star - q1)
        S_mass = -(1 - self.eps) / self.eps * (rate0 + rate1)
        Q_gen = -(self.DeltaH[0] * rate0 + self.DeltaH[1] * rate1) * self.rho_s * (1 - self.eps) / self.eps

        v_smooth = 0.1
        for i in range(N):
            vl = v_face[i]
            vr = v_face[i + 1]

            phi_l = 0.5 * (1 + ca.tanh(vl / v_smooth))
            phi_r = 0.5 * (1 + ca.tanh(vr / v_smooth))

            if i == 0:
                yL = phi_l * 0.15 + (1 - phi_l) * y[i]
                TL = phi_l * 298.15 + (1 - phi_l) * T[i]
            else:
                yL = phi_l * y[i - 1] + (1 - phi_l) * y[i]
                TL = phi_l * T[i - 1] + (1 - phi_l) * T[i]

            if i == N - 1:
                yR = phi_r * y[i] + (1 - phi_r) * y[i]
                TR = phi_r * T[i] + (1 - phi_r) * T[i]
            else:
                yR = phi_r * y[i] + (1 - phi_r) * y[i + 1]
                TR = phi_r * T[i] + (1 - phi_r) * T[i + 1]

            rhoL = P[i] / (self.R_gas * TL)
            rhoR = P[i] / (self.R_gas * TR)
            Fin = vl * rhoL
            Fout = vr * rhoR

            div_m = (Fout - Fin) / dz
            div_y = (Fout * yR - Fin * yL) / dz

            Cp_eff = self.eps * C_total[i] * self.Cp_g + (1 - self.eps) * self.rho_s * self.Cp_s
            dT = (-(Fout * self.Cp_g * TR - Fin * self.Cp_g * TL) / dz + Q_gen[i]) / Cp_eff
            dT_dt.append(dT)

            RHS_P = -div_m + S_mass[i]
            dP = self.R_gas * T[i] * RHS_P + (P[i] / T[i]) * dT
            dP_dt.append(dP)

            S_y = -(1 - self.eps) / self.eps * rate0[i]
            dy = (-(div_y - y[i] * div_m) + (S_y - y[i] * S_mass[i])) / C_total[i]
            dy_dt.append(dy)
            dq0_dt.append(rate0[i])
            dq1_dt.append(rate1[i])

        rhs = ca.vertcat(ca.vertcat(*dy_dt), ca.vertcat(*dP_dt) / self.P_scale, ca.vertcat(*dT_dt), ca.vertcat(*dq0_dt),
                         ca.vertcat(*dq1_dt))
        rhs_scaled = rhs * duration

        self.dae = {'x': x, 'p': u, 't': tau, 'ode': rhs_scaled}

        opts = {
            'abstol': 1e-4,
            'reltol': 1e-4,
            'max_num_steps': 20000,
            'nonlin_conv_coeff': 0.1,
            'linear_solver': 'csparse'
        }
        self.integrator = ca.integrator('I', 'cvodes', self.dae, 0.0, 1.0, opts)

    def simulate_step(self, x0, type_id, duration, P_L, P_H):
        p_val = [type_id, duration, 0, P_L, P_H]
        res = self.integrator(x0=x0, p=p_val)
        return res['xf'].full().flatten()

    def simulate_css(self, cycles=10, make_plot=True):
        y_init_val = 0.0
        P_init_val = 1e4
        T_init_val = 298.15

        q0_eq, q1_eq = self.get_isotherm_numeric(P_init_val, y_init_val, T_init_val)

        x = np.zeros(5 * self.N)
        x[0 * self.N:1 * self.N] = y_init_val
        x[1 * self.N:2 * self.N] = P_init_val / self.P_scale
        x[2 * self.N:3 * self.N] = T_init_val
        x[3 * self.N:4 * self.N] = q0_eq
        x[4 * self.N:5 * self.N] = q1_eq

        design = [20.0, 15.0, 30.0, 40.0]
        errors = []

        for i in range(cycles):
            x_start = x.copy()
            x = self.simulate_step(x, 0, design[0], 1e4, 1e5)
            x = self.simulate_step(x, 1, design[1], 1e4, 1e5)
            x = self.simulate_step(x, 2, design[2], 1e4, 1e5)
            x = self.simulate_step(x, 3, design[3], 1e4, 1e5)

            err = np.linalg.norm(x - x_start) / (np.linalg.norm(x_start) + 1e-8)
            errors.append(err)

            if err < 1e-3:
                break

        return errors, x


if __name__ == "__main__":
    N_values = [15, 20, 25, 30, 35, 40]
    results = {}

    print(f"{'N':<5} | {'Cycles':<10} | {'Time (s)':<10} | {'Final Error':<12}")
    print("-" * 45)

    for n_val in N_values:
        start_time = time.time()
        sim = VPSA_Robust(N=n_val)
        errs, final_x = sim.simulate_css(cycles=1000, make_plot=False)
        elapsed = time.time() - start_time
        results[n_val] = {'time': elapsed, 'cycles': len(errs), 'final_error': errs[-1], 'x': final_x}
        print(f"{n_val:<5} | {len(errs):<10} | {elapsed:<10.2f} | {errs[-1]:<12.2e}")

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))

    times = [results[n]['time'] for n in N_values]
    ax1.plot(N_values, times, 'o-', color='crimson')
    ax1.set_xlabel('N (Number of Nodes)')
    ax1.set_ylabel('Calculation Time (s)')
    ax1.set_title('Computational Cost vs Mesh Size')
    ax1.grid(True)

    for n_val in N_values:
        x_res = results[n_val]['x']
        y_profile = x_res[0:n_val]
        z_axis = np.linspace(0, 1, n_val)
        ax2.plot(z_axis, y_profile, '.-', label=f'N={n_val}')

    ax2.set_xlabel('Column Length (z/L)')
    ax2.set_ylabel('Mole Fraction CO2 (y)')
    ax2.set_title('Mesh Convergence: CO2 Profile (Fixed MTC)')
    ax2.legend()
    ax2.grid(True)

    plt.tight_layout()
    plt.show()