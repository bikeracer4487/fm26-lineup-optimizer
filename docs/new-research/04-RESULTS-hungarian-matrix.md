# **Hungarian Matrix Architecture: Operationalizing Squad Management via Linear Sum Assignment**

## **I. Introduction: The Convergence of Algorithmic Logic and Sporting Intuition**

The contemporary landscape of football management, whether practiced within the high-stakes environment of professional clubs or simulated through the granular fidelity of Sports Interactive’s *Football Manager*, has evolved into a complex domain of constraint satisfaction and resource allocation. No longer is the managerial remit confined to the subjective selection of the "best eleven" players based on historical reputation or perceived quality. Instead, the modern manager operates as the chief architect of a dynamic system, tasked with solving a continuous, multi-objective optimization problem: maximizing the probability of immediate competitive success while simultaneously minimizing long-term fatigue accrual, injury risk, and squad stagnation.1 The decision space is high-dimensional, involving variables that range from physical condition and match sharpness to tactical familiarity and developmental trajectories. Navigating this space requires moving beyond intuition toward rigorous mathematical modeling.

This report proposes and details the "Hungarian Matrix Architecture," a sophisticated operational framework that applies the Linear Sum Assignment Problem (LSAP) to squad rotation and selection. By leveraging the Kuhn-Munkres (Hungarian) algorithm, we transform the subjective dilemmas of management—such as whether to play a tired star or a fresh prospect—into a solvable matrix of costs and utilities.3 This approach provides a mathematically optimal solution to the allocation of "workers" (players) to "jobs" (tactical roles), ensuring that the marginal utility of every minute played is maximized across the constraints of a grueling season.5

The necessity for such an architecture arises from the inherent limitations of human cognition in handling combinatorial complexity. A squad of 25 players competing for 11 positions yields millions of potential permutations. When compounded by constraints such as registration quotas, fatigue thresholds, and disjoint positional sets (e.g., goalkeepers), the "Best XI" is rarely a static entity. It is a fluid concept that shifts with every decrement in player condition and every fluctuation in form. The Hungarian Matrix Architecture operationalizes these shifts, creating a decision-support system that integrates the hardness of Operations Research with the softness of human heuristics.6

## **II. Theoretical Framework: The Linear Sum Assignment Problem (LSAP) in Sports**

To deploy the Hungarian Matrix Architecture, one must first establish the mathematical foundation upon which it rests. The problem of squad selection is formally an instance of the Linear Sum Assignment Problem (LSAP), a fundamental class of combinatorial optimization problems involving the pairing of agents to tasks to minimize total cost or maximize total efficiency.8

### **2.1 Mathematical Formulation of the Squad Matrix**

Let $N$ represent the set of tactical roles required for a match (typically $|N| \= 11$ for the starting lineup), and let $M$ represent the pool of available players (the squad). In the canonical formulation, we assume a balanced assignment where $|N| \= |M|$; however, the reality of football management involves rectangular matrices where $|M| \> |N|$, a variation discussed in subsequent sections.

We define a cost matrix $C$ of size $N \\times M$, where each element $c\_{i,j}$ represents the "cost" of assigning role $i$ to player $j$. In the context of performance maximization, this "cost" is the negation of the player's utility ($U\_{i,j}$), such that minimizing cost is mathematically equivalent to maximizing team strength.9

The objective is to find a boolean assignment matrix $X$, where $x\_{i,j} \\in \\{0, 1\\}$, such that:

$$\\min \\sum\_{i=1}^{N} \\sum\_{j=1}^{M} c\_{i,j} x\_{i,j}$$  
This objective function is subject to strict constraints that define the rules of the sport:

1. Role Fulfillment Constraint: Every tactical role must be filled by exactly one player.

   $$\\sum\_{j=1}^{M} x\_{i,j} \= 1, \\quad \\forall i \\in \\{1, \\dots, N\\}$$  
2. Player Singularity Constraint: A player can fulfill at most one role (no cloning).

   $$\\sum\_{i=1}^{N} x\_{i,j} \\le 1, \\quad \\forall j \\in \\{1, \\dots, M\\}$$  
3. Integrality Constraint: Assignments must be binary; a player cannot be "half-assigned" to a role in a discrete match scenario.

   $$x\_{i,j} \\in \\{0, 1\\}$$

The solution to this formulation yields a **Maximum Weight Matching** in a bipartite graph, where one set of vertices represents the roles and the other represents the players. The edges connecting them are weighted by the calculated utility of the pairing.4

### **2.2 The Kuhn-Munkres (Hungarian) Algorithm**

While brute-force enumeration of all squad permutations is computationally infeasible ($11\! \\approx 39.9$ million, and selecting 11 from 25 is vastly larger), the Hungarian Algorithm allows for an optimal solution in polynomial time, specifically $O(n^3)$ in modern implementations.4 This efficiency is critical for decision-support systems that must recalculate assignments dynamically as parameters change (e.g., a player failing a late fitness test).

The algorithm operates on the principle of combinatorial duality. It seeks to reduce the cost matrix to a state where a set of independent zeros exists—representing "free" assignments in the reduced cost space—that corresponds to the optimal matching. The procedure involves:

