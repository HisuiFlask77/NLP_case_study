# Nonlinear Problem Implementations: Case Studies

This repository features a diverse collection of Nonlinear Programming (NLP) problem instances derived from complex industrial and physical engineering scenarios. The models are implemented using state-of-the-art optimization frameworks, including GAMS, Pyomo, and CasADi.

## Table of Contents
* [Case 1: Refinery Hydrogen Network Optimization](#case-1-refinery-hydrogen-network-optimization)
* [Case 2: Multi-Period Refinery Crude Oil Scheduling Optimization](#case-2-multi-period-refinery-crude-oil-scheduling-optimization)
* [Case 3: Steady-State Two-Column Crude Distillation and Product Blending Optimization](#case-3-steady-state-two-column-crude-distillation-and-product-blending-optimization)
* [Case 4: 4-Step PSA Carbon Capture Optimization](#case-4-4-step-psa-carbon-capture-optimization)
* [Case 5: Newton's Cradle Dynamic Simulation](#case-5-newtons-cradle-dynamic-simulation)
* [Case 6: Refinery Production Planning](#case-6-refinery-production-planning)
* [Case 7: Gasoline Blending and Pooling](#case-7-gasoline-blending-and-pooling)
* [Case 8: Industrial FCC Unit Optimization (6-Lump Kinetic Model)](#case-8-industrial-fcc-unit-optimization-6-lump-kinetic-model)

---

## Case 1: Refinery Hydrogen Network Optimization


### 1. Problem Description
This case addresses the Hydrogen Management Problem in a petroleum refinery, focusing on the efficient allocation of hydrogen resources to maximize profitability and operational efficiency. The refinery hydrogen network is modeled as a Superstructure that interconnects multiple functional entities:
* **Hydrogen Sources:** These include high-purity, high-cost external or fresh sources like the Steam Methane Reformer, and internal by-product sources such as Continuous Catalytic Reformers (CCR1, CCR2).
* **Hydrogen Sinks:** Processing units such as the Hydrocracker (HCU), Diesel Hydrotreater (DHT), Naphtha Hydrotreater (NHT), and Gasoline Hydrotreater (GHT). These units require specific hydrogen volumes and must maintain a minimum inlet purity threshold to protect catalyst activity and ensure proper partial pressures.
* **Purification Units:** A Pressure Swing Adsorption (PSA) unit acts as a source-sink intermediary. It captures low-purity "off-gas" from unit outlets and upgrades it to high-purity hydrogen at a 90% recovery rate.
* **Reuse and Recycle:** The superstructure allows for direct recycling of off-gas from high-purity/high-pressure sinks to lower-requirement units. Any excess gas is sent to the refinery's fuel gas system as waste.
  
The core mathematical complexity of this system is its classification as a Nonlinear Programming (NLP) model. This arises from the mixing of various streams with different concentrations, which generates bilinear terms ($\text{Flow Rate} \times \text{Purity}$) in the component mass balances. This nonlinearity creates a non-convex optimization space where multiple local optima may exist.

### 2. Optimization Goals
* **Minimize the TAC:** The objective function focuses on reducing the expenses associated with purchasing or producing high-purity fresh hydrogen.
* **Maximize Hydrogen Reuse:** Strategically recycle "off-gas" from high-purity sinks to lower-requirement units or purification units to minimize waste.

### 3. Key Constraints
* **Sink Inlet Flow Balance:** The model enforces a bulk volume balance for each tank.
* **Bilinear Component Balance:** Property mass balances ensure the sulfur and gravity levels in tanks reflect physical blending.
* **Purity Hard Constraint:** The actual mixed purity at the inlet of each processing unit must be greater than or equal to its minimum specified threshold to ensure process integrity.
* **PSA Performance Model:** The purified hydrogen output is constrained by a fixed recovery rate, where the pure hydrogen produced is proportional to the total hydrogen entering the unit from all source and sink feeds.
* **Capacity Limits:** The total hydrogen drawn from any production unit (SMR or CCR) for both direct sink supply and PSA feed must not exceed its maximum operating capacity.

---

## Case 2: Multi-Period Refinery Crude Oil Scheduling Optimization


### 1. Problem Description
This case addresses the industrial-scale scheduling of crude oil operations over a 10-day time horizon. The system manages three categories of crude oil—Arabian Light (AL), Arabian Heavy (AH), and Bonny Light (BL)—arriving via vessels on specific scheduled dates. These feedstocks are unloaded into four storage tanks (TK101–TK104) where non-linear blending occurs before being processed by two Crude Distillation Units, CDU_A and CDU_B.

The core mathematical challenge is the Dynamic Tank Quality Balance4. The model tracks critical quality attributes—Sulfur Content and API Gravity—using bilinear terms (Volume $\times$ Quality), creating a non-convex NLP space.

### 2. Optimization Goals
* **Maximize Total Net Profit:** The objective is to maximize profit, calculated as the gross product revenue minus crude procurement costs.
* **Quality-Driven Revenue:** Product value is estimated as a function of the feed quality; the optimizer seeks to maximize the API Gravity premium while minimizing Sulfur penalties.

### 3. Key Constraints
* **Material and Inventory Balances:** The model enforces a bulk volume balance for each tank: $V_{t} = V_{t-1} + \text{In} - \text{Out}$.
* **Nonlinear Quality Mixing:** Property mass balances ensure that the sulfur and gravity levels in the tanks and CDU feeds accurately reflect the physical blending of different crude types.
* **Unloading Allocation:** All scheduled vessel arrivals must be fully unloaded and allocated to available storage tanks.
* **CDU Capacity Limits:** Each distillation unit must operate between its minimum turndown rate and its maximum daily processing capacity.

---

## Case 3: Steady-State Two-Column Crude Distillation and Product Blending Optimization


### 1. Problem Description
This case optimizes the steady-state operational conditions of a refinery’s primary distillation section. Unlike scheduling models, this simulation focuses on fixed processing parameters rather than time-period decisions. The system processes three types of crude oil (Arabian Light, Arabian Heavy, and Bonny Light) which are blended and fed into a two-column sequence:
* **Atmospheric Distillation Unit (ADU):** Separates the crude blend into Naphtha, Kerosene, Diesel, and Atmospheric Residue (AR).
* **Vacuum Distillation Unit (VDU):** Processes the heavy AR from the ADU bottom to further recover Vacuum Gas Oil (VGO) and Vacuum Residue.

To achieve high accuracy, the model discretizes crude oil into eight "narrow cuts" (pseudo-components) based on boiling point ranges. The non-linear core involves E-Cutpoint Correlations, where distillation yields are functions of cut-point temperatures, and Swing Cut decision variables (Split_NK and Split_KD) that determine how intermediate fractions are routed between adjacent product pools.

### 2. Optimization Goals
* **Maximize Total Net Profit:** The objective function seeks to maximize the difference between final product revenue and the combined costs of crude procurement and unit operating expenses.
* **Optimal Fraction Routing:** Determine the optimal split ratios for swing cuts to divert intermediate streams to the most valuable product pools while meeting all quality standards.

### 3. Key Constraints
* **Unit Capacity Limits:** Total crude feed must remain within the ADU capacity (150 kbbl/day), and the heavy fractions sent to the VDU (VGO and Residue) must not exceed its processing limit.
* **Bilinear Blending Equations:** Specific equations govern the routing of narrow cuts. For example, the Gasoline pool must consist of Light Naphtha and the optimized portion of the Naphtha/Kerosene swing cut.
* **Product Quality Specifications:** Final products (Gasoline, Jet Fuel, Diesel, and Fuel Oil) must satisfy strict standards for Maximum Sulfur content and Minimum API Gravity.
* **Bilinear Blending Equations:** Property mass balances ensure the final product quality accurately reflects the weighted average of the blended intermediate streams.


---

## Case 4: 4-Step PSA Carbon Capture Optimization


### 1. Problem Description
This case addresses the optimal design of a four-step Vacuum Pressure Swing Adsorption (PVSA) cycle for carbon capture1111. The process is designed to separate a $CO_2/N_2$ mixture (containing 15% $CO_2$) into a high-purity $CO_2$ product2. The cycle consists of four fundamental steps: feed pressurization, high-pressure adsorption, cocurrent blowdown, and countercurrent evacuation.

The primary technical challenges include:
* **Highly Nonlinear PDAEs**: The system is governed by a set of coupled Partial Differential-Algebraic Equations (PDAEs) describing mass, momentum, and energy balances.
* **Cyclic Steady State (CSS)**: Unlike traditional steady states, CSS requires the final state of an adsorption cycle to exactly match the initial state, necessitating hundreds of simulation cycles for convergence.
* **Rigorous Model Complexity**: Direct optimization of rigorous models is computationally prohibitive due to inherent nonlinearity and stiffness.

### 2. Optimization Goals
* **Minimize Capture Cost:** Minimize the $CO_2$ capture cost (\$/ton $CO_2$) by optimizing step durations and operating pressures ($P_H, P_I, P_L$).

### 3. Key Constraints
* **Product Requirements:** The $CO_2$ product must meet a minimum purity of 95% and a recovery rate of at least 90%.
* **Logical Pressure Ordering**
* **Operational Boundaries** 

**Reference:** Model based on "Hybrid data-driven optimisation approach for pressure swing adsorption," *Separation and Purification Technology* (2026).
DOI: 10.1016/j.seppur.2025.136228.

---

## Case 5: Newton's Cradle Dynamic Simulation


### 1. Problem Description
This case focuses on the dynamic modeling of a multi-body collision system—specifically a Newton's Cradle consisting of three identical balls ('b1', 'b2', 'b3'). Unlike simple kinematic animations, this simulation treats collisions as a "stiff" physical process where the balls undergo microscopic deformation during contact.

The simulation begins with Ball 1 located at $x = -1.0$ moving right at $5.0\text{ m/s}$, while Ball 2 and Ball 3 are stationary at $x = 0.0$ and $x = 1.0$, respectively. The goal is to capture the transfer of momentum through the chain of spheres.

### 2. Physical & Mathematical Model
The system is governed by Newton's Second Law and modeled as a system of DAEs:
* **Kinematics:** The change in position over time is defined by velocity:
  
$$
\frac{dx_i}{dt} = v_i
$$

* **Dynamics:** The acceleration of each ball is determined by the sum of contact forces:

$$
m \frac{dv_i}{dt} = \sum F_{\text{contact}}
$$

* **Contact Force Model:** Collisions are simulated using a high-stiffness spring interaction ($k = 200.0$). A repulsive force is generated only when the distance between two balls is less than the sum of their radii ($2r$):

$$F_{\text{contact}} = \max(0, k \cdot (2r - \text{distance}))$$

---

## Case 6: Refinery Production Planning


### 1. Problem Description
This case is a refinery production planning problem. The model is designed to determine the optimal balance between raw material selection and operational settings to maximize economic returns. It considers two types of feedstock—Light Crude and Heavy Crude—which are processed through a Crude Distillation Unit (CDU) and a FCC unit.

A unique feature of this model is the inclusion of the CDU operating temperature ($T$) as a decision variable. Because the temperature directly influences the chemical yields of high-value products and the consumption of utilities, the model must navigate a non-convex space to find the most profitable operating point.

### 2. Optimization Goals
* **Maximize Daily Profit:** The objective is to maximize the total daily profit ($Z$), calculated as the gross revenue from product sales minus the costs of crude oil and nonlinear operational expenses.

$$
Z = \sum_{p \in \text{Products}} (\text{Output}_p \cdot \text{Price}_p) - \sum_{c \in \text{Crudes}} (\text{Feed}_c \cdot \text{Price}_c) - \text{Cost}_{\text{op}}
$$

*  **Optimize Yield Efficiency:** Balance the CDU temperature to maximize the yield of expensive products like Gasoline, while accounting for the increased utility costs associated with higher temperatures.
* **Material Selection:** Determine the optimal mix of Light and Heavy crudes based on their API gravity and purchase price.

### 3. Key Constraints
* **Nonlinear Gasoline Yield:** The gasoline output is a quadratic function of the CDU temperature and a linear function of the weighted average API gravity of the feed:

$$
\text{Output}_{\text{Gasoline}} = Q_{\text{CDU}} \cdot (-0.000005 \cdot T^2 + 0.004 \cdot T + 0.005 \cdot API_{\text{avg}} - 0.5)
$$

* **Linear Product Yields** Yields for Diesel, Jet Fuel, and Fuel Oil are modeled as fixed percentages (35%, 15%, and 10% respectively) of the total CDU throughput.
* **Operational Cost Function** Costs increase linearly with throughput and rise further as the temperature deviates from the base level of $300\text{ °F}$:

$$
\text{Cost}_{\text{op}} = Q_{\text{CDU}} \cdot 2.0 + (T - 300) \cdot 0.05
$$

* **Capacity and Bounds**


---

## Case 7: Gasoline Blending and Pooling


### 1. Key Technical Challenges
This case addresses a NLP case study: the Multi-period Gasoline Blending and Pooling Problem.

The model represents a three-layer production network:
* **Feedstock Components:** Raw materials (Alkylate, Reformate, and FCC Naphtha) with known qualities, specifically Octane (RON) and Sulfur content. Each component has a specific purchase cost.
* **Intermediate Pools:** Components are first mixed into storage tanks (Pool 1 and Pool 2). The resulting qualities of these pools are initially unknown variables that depend on the specific blend ratio of the inputs.
* **Final Products:** Fluids are drawn from the intermediate pools to produce final gasoline grades: Premium and Regular.

The optimization is conducted over three time periods. The mathematical complexity arises from Bilinearity, where the product of flow rates and unknown pool qualities creates a non-convex optimization space.


### 2. Optimization Goals
* **Maximize Total Profit:** The primary objective is to maximize the total net profit across all periods, calculated as product sales revenue minus feedstock procurement costs.

### 3. Key Constraints
* **Pool Mass Balance:** The sum of the incoming component mass must equal the outgoing mass from the pool.
* **Pool Volumetric Flow Balance:** For each pool and time period, the total volumetric inflow must equal the total volumetric outflow.
* **Product Specification Constraints:** Blended final products must satisfy specific bounds. For Octane (RON), a minimum threshold is enforced and for contaminants like Sulfur, the concentration must remain below a maximum threshold.
 

---

## Case 8: Industrial FCC Unit Optimization (6-Lump Kinetic Model)


### 1. Problem Description
This case models and optimizes an industrial FCC unit based on the Abadan Refinery configuration. The system utilizes a 6-Lump kinetic network (Vacuum Gas Oil, Diesel, Gasoline, LPG, Dry Gas, and Coke) to simulate the complex chemical transformations and heat integration within the refinery's core conversion unit.

The model architecture captures the coupled dynamics of two distinct reactors:
* **Pool Mass Balance:** Modeled as a PFR using DAEs. Heavy VGO is cracked into lighter products through a series of 15 endothermic reactions.
* **Regenerator:** Modeled as a CSTR. This unit burns off coke deposited on the catalyst to restore its activity and provides the thermal energy required for the riser reactions.

The simulation accounts for catalyst deactivation kinetics, where the catalyst activity ($\Phi$) decreases as it travels up the riser due to coke formation.

### 2. Optimization Goals
* **Maximize Gasoline Yield:** The primary objective is to maximize the mass fraction of Gasoline ($y_{\text{GAS}}$) at the riser outlet.
* **System Stability:** The optimizer uses a penalty function to drive energy and combustion balance slacks to zero, ensuring the resulting operating point is physically and industrially feasible.

### 3. Key Constraints
* **Riser Mass and Energy Balances:** A system of DAEs governs the change in mass fractions and temperature ($T_{\text{riser}}$) along the dimensionless height ($z$) of the riser:

$$
\frac{dy_j}{dz} = \text{NetRate}_j \cdot \tau
$$
$$
\frac{dT_{\text{riser}}}{dz} = \frac{\text{HeatOfReaction} \cdot \text{Rate}_{\text{net}}}{C_{p, \text{mix}}} \cdot \tau
$$

* **Catalyst Deactivation Kinetics:** The activity of the catalyst is modeled to decay based on the local coke concentration:

$$
\frac{d\Phi}{dz} = -2.0 \cdot \Phi \cdot y_{\text{coke}} \cdot \tau
$$

* **Regenerator Heat Balance:** The energy generated by burning coke must balance the energy required to heat the circulating catalyst back to the regeneration temperature ($T_{\text{regen}}$):

$$
H_{\text{cat,in}} + H_{\text{gen}} = H_{\text{cat,out}}
$$

* **Kinetic Temperature Dependency:** All 15 reaction rates follow the Arrhenius equation:

$$
k_i = k_{i,0} \cdot \exp\left(-\frac{E_{a,i}}{R \cdot T_{\text{riser}}}\right)
$$


**Reference:** Model based on "Comprehensive Kinetic Modeling and Sensitivity Analysis of Industrial Fluid Catalytic Cracking (FCC) Unit," *Arabian Journal for Science and Engineering* (2025).
DOI: 10.1007/s13369-025-10412-6
