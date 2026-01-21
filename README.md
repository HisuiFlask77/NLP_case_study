# Nonlinear Problem implementations: Case Studies

This repository features a diverse collection of Nonlinear Programming (NLP) problem instances derived from complex industrial and physical engineering scenarios. The models are implemented using state-of-the-art optimization frameworks, including GAMS, Pyomo, and CasADi.

## Table of Contents
* [Case 1: Refinery Hydrogen Network Optimization](#case-1-refinery-hydrogen-network-optimization)
* [Case 2: Multi-Period Refinery Crude Oil Scheduling Optimization](#case-2-multi-period-refinery-crude-oil-scheduling-optimization)
* [Case 3: Steady-State Two-Column Crude Distillation and Product Blending Optimization](#case-3-steady-state-two-column-crude-distillation-and-product-blending-optimization)
* [Case 4: 4-step PSA carbon capture Optimization](#case-4-4-step-psa-carbon-capture-optimization)
* [Case 5: Newton's Cradle Dynamic Simulation](#case-5-newtons-cradle-dynamic-simulation)
* [Case 6: Refinery Production Planning](#case-6-refinery-production-planning)
* [Case 7: Gasoline Blending and Pooling](#case-7-gasoline-blending-and-pooling)
* [Case 8: Industrial FCC Unit Optimization (6-Lump Kinetic Model)](#case-8-industrial-fcc-unit-optimization-6-lump-kinetic-model)

---

## Case 1: Refinery Hydrogen Network Optimization

### 1. Problem Description
This case addresses the **Hydrogen Management Problem** in a petroleum refinery.  The network is modeled as a **Superstructure** that interconnects multiple hydrogen sources (SMR, CCR), consumption sinks (HCU, DHT, etc.), and purification units (PSA). 

 The core complexity arises from the **mixing of streams** with different concentrations, which generates **bilinear terms** (Flow Rate $\times$ Purity).  This makes the problem a NLP model where the actual inlet purity of each unit is a variable determined by the optimized blend.



### 2. Optimization Goals
*  **Minimize the TAC:** The objective function focuses on reducing the expenses associated with purchasing or producing high-purity fresh hydrogen (e.g., from an SMR unit).
*  **Maximize Hydrogen Reuse:** Strategically recycle "off-gas" from high-purity sinks to lower-requirement units or purification units to minimize waste.

### 3. Key Constraints
*  **Sink Requirements:** Every processing unit must receive its required total hydrogen flow rate and maintain a minimum purity threshold at the inlet to protect catalyst activity.
*  **Source Capacity:** The total hydrogen drawn from any production unit (SMR, CCR) must not exceed its maximum operating capacity.
*  **System Balances:** The network must satisfy both total mass balances and component (hydrogen) balances at every junction and splitter.
*  **Purification Performance:** The PSA unit operates under a fixed recovery rate and specific product purity limits.

---

## Case 2: Multi-Period Refinery Crude Oil Scheduling Optimization

### 1. Problem Description
 This case addresses the industrial-scale scheduling of crude oil operations over a 10-day time horizon.  The system manages three categories of crude oil—Arabian Light (AL), Arabian Heavy (AH), and Bonny Light (BL)—arriving via vessels on specific scheduled dates.  These feedstocks are unloaded into four storage tanks where non-linear blending occurs before being processed by two Crude Distillation Units (CDU).



 The core mathematical challenge is the **Dynamic Tank Quality Balance**.  Because different crude types mix in the tanks, the model must track quality attributes (Sulfur and API Gravity) using bilinear terms (Volume $\times$ Quality), creating a NLP space.

### 2. Optimization Goals
*  **Maximize Total Net Profit**: The objective is to maximize profit, calculated as gross product value minus crude costs, inventory holding costs, and operational switching costs.
*  **Quality-Driven Revenue**: Product value is estimated as a function of the feed quality (API Gravity and Sulfur content), incentivizing the optimizer to find the most valuable blend.

### 3. Key Constraints
*  **Material and Inventory Balances**: The model enforces a bulk volume balance for each tank across all time periods ($V_t = V_{t-1} + In - Out$).
*  **Nonlinear Quality Mixing**: Property mass balances ensure that the sulfur and gravity levels in the tanks and CDU feeds accurately reflect the physical blending of different crude types.
*  **CDU Capacity Limits**: Each distillation unit must operate between its minimum turndown rate and its maximum daily processing capacity.
*  **Unloading Allocation**: All scheduled vessel arrivals must be fully unloaded and allocated to available storage tanks.

---
## Case 3: Steady-State Two-Column Crude Distillation and Product Blending Optimization

### 1. Problem Description
This case focuses on the steady-state operational optimization of a refinery’s primary distillation section. Unlike scheduling models, this case optimizes fixed operating conditions for a two-column system: the **Atmospheric Distillation Unit (ADU)** and the **Vacuum Distillation Unit (VDU)**.


The process discretizes crude oil into "narrow cuts" to track boiling point ranges accurately. The non-linear core involves **E-Cutpoint Correlations**, where distillation yields are functions of cut-point temperatures, and **bilinear mass conservation** equations during the final product blending phase.

### 2. Optimization Goals
* **Maximize Total Net Profit**: The objective is to maximize the difference between final product revenue and the combined costs of crude procurement and unit operating expenses.
* **Optimize Fraction Routing**: Determine the optimal "Swing Cut" split ratios (e.g., Naphtha/Kerosene and Kerosene/Diesel) to divert intermediate streams to the most valuable product pools.

### 3. Key Constraints
* **Unit Capacity Limits**: The total crude feed rate must not exceed the ADU capacity, and the atmospheric residue (AR) sent to the VDU must remain within its vacuum processing limits.
* **Product Quality Specifications**: Final products (Gasoline, Jet Fuel, Diesel, and Fuel Oil) must satisfy strict environmental and performance standards, specifically **Maximum Sulfur content** and **Minimum API Gravity**.
* **Fraction Allocation Logic**: Enforce topological constraints to ensure that narrow cuts are routed correctly based on the optimized split variables and boiling point hierarchies.
* **Bilinear Blending Equations**: Ensure that the flow and property balances are satisfied when mixing intermediate streams into final product pools.

---

## Case 4: 4-step PSA carbon capture Optimization

### 1.Problem: Optimization of a four-step PVSA cycle (pressurization, adsorption, blowdown, evacuation) for $CO_2/N_2$ separation, characterized by high nonlinearity, stiffness, and the requirement for cyclic steady-state (CSS) convergence.

### 2.Goal: Minimize the $CO_2$ capture cost ($\$/tonCO_2$) by optimizing step durations, operating pressures ($P_H, P_I, P_L$), and feed velocities.

### 3.Constraints: Stringent product requirements ($CO_2$ purity $\ge 95\%$, recovery $\ge 90\%$), logical pressure ordering, and adsorbent material capacity limits.

* **Reference:** Model based on Hybrid data-driven optimisation approach for pressure swing adsorption," *Separation and Purification Technology* (2026).

---

## Case 5: Newton's Cradle Dynamic Simulation

### 1. Problem Description
This case focuses on the dynamic modeling of a multi-body collision system—a **Newton's Cradle** consisting of three identical balls. Unlike basic animations, this simulation treats collisions as a "stiff" physical process governed by **DAEs**.

### 2. Physical & Mathematical Model
The system is governed by Newton's Second Law. We model the collision as a high-stiffness spring interaction:
* **Kinematics:** $$\frac{dx_i}{dt} = v_i$$
* **Dynamics:** $$m \frac{dv_i}{dt} = \sum F_{\text{contact}}$$
* **Contact Force Model:** $$F = \max(0, k \cdot (2r - \text{distance}))$$

---

## Case 6: Refinery Production Planning

### 1. Problem Description
This case addresses a **Refinery Production Planning** problem. The goal is to maximize daily profit by optimizing the mix of crude oil feedstocks, unit throughputs, and critical operating parameters like temperature.

### 2. Nonlinear Features
* **Nonlinear Yields:** Gasoline output is a quadratic function of temperature and feedstock API gravity.
* **Variable Operating Costs:** Utility costs are modeled as an increasing function of the operating temperature.
* **Objective:** Maximize $Z = \text{Revenue} - \text{Crude Costs} - \text{OpCosts}(T)$.

---

## Case 7: Gasoline Blending and Pooling

### 1. Problem Overview
This case addresses the **Multi-period Gasoline Blending and Pooling Problem**, a classic and challenging Nonlinear Programming (NLP) problem in refinery operations. The model optimizes the transition of raw feedstocks into intermediate storage tanks (Pools) and finally into marketable gasoline grades over multiple time periods.

### 2. Key Technical Challenges
The primary complexity of this model arises from **Bilinearity**:
* **Pooling:** Feedstock qualities (RON, Sulfur) are known, but the qualities of the intermediate pools depend on the blend ratio and are initially unknown.
* **Non-Convexity:** The quality balance involves the product of flow rates and pool qualities (e.g., $q_p \times \sum f_{ip}$), creating bilinear terms that make the problem non-convex and difficult for standard solvers to reach global optima without good initial guesses.

### 3. Mathematical Formulation
The model tracks quality attributes (RON and Sulfur) across three time periods.

**Pool Quality Balance:**
The sum of inflow mass must equal the outflow mass, where the pool quality $q_{p,q,t}$ is a decision variable:
$$\sum_{i \in I} (f_{ip,t} \cdot \text{InputQuality}_{i,q}) = q_{p,q,t} \cdot \sum_{i \in I} f_{ip,t}$$

**Product Specifications:**
Final products (Premium and Regular) must meet strict quality boundaries:
* **Octane (RON):** Must meet a minimum threshold (e.g., 95 for Premium).
* **Sulfur:** Must remain below a maximum threshold (e.g., 15 ppm for Premium).

### 4. Component Data
| Component | RON (Octane) | Sulfur (ppm) | Cost ($/bbl) |
| :--- | :--- | :--- | :--- |
| **Alkylate** | 98 | 5 | 90 |
| **Reformate** | 102 | 10 | 85 |
| **FCC Naphtha** | 92 | 50 | 70 |


---

## Case 8: Industrial FCC Unit Optimization (6-Lump Kinetic Model)

### 1. Problem Overview
This case models and optimizes an industrial **FCC** unit, specifically based on the Abadan Refinery configuration. The FCC unit is one of the most critical processes in modern petroleum refining, responsible for converting heavy vacuum gas oil (VGO) into high-value lighter products like gasoline.

The model employs a **6-Lump kinetic network** (VGO, Diesel, Gasoline, LPG, Dry Gas, and Coke) to simulate the chemical transformations within the system.



### 2. System Architecture
The simulation captures the coupled dynamics of two distinct reactor types:
* **Riser Reactor:** Modeled as a **PFR** where the endothermic cracking reactions take place as the catalyst and oil vapor travel upward.
* **Regenerator:** Modeled as a **CSTR**. This unit burns off the coke deposited on the catalyst to restore its activity and provides the thermal energy required for the riser reactions.

### 3. Mathematical & Kinetic Model
The system is described by a series of DAEs including mass balances, energy balances, and catalyst deactivation kinetics.

**Reaction Kinetics:**
The 15-reaction network uses the Arrhenius equation to calculate rate constants $k_i$:
$$k_i = k_{i,0} \cdot \exp\left(-\frac{E_{a,i}}{R \cdot T_{riser}}\right)$$

**Mass Balance:**
For each chemical lump $j$, the change in mass fraction $y$ along the riser height $z$ is governed by:
$$\frac{dy_j}{dz} = \text{NetRate}_j \cdot \text{Tau}$$

**Catalyst Deactivation:**
The catalyst activity $\Phi$ decreases as it becomes covered in coke:
$$\frac{d\Phi}{dz} = -2.0 \cdot \Phi \cdot y_{\text{coke}} \cdot \text{Tau}$$

### 4. Optimization Objective
The primary goal is to **maximize the mass fraction of Gasoline** at the riser outlet. The optimization must balance the catalyst circulation rate and air flow rate while strictly obeying industrial energy and mass balance constraints.

**Key Decision Variables:**
* **Catalyst Circulation Rate ($F_{cat}$):** Range of 100 to 2000 kg/s.
* **Air Flow Rate:** Range of 10 to 500 units.

* **Reference:** Model based on "Comprehensive Kinetic Modeling and Sensitivity Analysis of Industrial Fluid Catalytic Cracking (FCC) Unit," *Arabian Journal for Science and Engineering* (2025).