1. **Row and Column Reduction:** Subtracting the minimum value from each row and column to normalize costs relative to the best options.10  
2. **Zero Covering:** Using the minimum number of lines to cover all zeros in the matrix. If the number of lines equals the dimension of the matrix, an optimal assignment is found.13  
3. **Matrix Transformation:** If optimality is not reached, the algorithm manipulates the uncovered elements to shift the "zero landscape" without altering the relative ranking of assignments, iteratively converging on the solution.14

In computational terms, particularly within the Python ecosystem used for this research, the implementation often utilizes the **Modified Jonker-Volgenant algorithm**, which is faster and more robust for rectangular and sparse matrices than the original Kuhn-Munkres formulation.3

### **2.3 Handling the Rectangular Squad (Unbalanced Assignment)**

A football squad is inherently unbalanced: there are more players than starting spots ($M \> N$). This creates a **Rectangular Linear Assignment Problem (RLAP)**. Standard textbook definitions of the Hungarian algorithm assume square matrices, necessitating specific architectural adjustments for the squad management domain.8

There are two primary methods for handling the excess players (the bench and reserves) within the matrix architecture:

#### **2.3.1 Explicit Padding with Dummy Nodes**

To square the matrix, we introduce $M \- N$ "Dummy Roles" (or "Slack Variables"). Assigning a player to a Dummy Role is equivalent to leaving them on the bench.

* **Cost of Dummies:** If maximizing utility, the utility of a dummy assignment is typically zero. However, to model the value of rotation, we can assign a **positive utility to resting**. If Player A is jaded, their utility in a "Rest" row might be higher than their utility in a "Play" row, incentivizing the algorithm to bench them optimally.1  
* The formulation becomes:

  $$\\min \\sum\_{i=1}^{M} \\sum\_{j=1}^{M} c'\_{i,j} x\_{i,j}$$

  Where $c'\_{i,j}$ for $i \> N$ (dummy rows) reflects the strategic value of preserving the player.17

#### **2.3.2 Implicit Rectangular Resolution**

Modern solvers, such as scipy.optimize.linear\_sum\_assignment, handle rectangular inputs natively. They solve the generalized problem where every row (role) is matched to a column (player), but not every column must be matched. The algorithm returns a subset of indices corresponding to the optimal $N$ players, effectively discarding the unselected $M-N$ players from the active solution set.3 This method is computationally superior as it avoids the memory overhead of large padded matrices, though it requires careful pre-processing to ensure that the "value of rest" is internalized in the active player costs (e.g., via penalty functions) rather than explicit dummy rows.12

## ---

**III. Quantifying Football Utility: Constructing the Cost Matrix**

The mathematical elegance of the Hungarian algorithm is rendered distinct by the quality of its inputs. The "Garbage In, Garbage Out" principle is paramount. To operationalize the architecture, we must transmute the abstract, qualitative concepts of football—form, fitness, suitability, and morale—into a unified scalar value $U\_{i,j}$ (Utility) for every player-position pair. This process is the bridge between the "Hard" science of optimization and the "Soft" science of man-management.

### **3.1 The Weighted-Sum Attribute Model**

The foundational utility of a player is derived from their attributes relative to the specific demands of a tactical role. In *Football Manager*, players are defined by attributes on a scale of 1-20. However, a raw sum of attributes is a poor predictor of performance; a Centre-Back with 20 Finishing is inefficient if they lack Tackling and Positioning.

We define the **Base Utility** ($U\_{base}$) using a weighted linear combination:

$$U\_{base}^{(i,j)} \= \\sum\_{k \\in \\mathcal{A}} w\_{i,k} \\cdot A\_{j,k}$$  
Where:

* $\\mathcal{A}$ is the set of all player attributes.  
* $A\_{j,k}$ is the rating of attribute $k$ for player $j$.  
* $w\_{i,k}$ is the weighting factor of attribute $k$ for role $i$.19

**Strategic Insight:** The weights ($w\_{i,k}$) function as the manager's "Tactical DNA." A manager favoring a High Press will assign a high $w$ to *Stamina* and *Work Rate* for forward roles, whereas a manager favoring a Low Block might prioritize *Positioning* and *Strength*. These weights must be tuned to reflect the marginal gain of specific skills; "Key" attributes often carry a weight of 3.0, "Secondary" attributes 1.5, and irrelevant attributes 0.0.1

### **3.2 The Physiology of Rotation: Condition and Sharpness**

The most critical heuristic in squad rotation is the non-linear trade-off between **Condition** (energy reserves) and **Match Sharpness** (performance readiness). This relationship defines the "Rotation Paradox": resting a player restores Condition but degrades Sharpness.20

#### **3.2.1 The Condition Decay Function**

Research in sports science and FM community heuristics indicates that performance does not degrade linearly with fatigue. Instead, there are "cliffs" where performance collapses. We model this via a discrete multiplier function, $M\_{con}(c)$, where $c$ is the player's condition percentage 21:

| Condition Range (c) | Multiplier (Mcon​) | Reasoning |
| :---- | :---- | :---- |
| $\\ge 95\\%$ | $1.00$ | Peak physical performance. |
| $90\\% \- 94\\%$ | $0.95$ | Minor degradation; acceptable for starters. |
| $80\\% \- 89\\%$ | $0.80$ | Significant drop; high risk of late-game errors. |
| $\< 80\\%$ | $0.50$ | "Red Zone"; high injury risk, severe performance loss. |

