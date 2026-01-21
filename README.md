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
Optimizes fixed operating conditions for a two-column system: the Atmospheric Distillation Unit (ADU) and the Vacuum Distillation Unit (VDU). The process discretizes crude oil into "narrow cuts" to track boiling point ranges accurately.

### 2. Key Constraints
* **Product Quality Specifications:** Final products must satisfy strict standards: Maximum Sulfur content and Minimum API Gravity.
* **Bilinear Blending Equations:** Ensure flow and property balances are satisfied when mixing intermediate streams into final product pools.

---

## Case 4: 4-Step PSA Carbon Capture Optimization



### 1. Problem Description
This case addresses the optimal design of a four-step Vacuum Pressure Swing Adsorption (PVSA) cycle for $CO_2/N_2$ separation. The physics are governed by a system of coupled Partial Differential-Algebraic Equations (PDAEs).

### 2. Optimization Goals
* **Minimize Capture Cost:** Minimize the $CO_2$ capture cost (\$/ton $CO_2$) by optimizing step durations and operating pressures ($P_H, P_I, P_L$).

* **Reference:** Model based on "Hybrid data-driven optimisation approach for pressure swing adsorption," *Separation and Purification Technology* (2026).

---

## Case 5: Newton's Cradle Dynamic Simulation


### 1. Physical & Mathematical Model
The system is governed by Newton's Second Law, treating collisions as a "stiff" physical process governed by DAEs.

* **Kinematics:** $\frac{dx_i}{dt} = v_i$
* **Dynamics:** $m \frac{dv_i}{dt} = \sum F_{\text{contact}}$
* **Contact Force Model:** $F = \max(0, k \cdot (2r - \text{distance}))$

---

## Case 6: Refinery Production Planning

### 1. Nonlinear Features
* **Nonlinear Yields:** Gasoline output is a quadratic function of temperature and feedstock API gravity.
* **Variable Operating Costs:** Utility costs are modeled as an increasing function of the operating temperature: $\text{OpCosts}(T)$.

---

## Case 7: Gasoline Blending and Pooling

### 1. Key Technical Challenges
The primary complexity arises from Bilinearity:
* **Pool Quality Balance:**

$$
\sum_{i \in I} (f_{ip,t} \cdot \text{InputQuality}_{i,q}) = q_{p,q,t} \cdot \sum_{i \in I} f_{ip,t}
$$


### 2. Component Data
| Component | RON (Octane) | Sulfur (ppm) | Cost ($/bbl) |
| :--- | :--- | :--- | :--- |
| **Alkylate** | 98 | 5 | 90 |
| **Reformate** | 102 | 10 | 85 |
| **FCC Naphtha** | 92 | 50 | 70 |

---

## Case 8: Industrial FCC Unit Optimization (6-Lump Kinetic Model)



### 1. System Architecture
* **Riser Reactor:** Modeled as a PFR (Plug Flow Reactor) for endothermic cracking.
* **Regenerator:** Modeled as a CSTR (Continuous Stirred-Tank Reactor) for catalyst regeneration.

### 2. Mathematical & Kinetic Model
The system uses the Arrhenius equation for 15 reaction networks:
$$k_i = k_{i,0} \cdot \exp\left(-\frac{E_{a,i}}{R \cdot T_{\text{riser}}}\right)$$

**Catalyst Deactivation:**
$$\frac{d\Phi}{dz} = -2.0 \cdot \Phi \cdot y_{\text{coke}} \cdot \text{Tau}$$

* **Reference:** Model based on "Comprehensive Kinetic Modeling and Sensitivity Analysis of Industrial Fluid Catalytic Cracking (FCC) Unit," *Arabian Journal for Science and Engineering* (2025).