This non-linear penalty ensures that the algorithm will only select a tired star (e.g., Condition 78%) if the alternative is a youth player whose base utility is less than 50% of the star's capability.16

#### **3.2.2 The Sharpness Curve**

Match Sharpness represents a player's cognitive and technical readiness. A player with 100% Condition but 50% Sharpness is "rusty" and prone to poor decision-making. We apply a sharpness modifier $M\_{shp}(s)$ 20:

$$M\_{shp}(s) \= \\frac{1}{1 \+ e^{-\\lambda(s \- s\_0)}}$$  
Alternatively, a simpler step function is often used in heuristics:

* Sharpness $\> 90$: $1.0$ (Match Fit)  
* Sharpness $70-90$: $0.9$ (Lacking)  
* Sharpness $\< 50$: $0.7$ (Rusty)

Synthesis: The effective physical utility is the product of these factors:

$$U\_{phys}^{(i,j)} \= U\_{base}^{(i,j)} \\cdot M\_{con}(c\_j) \\cdot M\_{shp}(s\_j)$$

### **3.3 Modeling Jadedness: The Hidden Variable**

"Jadedness" differs from acute fatigue (Condition). It is a hidden variable representing accumulated season-long workload and mental burnout.23 While Condition recovers in days, Jadedness recovers in weeks. High jadedness correlates with a higher probability of injury and "invisibility" in matches.

In the Hungarian Matrix, Jadedness is not a multiplier but a **Threshold Constraint** or a heavy **Additive Penalty**.

* **Penalty Approach:** $Cost \= Cost \+ P\_{jaded}$. If a player is flagged as "Jaded," we add a substantial penalty (e.g., equivalent to a 20% drop in utility) to discourage selection unless essential.  
* **Hard Constraint:** If Jadedness \> Threshold, the assignment cost is set to Big M ($10^9$), effectively forcing the player to rest.25 This aligns with sports science concepts of "Non-Functional Overreaching," where continued loading leads to maladaptation.26

### **3.4 Tactical Familiarity and Switching Costs**

A player playing out of position suffers penalties to attributes like *Decision Making* and *Positioning*. The matrix accounts for this via the **Positional Efficiency Rating** ($E\_{pos}$):

* Natural: 100%  
* Accomplished: 85%  
* Unconvincing: 50%  
* Awkward: 20%

Furthermore, we must consider **Switching Costs**. If a player played Left Back in the previous match, moving them to Right Back in the current match incurs a minor "disruption penalty" representing the loss of tactical rhythm. This introduces a dynamic element where $Cost\_{t}$ depends on Assignment$\_{t-1}$.28

## ---

**IV. Advanced Constraint Architectures**

Standard LSAP formulations assume any worker can do any job, varying only in cost. In football, strict rules (constraints) exist that cannot be violated (e.g., a suspension) or should rarely be violated (e.g., playing a goalkeeper as a striker). The architecture must handle these via **Hard Constraints** and **Soft Constraints**.30

### **4.1 The Disjoint Set Problem: Goalkeepers vs. Outfield**

Goalkeepers (GK) and Outfield players form effectively disjoint sets. A GK has near-zero utility in outfield roles, and outfield players have near-zero utility in goal. Including them in a single $11 \\times 25$ matrix increases the search space unnecessarily and risks numerical noise (e.g., a bug where a GK is assigned to Striker because the "Big M" wasn't big enough).32

Operational Solution:  
The most robust architecture splits the problem into two independent matrices:

1. **GK Matrix:** $1 \\times N\_{GK}$ (Solves for the Goalkeeper).  
2. **Outfield Matrix:** $10 \\times N\_{Outfield}$ (Solves for the remaining 10 spots).

This "Partitioned Assignment" ensures structural validity and improves computational speed. The results are then concatenated to form the final team sheet.

### **4.2 Implementing "Big M" with Numerical Stability**

To strictly forbid an assignment (e.g., an injured player), we assign an infinite cost. However, in computational practice (specifically using float64 in SciPy), true infinity can cause errors in summation or convergence checks.25

Instead, we use a "Safe Big M" value. This value must be:

1. Larger than any possible sum of valid assignments.  
2. Small enough to avoid floating-point overflow or precision loss during subtraction steps.

Calculation of Safe Big M:  
If the maximum possible utility for a player is $200$ (20 attributes $\\times$ max weight 10), and there are 11 positions, the max team utility is $2200$.  
A Safe Big M would be $10^6$ (1,000,000).

$$C\_{i,j} \= 10^6 \\quad \\text{if assignment is forbidden.}$$

If the returned optimal cost exceeds $10^6$, the algorithm signals that no feasible solution exists (e.g., not enough healthy players to field a team), prompting an alert for the manager.4

### **4.3 Lagrangian Relaxation for Registration Quotas**

Competitions often enforce quotas, such as "Minimum 4 Club-Grown Players." This transforms the problem into a **Constrained Assignment Problem**, which is generally NP-Hard.6

The Hungarian Matrix Architecture approximates this using a **Lagrangian Relaxation** approach via penalty weights:

1. **Initial Solve:** Run the unconstrained assignment.  
2. **Check Constraint:** Count Club-Grown players in the solution.  
3. Penalty Injection: If the count is $\< 4$, apply a global "subsidy" (utility boost) or "penalty reduction" to all Club-Grown players in the pool.

   $$U'\_{j} \= U\_{j} \+ \\lambda \\quad \\forall j \\in \\text{ClubGrown}$$  
4. **Iteration:** Re-run the assignment. Increase $\\lambda$ (the Lagrange multiplier) iteratively until the constraint is satisfied.

This method dynamically biases the matrix to favor the constrained category until the quota is met, balancing the performance loss against the regulatory requirement.37

## ---

**V. Multi-Objective Optimization: Balancing Conflict**

A manager does not optimize for a single variable. They balance **Winning Now** (Current Ability) against **Developing Future** (Potential Ability) and **Resting Stars** (Fatigue Management). These are conflicting objectives.1

### **5.1 Scalarization of Objectives**

The most effective method for handling this in an operational context is **Weighted Sum Scalarization**. We create a composite cost function:

$$C\_{total} \= w\_1 C\_{perf} \+ w\_2 C\_{dev} \+ w\_3 C\_{fatigue}$$  
Where:

* $C\_{perf}$: Cost derived from Current Ability and Suitability.  
* $C\_{dev}$: Cost derived from lost development time (prioritizing youth).  
* $C\_{fatigue}$: Cost derived from accumulated workload (prioritizing rest).

### **5.2 Scenario-Based Weighting Profiles**

The scalars ($w\_1, w\_2, w\_3$) are not static; they change based on the **Match Priority**.

| Match Scenario | w1​ (Perf) | w2​ (Dev) | w3​ (Rest) | Strategic Outcome |
| :---- | :---- | :---- | :---- | :---- |
| **Cup Final** | $1.0$ | $0.0$ | $0.0$ | Pure "Best XI." Ignore fatigue/youth. |
| **League Grind** | $0.6$ | $0.1$ | $0.3$ | Balanced rotation. Avoid red-zone players. |
| **Dead Rubber** | $0.2$ | $0.5$ | $0.3$ | Prioritize youth and resting key starters. |
| **Youth Cup** | $0.3$ | $0.7$ | $0.0$ | Maximize youth playing time regardless of ability. |

This dynamic weighting system allows the algorithm to shift its "personality" from a ruthless pragmatist to a long-term strategist without changing the underlying code structure.40

## ---

**VI. The Bench Problem: Two-Stage Optimization**

A unique characteristic of football is that the utility of a substitute differs fundamentally from that of a starter. A starter needs **Specialization** (peak performance in one role). A substitute needs **Versatility** (ability to cover multiple roles in case of injury).20

### **6.1 The Two-Stage Algorithm**

Standard LSAP solves for the best 11\. It does not inherently understand the concept of a bench. Therefore, we implement a **Sequential Optimization Logic**:

**Stage 1: The Starting XI**

* Input: Full Squad ($M$).  
* Matrix: $11 \\times M$ based on **Peak Utility** ($U\_{peak}$).  
* Output: Set $S$ (Starters).

**Stage 2: The Bench**

* Input: Remaining Squad ($M \- S$).  
* Matrix: $K \\times (M \- S)$ (where $K$ is bench size, e.g., 7).  
* New Utility Function: For the bench, we calculate Coverage Utility ($U\_{cover}$).

  $$U\_{cover}^{(j)} \= \\sum\_{r \\in \\text{AllRoles}} (A\_{j,r} \\times P(\\text{Injury}\_r))$$

  Where $P(\\text{Injury}\_r)$ is the probability that role $r$ will need a substitution.

### **6.2 Coverage Logic**

In Stage 2, a player who is "Accomplished" in 4 positions (e.g., DR, DL, MC, MR) receives a massive utility boost compared to a specialist Striker, even if the Striker has higher Current Ability. This ensures the algorithm selects a "Utility Man" (e.g., James Milner archetype) for the bench, guaranteeing that the squad is resilient to in-match injuries across defense and midfield.20

## ---

**VII. Algorithmic Implementation: Python and SciPy**

To operationalize the Hungarian Matrix Architecture, we rely on the scipy.optimize library within the Python ecosystem. The function linear\_sum\_assignment is the industry standard for solving LSAP, utilizing the Jonker-Volgenant algorithm for $O(n^3)$ efficiency.3

### **7.1 Code Structure and Maximization Logic**

Since SciPy minimizes cost, we must negate our Utility Matrix.

Python

import numpy as np  
from scipy.optimize import linear\_sum\_assignment

def solve\_squad\_selection(utility\_matrix):  
    """  
    Solves the assignment problem for a given utility matrix.  
    Rows \= Positions, Cols \= Players.  
    """  
    \# 1\. Negate Utility to convert Maximization \-\> Minimization  
    \#    We use a Safe Big M approach for forbidden slots (e.g., Injured)  
    \#    Forbidden slots in utility\_matrix should be \-np.inf or extremely low.  
      
    \# Create Cost Matrix  
    cost\_matrix \= \-utility\_matrix  
      
    \# Handle Forbidden Assignments (Infs in utility become \-Infs)  
    \# We replace \-Inf with Safe Big M for minimization  
    SAFE\_BIG\_M \= 1e9  
    cost\_matrix\[np.isinf(cost\_matrix)\] \= SAFE\_BIG\_M

    \# 2\. Solve using Modified Jonker-Volgenant  
    \#    scipy handles rectangular matrices natively by selecting  
    \#    indices that minimize the sum.  
    row\_ind, col\_ind \= linear\_sum\_assignment(cost\_matrix)  
      
    \# 3\. Validation  
    \#    Check if total cost exceeds Big M (implying infeasibility)  
    total\_cost \= cost\_matrix\[row\_ind, col\_ind\].sum()  
    if total\_cost \>= SAFE\_BIG\_M:  
        raise ValueError("No feasible squad selection found.")  
          
    return row\_ind, col\_ind

### **7.2 Handling Rectangularity and Bench Selection**

As noted in 3 and 3, linear\_sum\_assignment does not require explicit padding for the $11 \\times 25$ case. It returns the optimal 11 assignments. The indices in col\_ind represent the selected players.

To select the bench, we perform a **Matrix Masking** operation:

1. Identify col\_ind from Stage 1 (Starters).  
2. Create a Boolean Mask of the squad, setting is\_available \= False for the indices in col\_ind.  
3. Construct the Bench Utility Matrix using only players where is\_available \== True.  
4. Run linear\_sum\_assignment on the new subset.43

### **7.3 Numerical Stability Checks**

When using float64, extremely small differences in utility (e.g., $150.0000001$ vs $150.0000002$) can lead to arbitrary tie-breaking. To impose deterministic behavior, it is recommended to **Quantize** utilities to a fixed precision (e.g., 2 decimal places) before solving. This ensures that a "Tie" is genuinely treated as a tie, allowing secondary heuristics (like Squad Number or Alphabetical order) to resolve it consistently if implemented in a custom wrapper.4

## ---

**VIII. Simulation Case Studies**

To demonstrate the architectural robustness, we analyze three operational scenarios.

### **8.1 Scenario A: The "Red Zone" Crisis**

Situation: The team plays its 3rd game in 7 days. 6 starters have Condition \< 85% ("Red Zone").  
Matrix Response:

* The **Condition Multiplier ($M\_{con}$)** for the 6 starters drops to $0.75$.  
* Their Effective Utility ($U\_{eff}$) falls below that of the "Match Fit" reserves (Condition \> 95%).  
* **Outcome:** The algorithm automatically triggers a mass rotation, selecting 6 reserves. A human manager might hesitate, fearing the drop in quality, but the matrix strictly adheres to the "Injury Risk" penalty, valuing long-term availability over the marginal probability of winning this specific match.16

### **8.2 Scenario B: The "Dead Rubber" Development**

Situation: League title secured. 2 games remaining. Objective: Develop Youth.  
Matrix Response:

* **Development Weight ($w\_{dev}$)** is set to $0.8$.  
* The cost function now heavily penalizes players \> 23 years old (Zero or negative development utility).  
* High-potential youth players (PA \> 150\) receive a massive "Future Value" subsidy.  
* **Outcome:** The "Best XI" is benched. The starting lineup is populated by U21 prospects, ensuring they gain critical match experience to trigger attribute growth.1

### **8.3 Scenario C: The "Utility Man" Bench**

Situation: Selecting a 7-man bench.  
Matrix Response:

* Player A (Striker, CA 140\) vs. Player B (Fullback/Midfielder, CA 135).  
* The bench already contains a Striker.  
* The **Coverage Utility** for Player A is low (redundant coverage).  
* The **Coverage Utility** for Player B is high (covers 3 positions: DR, DL, MC).  
* **Outcome:** Player B is selected despite lower Ability. This aligns with the "Optimal Squad Rotation" heuristic of keeping the squad small but versatile.20

## ---

**IX. Conclusion: The Future of Decision Support Systems**

The "Hungarian Matrix Architecture" represents a paradigm shift in sports management. It moves the discipline from the realm of "gut feeling" to the realm of **Computational Intelligence**. By mapping the messy, organic variables of football—fatigue, morale, sharpness, and ability—onto the rigorous framework of the Linear Sum Assignment Problem, we create a system that is transparent, repeatable, and mathematically optimal given the input constraints.

This architecture does not replace the manager; rather, it augments them. It handles the computational load of the $10^{14}$ potential permutations, filtering the noise to present the manager with the "Pareto Efficient" options. Whether navigating a congested winter fixture list or managing a strict homegrown quota, the application of Operations Research principles ensures that every resource is utilized to its theoretical maximum. As data collection in football becomes more granular—tracking player recovery curves, biomarkers, and psychological states—the precision of the Utility Matrix will only increase, cementing the LSAP as the central engine of modern squad management.

## ---

**X. Technical Appendix: Data Structures**

### **Table 1: Matrix Construction Variables & Definitions**

| Variable | Symbol | Definition | Data Source |
| :---- | :---- | :---- | :---- |
| **Base Utility** | $U\_{base}$ | Weighted sum of attributes ($1-20$) relative to Role | Attributes |
| **Condition Mod** | $M\_{con}$ | Multiplier based on short-term energy | Condition % |
| **Sharpness Mod** | $M\_{shp}$ | Multiplier based on recent match load | Match Sharpness |
| **Jadedness Cost** | $C\_{jad}$ | Subtractive penalty for accumulated fatigue | Hidden Attribute |
| **Positional Mod** | $M\_{pos}$ | Multiplier for role familiarity | Positional Rating |
| **Switching Cost** | $C\_{switch}$ | Penalty for changing role from match $t-1$ | Match History |
| **Safe Big M** | $\\Omega$ | Finite large cost for invalid assignments | $10^6$ (Float64 safe) |

### **Table 2: The "Condition Cliff" Heuristic Table**

| Condition % | Sharpness % | Decision Class | Matrix Impact |
| :---- | :---- | :---- | :---- |
| $\\ge 95\\%$ | $\> 90\\%$ | **Prime** | No Penalty ($Cost \= \-Utility$) |
| $90-94\\%$ | $\> 80\\%$ | **Startable** | Soft Penalty ($Cost \= \-(Utility \\times 0.95)$) |
| $\< 90\\%$ | Any | **Risk** | Moderate Penalty ($Cost \= \-(Utility \\times 0.85)$) |
| Any | $\< 50\\%$ | **Rusty** | Sharpness Penalty ($Cost \= \-(Utility \\times 0.70)$) |
| $\< 75\\%$ | Any | **DANGER** | Hard Constraint ($Cost \\to \\Omega$) |

### **Table 3: Python Implementation Map**

| Concept | Library/Function | Mathematical Operation | Reference |
| :---- | :---- | :---- | :---- |
| **Matrix Solver** | scipy.optimize.linear\_sum\_assignment | Jonker-Volgenant (Bipartite Matching) | 3 |
| **Rectangularity** | scipy (Internal) | Implicit Partial Assignment | 3 |
| **Maximization** | N/A (Manual) | $C\_{ij} \= \-U\_{ij}$ | 9 |
| **Disjoint Sets** | Manual Partitioning | $M\_{GK} \\cup M\_{Outfield}$ | 32 |

#### **Works cited**

1. (PDF) Multi-Objective Optimization for Football Team Member Selection \- ResearchGate, accessed December 29, 2025, [https://www.researchgate.net/publication/352621944\_Multi-Objective\_Optimization\_for\_Football\_Team\_Member\_Selection](https://www.researchgate.net/publication/352621944_Multi-Objective_Optimization_for_Football_Team_Member_Selection)  
2. Optimization of Assignment of Tasks to Teams using Multi-objective Metaheuristics \- CMAP, accessed December 29, 2025, [http://www.cmap.polytechnique.fr/\~nikolaus.hansen/proceedings/2013/GECCO/companion/p103.pdf](http://www.cmap.polytechnique.fr/~nikolaus.hansen/proceedings/2013/GECCO/companion/p103.pdf)  
3. linear\_sum\_assignment — SciPy v1.16.2 Manual, accessed December 29, 2025, [https://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.linear\_sum\_assignment.html](https://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.linear_sum_assignment.html)  
4. Hungarian algorithm \- Wikipedia, accessed December 29, 2025, [https://en.wikipedia.org/wiki/Hungarian\_algorithm](https://en.wikipedia.org/wiki/Hungarian_algorithm)  
5. scipy.optimize.linear\_sum\_assignment — SciPy v1.2.0 Reference Guide, accessed December 29, 2025, [https://docs.scipy.org/doc//scipy-1.2.0/reference/generated/scipy.optimize.linear\_sum\_assignment.html](https://docs.scipy.org/doc//scipy-1.2.0/reference/generated/scipy.optimize.linear_sum_assignment.html)  
6. Multiple Hungarian Method for k-Assignment Problem \- MDPI, accessed December 29, 2025, [https://www.mdpi.com/2227-7390/8/11/2050](https://www.mdpi.com/2227-7390/8/11/2050)  
7. Hungarian maximization model approach for optimizing human resource assignment in multi-site projects, accessed December 29, 2025, [https://www.medikom.iocspublisher.org/index.php/JTI/article/download/1105/88](https://www.medikom.iocspublisher.org/index.php/JTI/article/download/1105/88)  
8. Assignment problem \- Wikipedia, accessed December 29, 2025, [https://en.wikipedia.org/wiki/Assignment\_problem](https://en.wikipedia.org/wiki/Assignment_problem)  
9. mindspore.scipy.optimize.linear\_sum\_assignment, accessed December 29, 2025, [https://www.mindspore.cn/docs/en/r2.3.0/api\_python/scipy/mindspore.scipy.optimize.linear\_sum\_assignment.html](https://www.mindspore.cn/docs/en/r2.3.0/api_python/scipy/mindspore.scipy.optimize.linear_sum_assignment.html)  
10. Assignment Problem: Hungarian Algorithm | PDF | Teaching Methods & Materials \- Scribd, accessed December 29, 2025, [https://www.scribd.com/doc/72286287/Hungarian](https://www.scribd.com/doc/72286287/Hungarian)  
11. Complexity of a 3-dimensional assignment problem \- AM FRIEZE, accessed December 29, 2025, [https://www.math.cmu.edu/\~af1p/Texfiles/3Dass.pdf](https://www.math.cmu.edu/~af1p/Texfiles/3Dass.pdf)  
12. LINEAR\_ASSIGNMENT \- Boardflare, accessed December 29, 2025, [https://www.boardflare.com/python-functions/solvers/optimization/assignment\_problems/linear\_assignment](https://www.boardflare.com/python-functions/solvers/optimization/assignment_problems/linear_assignment)  
13. Assignment Problem In Operation Research | using Hungarian Method | Lecture 01, accessed December 29, 2025, [https://www.youtube.com/watch?v=hEmq28glJM8](https://www.youtube.com/watch?v=hEmq28glJM8)  
14. Hungarian Maximum Matching Algorithm | Brilliant Math & Science Wiki, accessed December 29, 2025, [https://brilliant.org/wiki/hungarian-matching/](https://brilliant.org/wiki/hungarian-matching/)  
15. accessed December 29, 2025, [https://www.gotoassignmenthelp.com/blog/what-is-an-unbalanced-assignment-problem-how-it-is-solved-with-hungarian-method/\#:\~:text=Sometimes%2C%20in%20assignment%20problems%2C%20the,rows%20or%20columns%20as%20zero.](https://www.gotoassignmenthelp.com/blog/what-is-an-unbalanced-assignment-problem-how-it-is-solved-with-hungarian-method/#:~:text=Sometimes%2C%20in%20assignment%20problems%2C%20the,rows%20or%20columns%20as%20zero.)  
16. The bench myth: why resting athletes may not be as helpful as teams believe \- The Guardian, accessed December 29, 2025, [https://www.theguardian.com/sport/blog/2017/dec/13/the-bench-myth-why-resting-athletes-may-not-be-as-helpful-as-teams-believe](https://www.theguardian.com/sport/blog/2017/dec/13/the-bench-myth-why-resting-athletes-may-not-be-as-helpful-as-teams-believe)  
17. Hungarian algorithm in Python for non-square cost matrices \- Stack Overflow, accessed December 29, 2025, [https://stackoverflow.com/questions/69988671/hungarian-algorithm-in-python-for-non-square-cost-matrices](https://stackoverflow.com/questions/69988671/hungarian-algorithm-in-python-for-non-square-cost-matrices)  
18. (PDF) Solving the Unbalanced Assignment Problem: Simpler Is Better \- ResearchGate, accessed December 29, 2025, [https://www.researchgate.net/publication/304660743\_Solving\_the\_Unbalanced\_Assignment\_Problem\_Simpler\_Is\_Better](https://www.researchgate.net/publication/304660743_Solving_the_Unbalanced_Assignment_Problem_Simpler_Is_Better)  
19. Weight of attributes per role (and general spreadsheet geeking) \- Football Manager General Discussion \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/510157-weight-of-attributes-per-role-and-general-spreadsheet-geeking/](https://community.sports-interactive.com/forums/topic/510157-weight-of-attributes-per-role-and-general-spreadsheet-geeking/)  
20. Squad rotation \- How do you do it? \- Tactics, Training & Strategies ..., accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/576009-squad-rotation-how-do-you-do-it/](https://community.sports-interactive.com/forums/topic/576009-squad-rotation-how-do-you-do-it/)  
21. What's the lowest %condition you normally start a player in FM? 95%? 98%? \- Football Manager General Discussion \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/540512-whats-the-lowest-condition-you-normally-start-a-player-in-fm-95-98/](https://community.sports-interactive.com/forums/topic/540512-whats-the-lowest-condition-you-normally-start-a-player-in-fm-95-98/)  
22. How do you handle team rotation? \- Football Manager General Discussion, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/552508-how-do-you-handle-team-rotation/](https://community.sports-interactive.com/forums/topic/552508-how-do-you-handle-team-rotation/)  
23. Jadedness \- Football Manager General Discussion \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/86824-jadedness/](https://community.sports-interactive.com/forums/topic/86824-jadedness/)  
24. Player Fitness | Football Manager 2022 Guide, accessed December 29, 2025, [https://www.guidetofm.com/squad/fitness/](https://www.guidetofm.com/squad/fitness/)  
25. Why does linear\_sum\_assignment in scipy.optimize never return if one of the assignments must have a cost of Infinity?, accessed December 29, 2025, [https://stackoverflow.com/questions/42035999/why-does-linear-sum-assignment-in-scipy-optimize-never-return-if-one-of-the-assi](https://stackoverflow.com/questions/42035999/why-does-linear-sum-assignment-in-scipy-optimize-never-return-if-one-of-the-assi)  
26. Recovery–stress balance and injury risk in professional football players: a prospective study, accessed December 29, 2025, [https://www.tandfonline.com/doi/full/10.1080/02640414.2015.1064538](https://www.tandfonline.com/doi/full/10.1080/02640414.2015.1064538)  
27. Monitoring Fatigue and Recovery \- Gatorade Sports Science Institute, accessed December 29, 2025, [https://www.gssiweb.org/sports-science-exchange/article/sse-135-monitoring-fatigue-and-recovery](https://www.gssiweb.org/sports-science-exchange/article/sse-135-monitoring-fatigue-and-recovery)  
28. Assignment problems with changeover cost \- IDEAS/RePEc, accessed December 29, 2025, [https://ideas.repec.org/a/spr/annopr/v172y2009i1p447-45710.1007-s10479-009-0620-6.html](https://ideas.repec.org/a/spr/annopr/v172y2009i1p447-45710.1007-s10479-009-0620-6.html)  
29. Discrete assignment problem with penalties \- Computer Science Stack Exchange, accessed December 29, 2025, [https://cs.stackexchange.com/questions/69720/discrete-assignment-problem-with-penalties](https://cs.stackexchange.com/questions/69720/discrete-assignment-problem-with-penalties)  
30. Reformulating a Problem \- D-Wave Documentation, accessed December 29, 2025, [https://docs.dwavequantum.com/en/latest/quantum\_research/reformulating.html](https://docs.dwavequantum.com/en/latest/quantum_research/reformulating.html)  
31. Constrained optimization \- Wikipedia, accessed December 29, 2025, [https://en.wikipedia.org/wiki/Constrained\_optimization](https://en.wikipedia.org/wiki/Constrained_optimization)  
32. Disjoint-set data structure \- Wikipedia, accessed December 29, 2025, [https://en.wikipedia.org/wiki/Disjoint-set\_data\_structure](https://en.wikipedia.org/wiki/Disjoint-set_data_structure)  
33. How can I optimize the assignment of object sets to workers with pre-existing caches to minimize discrepancy? \- Theoretical Computer Science Stack Exchange, accessed December 29, 2025, [https://cstheory.stackexchange.com/questions/54185/how-can-i-optimize-the-assignment-of-object-sets-to-workers-with-pre-existing-ca](https://cstheory.stackexchange.com/questions/54185/how-can-i-optimize-the-assignment-of-object-sets-to-workers-with-pre-existing-ca)  
34. Python Infinity \- All you need to know | Flexiple Tutorials, accessed December 29, 2025, [https://flexiple.com/python/python-infinity](https://flexiple.com/python/python-infinity)  
35. linear\_sum\_assignment with infinite weights · Issue \#6900 · scipy/scipy \- GitHub, accessed December 29, 2025, [https://github.com/scipy/scipy/issues/6900](https://github.com/scipy/scipy/issues/6900)  
36. Algorithms for the Constrained Assignment Problems with Bounds and Maximum Penalty | Request PDF \- ResearchGate, accessed December 29, 2025, [https://www.researchgate.net/publication/384184466\_Algorithms\_for\_the\_Constrained\_Assignment\_Problems\_with\_Bounds\_and\_Maximum\_Penalty](https://www.researchgate.net/publication/384184466_Algorithms_for_the_Constrained_Assignment_Problems_with_Bounds_and_Maximum_Penalty)  
37. Penalties versus constraints in optimization problems \- The DO Loop \- SAS Blogs, accessed December 29, 2025, [https://blogs.sas.com/content/iml/2021/10/13/penalties-constraints-optimization.html](https://blogs.sas.com/content/iml/2021/10/13/penalties-constraints-optimization.html)  
38. Penalty & Barrier Methods in Optimization | Mathematical Methods for Optimization Class Notes \- Fiveable, accessed December 29, 2025, [https://fiveable.me/mathematical-methods-for-optimization/unit-14](https://fiveable.me/mathematical-methods-for-optimization/unit-14)  
39. Multi-objective optimization \- Wikipedia, accessed December 29, 2025, [https://en.wikipedia.org/wiki/Multi-objective\_optimization](https://en.wikipedia.org/wiki/Multi-objective_optimization)  
40. Multi-Objective Optimization For Football Team Member Selection | PDF \- Scribd, accessed December 29, 2025, [https://www.scribd.com/document/647248858/Multi-Objective-Optimization-for-Football-Team-Member-Selection](https://www.scribd.com/document/647248858/Multi-Objective-Optimization-for-Football-Team-Member-Selection)  
41. Scheduling the English Football League with a Multi-objective Evolutionary Algorithm \- Graham Kendall, accessed December 29, 2025, [https://www.graham-kendall.com/papers/wk2014.pdf](https://www.graham-kendall.com/papers/wk2014.pdf)  
42. What's the best rotation method for strong squads? : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1cv3a2t/whats\_the\_best\_rotation\_method\_for\_strong\_squads/](https://www.reddit.com/r/footballmanagergames/comments/1cv3a2t/whats_the_best_rotation_method_for_strong_squads/)  
43. Python scipy.optimize.linear\_sum\_assignment \- How to assign workers to jobs, accessed December 29, 2025, [https://stackoverflow.com/questions/78540210/python-scipy-optimize-linear-sum-assignment-how-to-assign-workers-to-jobs](https://stackoverflow.com/questions/78540210/python-scipy-optimize-linear-sum-assignment-how-to-assign-workers-to-jobs)  
44. Can the Hungarian method be used with real edge weights?, accessed December 29, 2025, [https://cstheory.stackexchange.com/questions/12541/can-the-hungarian-method-be-used-with-real-edge-weights](https://cstheory.stackexchange.com/questions/12541/can-the-hungarian-method-be-used-with-real-edge-weights)  
45. Football Analytics: Assessing the Correlation between Workload, Injury and Performance of Football Players in the English Premier League \- MDPI, accessed December 29, 2025, [https://www.mdpi.com/2076-3417/14/16/7217](https://www.mdpi.com/2076-3417/14/16/7217)  
46. The Hungarian Algorithm: The quest for the best lineup for football teams | by Andrea Grianti, accessed December 29, 2025, [https://andrea-grianti.medium.com/the-hungarian-algorithm-a-use-case-for-football-managers-2527ad3097ef](https://andrea-grianti.medium.com/the-hungarian-algorithm-a-use-case-for-football-managers-2527ad3097ef)