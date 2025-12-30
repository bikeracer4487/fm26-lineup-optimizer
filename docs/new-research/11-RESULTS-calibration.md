# **Systematic Calibration of Stochastic Squad Management Systems: An Operations Research Approach to Parameter Optimization**

## **1\. Introduction and Problem Statement**

The modern simulation of sports management, specifically within the domain of "Football Manager"-style squad systems, represents a highly complex stochastic resource allocation problem. Unlike static scheduling problems common in manufacturing or logistics, a squad management system must account for the biological volatility of the assets (the players), the probabilistic nature of performance outcomes, and the adversarial dynamics of competition. The objective is not merely to maximize a single metric, such as match points, but to optimize a multi-objective function that balances short-term competitive success against the long-term preservation of the squad's physiological capital.

The user has presented a system governed by approximately 50 tunable parameters. These include non-linear coefficients for fatigue accumulation (sigmoid multipliers $k, T$), tactical efficiency penalties (positional drag), temporal decay rates (sharpness, jadedness), and economic valuations of player utility (shadow prices). While the functional forms of these interactions—the "physics" of the simulation—have been established in prior research steps, the specific scalar values (coefficients) remain undefined. This report addresses the "Parameter Tuning Problem."

In Operations Research (OR) and Control Theory, a system with 50 interdependent parameters is widely considered to suffer from the "Curse of Dimensionality." A brute-force exploration of this parameter space is computationally intractable. Furthermore, the objective function is noisy; a "good" set of parameters might yield a poor season outcome simply due to bad luck (stochastic variance in injury rolls or match engine results). Therefore, a heuristic trial-and-error approach is insufficient.

This report establishes a rigorous, scientifically grounded methodology for calibrating these parameters. We propose a hybrid framework integrating **Global Sensitivity Analysis (GSA)** to reduce the search space, **Simulation-Based Optimization (SBO)** utilizing **Bayesian Optimization and Hyperband (BOHB)** for efficient parameter search, and **Rolling Horizon Decomposition** for the dynamic calibration of shadow prices. We validate these methods against specific stress-test scenarios: the "Christmas Crunch" (extreme schedule congestion) and the "Death Spiral" (cascading injury failure modes).

## **2\. Theoretical Framework: The Biomechanical and Tactical Constraints**

Before defining the tuning methodology, we must rigorously define the "physics" of the system we are tuning. The calibration of a parameter is meaningless without a clear understanding of the physiological or tactical reality it models. We classify the 50 parameters into three distinct ontological categories: Biological Constraints (Rigid), Tactical Variables (Elastic), and Strategic Valuations (Abstract).

### **2.1. Biological Constraints: The Sigmoid Nature of Risk**

The core of the simulation is the physiological state of the agent. The user query highlights the need to tune sigmoid multiplier coefficients ($k, T$). This requirement stems from the non-linear relationship between workload and injury risk.

#### **2.1.1. The Acute:Chronic Workload Ratio (ACWR)**

Research in sports science, particularly the work surrounding the Banister Impulse-Response model and subsequent ACWR studies, suggests that injury risk does not increase linearly with load. Instead, it follows a curve defined by the ratio of Acute Load (typically 1 week) to Chronic Load (typically 4 weeks).1

* **The "Sweet Spot" (0.8 – 1.3):** Empirical evidence suggests that when the Acute:Chronic ratio sits between 0.8 and 1.3, injury risk is minimized. In this zone, the athlete is "fit" (high chronic load) and "fresh" (manageable acute load).3  
* **The "Danger Zone" (\> 1.5):** As the ratio exceeds 1.5, the risk of non-contact injury (e.g., hamstring strains) rises exponentially. Studies on English Premier League players indicate that ratios \> 2.0 can increase injury risk by 5-7 times.5

#### **2.1.2. Sigmoid Parameterization ($k, T$)**

To model this in the system, we utilize a logistic (sigmoid) function to map the dimensionless ACWR metric to a probability of injury ($P\_{inj}$).

$$P\_{inj}(r) \= P\_{base} \+ \\frac{P\_{max} \- P\_{base}}{1 \+ e^{-k(r \- T)}}$$  
Where:

* $r$ is the ACWR value.  
* $T$ (Threshold/Midpoint) represents the inflection point where risk transitions from "manageable" to "dangerous." Based on the literature, this biological anchor point is expected to be near $r \= 1.5$.4  
* $k$ (Steepness) governs how strictly the system punishes violations of the sweet spot. A low $k$ implies a gradual increase in risk; a high $k$ creates a "cliff edge" where playing a fatigued player is almost guaranteed to result in injury.

**Calibration Challenge:** If $k$ is too high, the simulation becomes brittle (random injuries decimate squads). If $k$ is too low, the "Death Spiral" scenario never triggers because users can abuse players without consequence.

### **2.2. Positional Drag: The Metabolic Cost of Misallocation**

"Positional Drag" refers to the efficiency penalty applied when a player operates in a role they are not conditioned for. This is not merely a skill penalty but a physiological one. Different positions on the soccer field impose drastically different metabolic demands.

#### **2.2.1. Positional Profiles and High-Speed Running (HSR)**

Detailed time-motion analysis of elite soccer provides the ground truth for these parameters.

* **Fullbacks (FB) & Wide Midfielders (WM):** These positions are characterized by the highest volume of High-Speed Running (HSR) and sprint distances. Fullbacks often cover \>10% more sprint distance than other defensive roles due to the requirement to transition between defensive and offensive phases.6  
* **Center Backs (CB):** Conversely, Center Backs display the lowest physical outputs in terms of total distance and HSR. Their recovery times between high-intensity efforts are significantly longer.7  
* **Central Midfielders (CM):** Cover the highest *total* distance but often at lower peak velocities than wide players.9

#### **2.2.2. Drag Coefficient Formulation**

The parameter positional\_drag ($\\delta\_p$) defines the fatigue multiplier for a player of Position $A$ playing in Position $B$.

$$\\text{Fatigue}\_{accumulated} \= \\text{BaseLoad}\_B \\times (1 \+ \\delta\_p \\times \\text{Incompatibility}(A, B))$$

If a Center Back (low endurance, low sprint capacity) is forced to play Fullback (high sprint demand), the mismatch is severe. The Drag Coefficient must be calibrated to reflect the \~15-20% difference in high-intensity metabolic load.6 Conversely, a Fullback playing Center Back might suffer less physiological drag (as the load is lower) but high tactical drag (shadow pricing penalty due to poor positioning).

### **2.3. Temporal Dynamics: Sharpness and Jadedness**

The system dynamics are governed by two competing time-dependent variables: Fatigue (which accumulates and clears quickly) and Sharpness (which decays during inactivity).

* **Recovery Kinetics:** Post-match recovery markers (Creatine Kinase, Hormonal balance) typically return to baseline within 48 to 72 hours.12 However, this is non-linear; the first 80% of recovery happens faster than the final 20%. The "Christmas Crunch" scenario (games every 48-72 hours) explicitly targets this window where recovery is incomplete.3  
* **Sharpness Decay ($\\lambda\_{sharp}$):** Players who do not play lose "match sharpness," a multiplier on their technical attributes. Research into "detraining" suggests that while aerobic capacity is stable over weeks, the specific neuromuscular coordination for match-play degrades faster.14

### **2.4. Shadow Prices: The Economic Valuation of Condition**

In Operations Research, **Shadow Pricing** arises from the Dual of a Linear Programming (LP) problem. The Primal problem is "Select a squad to maximize win probability subject to constraints." The Dual problem asks, "What is the marginal cost of the constraints?"

The constraint here is the finite pool of Player Condition. The Shadow Price ($\\lambda\_i$) of Player $i$ represents the *opportunity cost* of using them in the current match.

* If a player is the only fit Left Back and there is a Cup Final in 3 days, their Shadow Price is effectively infinite (or extremely high). Using them in a low-priority league game is "expensive" because it consumes the scarce resource needed for the high-priority objective.15

**Calibration Goal:** We must tune the variables that calculate this price. If the shadow price is too low, the AI plays its best XI in the League Cup 1st Round. If too high, the AI plays youth players in critical matches to "save" the stars, potentially losing the game (and the manager's job).

## **3\. Phase 1: Dimensionality Reduction via Global Sensitivity Analysis (GSA)**

With $\\approx 50$ parameters, the calibration landscape is vast. A simple Grid Search (discretizing each parameter into 5 levels) would require $5^{50}$ simulations, which is computationally impossible. We must first identify which parameters truly drive system behavior and which are effectively inert.

### **3.1. Methodology Selection: Sobol Indices**

We reject the **Morris Method (One-at-a-Time)** despite its computational efficiency. The Morris method is qualitative; it ranks parameters but struggles to quantify the magnitude of interactions.17 In squad management, interaction is everything: *High Intensity* (Tactical) $\\times$ *Low Condition* (Biological) $\\times$ *High Importance* (Strategic) is the exact recipe for the "Death Spiral."

Instead, we employ **Variance-Based Sensitivity Analysis (Sobol Indices)**. This method decomposes the variance of the output (e.g., Total Season Points, Total Injury Days) into fractions attributable to each input parameter and their interactions.17

#### **3.1.1. The Sobol Decomposition**

We define the simulation model as a function $Y \= f(X\_1, X\_2, \\dots, X\_{50})$. The variance $V(Y)$ is decomposed as:

$$V(Y) \= \\sum\_i V\_i \+ \\sum\_{i\<j} V\_{ij} \+ \\sum\_{i\<j\<k} V\_{ijk} \+ \\dots$$

* **First-Order Index ($S\_i \= V\_i / V(Y)$):** The effect of parameter $X\_i$ alone.  
* **Total-Order Index ($S\_{Ti}$):** The effect of $X\_i$ plus all its interactions with other parameters.

### **3.2. Execution Strategy for GSA**

1. **Sampling:** We utilize **Saltelli's extension of Sobol sequences** to generate quasi-random sample points across the parameter space. This ensures better coverage than simple Monte Carlo sampling.18  
2. **Simulation Budget:** We require $N(k+2)$ evaluations, where $k$ is the number of parameters. For $k=50$ and $N=1000$, we need \~52,000 simulation runs. To make this feasible, we run these simulations on a "Lite" version of the match engine (abstracting play-by-play calculations into statistical outcomes) to reduce runtime from minutes to milliseconds.  
3. **Screening Criteria:**  
   * Parameters with $S\_{Ti} \< 0.01$ (explaining \<1% of output variance) are classified as **Non-Critical**. They will be fixed to nominal default values derived from literature and excluded from the heavy optimization phase.  
   * Parameters with High $S\_{Ti}$ but Low $S\_i$ are flagged as **Interaction-Dominant**. These are dangerous; they only matter in specific combinations (e.g., injury\_threshold only matters when training\_intensity is high).

### **3.3. Anticipated Outcomes**

Based on the structure of FM-style systems, we hypothesize that the **Sigmoid Midpoint ($T$)**, **Recovery Rate ($\\tau\_{rec}$)**, and **Match Importance Weights** will be the dominant parameters. Conversely, minor tactical tweaks like "Goalkeeper Positional Drag" will likely be screened out, as Goalkeepers rarely accumulate critical fatigue levels.7

## **4\. Phase 2: Simulation-Based Optimization (SBO) using BOHB**

Once the parameter set is reduced to the critical 15-20 variables, we move to the optimization phase. The goal is to find the vector $\\theta^\*$ that minimizes a loss function $L(\\theta)$ (or maximizes an objective $J(\\theta)$).

### **4.1. Why Genetic Algorithms (GA) are Insufficient**

Genetic Algorithms are popular for discrete optimization but suffer in this domain due to "noisy" fitness functions. A single season simulation is stochastic; a "good" parameter set might perform poorly due to bad RNG. GAs can be easily misled by this noise, converging on local optima that got "lucky." Furthermore, GAs are computationally expensive, as they typically require evaluating full populations at full fidelity.20

### **4.2. Why Bayesian Optimization (BO) is Superior**

Bayesian Optimization builds a probabilistic model (a "surrogate," typically a Gaussian Process or Tree-structured Parzen Estimator) of the objective function. It uses this model to intelligently select the next set of parameters to test, balancing **Exploration** (high uncertainty areas) and **Exploitation** (promising areas). It is far more sample-efficient than Grid or Random Search.23

### **4.3. The Chosen Engine: BOHB (Bayesian Optimization & Hyperband)**

We select **BOHB**, a state-of-the-art algorithm that combines the strengths of Bayesian Optimization with **Hyperband**.24

#### **4.3.1. The Hyperband Component**

Hyperband addresses the issue of expensive simulations. It uses a "Successive Halving" approach to resource allocation.

* **Rung 1:** Generate 100 random parameter configurations. Run them for a short horizon (e.g., 5 matches or 1 month of season).  
* **Pruning:** Discard the worst 50% based on short-term metrics (e.g., injury rate, points per game).  
* **Rung 2:** Run the surviving 50 configurations for double the horizon (10 matches).  
* **Pruning:** Discard the worst 50%.  
* **Rung 3:** Continue until the full horizon (Full Season) is reached with the elite candidates.

This ensures that we do not waste computation simulating a full season for a parameter set that causes a catastrophic injury crisis in Week 3\.

#### **4.3.2. The Bayesian Component (TPE)**

Standard Hyperband samples configurations randomly. BOHB replaces this random sampling with a Tree-structured Parzen Estimator (TPE). It builds a probability density function $l(x)$ for "good" parameters and $g(x)$ for "bad" parameters. It then samples new candidates that maximize the ratio $l(x)/g(x)$.  
This allows BOHB to "learn" the landscape of the Sigmoid coefficients and Shadow Prices, converging on the optimal region significantly faster than other methods.24

### **4.4. Objective Function Formulation**

The loss function for the optimizer must capture the conflicting goals of the system.

$$L(\\theta) \= \- \\left( w\_1 \\cdot \\frac{Pts}{Pts\_{max}} \+ w\_2 \\cdot \\frac{Cup}{Cup\_{max}} \\right) \+ w\_3 \\cdot P\_{injury} \+ w\_4 \\cdot \\Omega\_{stability}$$

Where:

* $Pts$: League points obtained.  
* $Cup$: Rounds progressed in cups.  
* $P\_{injury}$: Total days lost to injury (penalized).  
* $\\Omega\_{stability}$: A penalty term for "Death Spiral" behavior (e.g., variance in squad availability).

## **5\. Phase 3: The Rolling Horizon and Shadow Pricing**

While BOHB tunes the static physiological parameters, the dynamic decision-making logic (the AI Brain) relies on **Shadow Pricing**. This requires a distinct calibration approach rooted in Linear Programming Duality and Rolling Horizon Control.

### **5.1. Duality and Opportunity Cost**

The decision to field a player is an optimization problem. Let $x\_{i,t}$ be a binary variable (1 if player $i$ plays in match $t$).  
Primal Constraint: Player condition $C\_{i,t}$ must remain above a safety threshold $C\_{min}$.

$$C\_{i,t} \\ge C\_{min}$$

The Dual Variable ($\\lambda\_{i,t}$) associated with this constraint measures the sensitivity of the objective function to the condition capital.

* $\\lambda\_{i,t} \\approx \\frac{\\partial \\text{SeasonSuccess}}{\\partial C\_{i,t}}$  
* This $\\lambda$ is the **Shadow Price**. It represents the "cost" of fatigue.

Calibration: We do not tune $\\lambda$ directly as a static number. We tune the function that estimates $\\lambda$.

$$\\lambda\_{i,t} \= f(\\text{Importance}\_{t}, \\text{Scarcity}\_{i}, \\text{FutureLoad}\_{i})$$

Research suggests using Piecewise Linear Approximations to model this cost function to keep the optimization tractable (linearizing bilinear terms).28

### **5.2. Rolling Horizon Decomposition**

Because the full season is stochastic, we cannot calculate the true Shadow Price for Match 38 at Match 1\. We use **Rolling Horizon** (Model Predictive Control).

* **Horizon ($H$):** The AI looks ahead $H$ matches.  
* Discount Factor ($\\gamma$): Future matches are discounted by $\\gamma^k$.

  $$\\max \\sum\_{k=0}^{H} \\gamma^k \\cdot \\text{Utility}(Match\_{t+k})$$

**Calibration of $\\gamma$:**

* $\\gamma \\to 0$: Myopic behavior. AI plays best XI now, ignores Boxing Day congestion.  
* $\\gamma \\to 1$: Hoarding behavior. AI rests stars in winnable games for a future "perfect" match.  
* **Target:** We calibrate $\\gamma$ to match the **Rotation Frequency** of elite human managers. Data from the 2018 World Cup and Premier League suggests elite teams rotate significantly (7-8 players) only in the 3rd game of a congested week.30 We tune $\\gamma$ until the simulation replicates this emergent behavior.

## **6\. Validation Scenarios: Stress-Testing the Defaults**

A key requirement is robustness. The parameters must handle edge cases without breaking the simulation logic.

### **6.1. Scenario A: The "Christmas Crunch"**

**Context:** The English Premier League festive period is notorious for congestion. Example schedule: Dec 26, Dec 28, Jan 1, Jan 4 (4 games in 10 days).32

**Validation Protocol:**

1. **Input:** Force a schedule with gap vector $G \= $ days.  
2. **Constraint:** ACWR spikes will exceed 1.5 for starters if not rotated.34  
3. **Success Metrics:**  
   * **Rotation Index:** The system *must* utilize \> 18 unique starters. If $\< 14$, the *Fatigue Sensitivity* ($k$) is too low (risk is underestimated).  
   * **Injury Containment:** Total injury days should not exceed $2\\sigma$ of the baseline average.  
4. **Tuning Loop:** If the AI refuses to rotate, we do not just force rotation. We increase the **Shadow Price of Fatigue** during congestion. This is an economic lever: make the cost of playing a tired player higher than the value of winning the match.

### **6.2. Scenario B: The "Death Spiral"**

**Context:** A feedback loop where injuries force the manager to overplay the remaining fit players, leading to *their* injury, until the squad collapses (e.g., playing U18 players or playing wingers at center back).35

**Validation Protocol:**

1. **Input:** Artificially injure 4 key defensive players (e.g., 2 CBs, 1 LB, 1 RB) in Week 10\.  
2. **Behavioral Check:**  
   * **Bad Behavior:** The AI plays the remaining fit RB at CB for 90 minutes every game. Due to **Positional Drag**, this player fatigues faster, enters the "Danger Zone" ($ACWR \> 1.5$), and gets injured.  
   * **Good Behavior:** The AI recognizes the high Shadow Price of the remaining RB. It chooses to play a lower-quality U21 Center Back (who has low fatigue) rather than burning out the senior pro out of position.  
3. **Parameter Adjustment:** If the Death Spiral occurs, it indicates that **Positional Drag** ($\\delta\_p$) is set too low (underestimating the cost of out-of-position play) or the **Base Utility** of the U21 player is set too low (the AI thinks losing the RB is better than fielding the kid).

## **7\. Match Importance Weighting: The AHP Approach**

The Shadow Price logic relies on knowing *which* matches matter. A League Cup 3rd Round match has lower utility than a Champions League Semi-Final. We determine these weights using the **Analytic Hierarchy Process (AHP)**.

### **7.1. AHP Matrix Construction**

We construct a pairwise comparison matrix $A$ where $a\_{ij}$ represents the relative importance of Competition $i$ vs Competition $j$.36

**Table 1: Illustrative AHP Matrix for a Top-Tier European Club**

| Competition | Champions League (CL) | Domestic League (DL) | FA Cup (FAC) | League Cup (LC) |
| :---- | :---- | :---- | :---- | :---- |
| **CL** | 1 | 2 | 5 | 9 |
| **DL** | 1/2 | 1 | 3 | 7 |
| **FAC** | 1/5 | 1/3 | 1 | 3 |
| **LC** | 1/9 | 1/7 | 1/3 | 1 |

### **7.2. Deriving the Weights**

Using the eigenvector method, we calculate the priority vector $w$.

* $\\lambda\_{max}$ calculation ensures consistency (Consistency Ratio $CR \< 0.1$).37  
* Resulting Weights (approx): $W\_{CL} \\approx 0.50$, $W\_{DL} \\approx 0.30$, $W\_{FAC} \\approx 0.15$, $W\_{LC} \\approx 0.05$.

These scalar weights $W\_c$ are multiplied into the objective function of the Rolling Horizon solver. This ensures that the Shadow Price of a star player is 10x higher before a CL game than before a League Cup game, driving the AI to rotate naturally.

## **8\. Robust Defaults and Proposed Ranges**

Based on the physiological snippets and OR principles, we propose the following initialization ranges for the BOHB search.

**Table 2: Proposed Parameter Ranges for Calibration**

| Parameter Group | Parameter Name | Symbol | Proposed Range | Physiological/OR Justification |
| :---- | :---- | :---- | :---- | :---- |
| **Sigmoid Risk** | Steepness Coefficient | $k$ | $\[2.0, 8.0\]$ | Controls the "cliff edge" of risk. |
| **Sigmoid Risk** | Danger Threshold | $T$ | $\[1.3, 1.8\]$ | Aligns with ACWR "Danger Zone" starts \> 1.5.4 |
| **Decay** | Sharpness Decay Half-life | $H\_{sharp}$ | $$ days | "Detraining" effects on coordination.14 |
| **Drag** | Positional Drag (FB $\\to$ CB) | $\\delta\_{FB \\to CB}$ | $\[0.05, 0.15\]$ | Lower drag (moving to lower intensity role).7 |
| **Drag** | Positional Drag (CB $\\to$ FB) | $\\delta\_{CB \\to FB}$ | $\[0.20, 0.40\]$ | High drag (moving to high sprint role).6 |
| **Strategic** | Discount Factor | $\\gamma$ | $\[0.85, 0.98\]$ | Balances myopic vs. long-term planning.38 |
| **Strategic** | Shadow Price Convexity | $\\alpha$ | $\[1.5, 3.0\]$ | Makes fatigue cost non-linear as limits approach. |

## **9\. Comprehensive Research Roadmap**

### **Phase 1: Data Structuring (Weeks 1-2)**

* **Task 1.1:** Implement the "Lite" simulator for rapid iteration.  
* **Task 1.2:** Hard-code the "Ground Truth" tables for Recovery Kinetics (CK clearance curves) based on 12 to serve as the immutable biological baseline.

### **Phase 2: Sensitivity Screening (Weeks 3-4)**

* **Task 2.1:** Run 50,000 simulations using Sobol sequences.  
* **Task 2.2:** Compute Total-Order Indices ($S\_{Ti}$).  
* **Task 2.3:** Lock the bottom 30 parameters to their median values.

### **Phase 3: BOHB Optimization (Weeks 5-8)**

* **Task 3.1:** Deploy the BOHB algorithm on the critical 20 parameters.  
* **Task 3.2:** Run the optimization loop on a compute cluster (parallelized workers).  
* **Task 3.3:** Monitor the "Pareto Front" of Points vs. Injuries.

### **Phase 4: Strategic Tuning (Weeks 9-10)**

* **Task 4.1:** Calibrate the Shadow Price function using the Rolling Horizon solver.  
* **Task 4.2:** Tune $\\gamma$ to match the "Rotation Frequency" of elite datasets.30

### **Phase 5: Scenario Validation (Weeks 11-12)**

* **Task 5.1:** Run the "Christmas Crunch" and "Death Spiral" stress tests.  
* **Task 5.2:** Final adjustments to the **Emergency Reserve Valuation** parameters to ensure stability in crisis.

## **10\. Conclusion**

The calibration of a Football Manager-style squad management system is a non-trivial exercise in high-dimensional stochastic optimization. By moving beyond manual heuristics and adopting a rigorous Operations Research framework—specifically the integration of **Sobol Sensitivity Analysis** for feature selection, **BOHB** for biological parameter tuning, and **Rolling Horizon Duality** for strategic logic—we can create a system that is both realistic and robust.

This methodology ensures that the system respects the hard physiological limits of the human body (via the Sigmoid/ACWR logic) while replicating the nuanced, trade-off-based decision-making of a human manager (via Shadow Pricing). The resulting defaults, validated against the "Christmas Crunch" and "Death Spiral," will provide a stable, challenging, and scientifically plausible simulation experience.

### ---

**Table 3: Summary of Methodological Decisions**

| Component | Selected Method | Alternative Considered | Reason for Rejection |
| :---- | :---- | :---- | :---- |
| **Screening** | **Sobol Indices** | Morris Method | Morris fails to quantify interaction effects critical to "Death Spiral" dynamics.17 |
| **Optimization** | **BOHB** | Genetic Algorithms | GAs are inefficient with noisy objectives and expensive simulations.20 |
| **Strategic Logic** | **Rolling Horizon** | Reinforcement Learning | RL requires millions of episodes; Rolling Horizon is more interpretable and easier to calibrate.38 |
| **Match Weights** | **AHP** | Arbitrary Weights | AHP provides a consistent, mathematically sound hierarchy of importance.36 |

#### **Works cited**

1. How to use ACWR to optimize physical readiness, improve performance, and reduce injury risk. \- RYPT Blog, accessed December 30, 2025, [https://blog.rypt.app/sandc/acwr-optimize-training-load-reduce-injury-risk/](https://blog.rypt.app/sandc/acwr-optimize-training-load-reduce-injury-risk/)  
2. Acute:Chronic Workload Ratio \- Science for Sport, accessed December 30, 2025, [https://www.scienceforsport.com/acutechronic-workload-ratio/](https://www.scienceforsport.com/acutechronic-workload-ratio/)  
3. Acute to chronic workload ratio (ACWR) for predicting sports injury risk: a systematic review and meta-analysis \- PMC \- NIH, accessed December 30, 2025, [https://pmc.ncbi.nlm.nih.gov/articles/PMC12487117/](https://pmc.ncbi.nlm.nih.gov/articles/PMC12487117/)  
4. A Systematic Review on Utilizing the Acute to Chronic Workload Ratio for Injury Prevention among Professional Soccer Players \- MDPI, accessed December 30, 2025, [https://www.mdpi.com/2076-3417/14/11/4449](https://www.mdpi.com/2076-3417/14/11/4449)  
5. Spikes in acute:chronic workload ratio (ACWR) associated with a 5–7 times greater injury rate in English Premier League football players: a comprehensive 3-year study | British Journal of Sports Medicine, accessed December 30, 2025, [https://bjsm.bmj.com/content/54/12/731](https://bjsm.bmj.com/content/54/12/731)  
6. Evaluation of movement and physiological demands of full-back and center-back soccer players using global positioning systems \- ResearchGate, accessed December 30, 2025, [https://www.researchgate.net/publication/271319026\_Evaluation\_of\_movement\_and\_physiological\_demands\_of\_full-back\_and\_center-back\_soccer\_players\_using\_global\_positioning\_systems](https://www.researchgate.net/publication/271319026_Evaluation_of_movement_and_physiological_demands_of_full-back_and_center-back_soccer_players_using_global_positioning_systems)  
7. Physical match demands across different playing positions during transitional play and high-pressure activities in elite soccer \- PubMed Central, accessed December 30, 2025, [https://pmc.ncbi.nlm.nih.gov/articles/PMC10955741/](https://pmc.ncbi.nlm.nih.gov/articles/PMC10955741/)  
8. Positional training demands in the English Premier League and English Championship. A longitudinal study across consecutive seasons \- Termedia, accessed December 30, 2025, [https://www.termedia.pl/Positional-training-demands-in-the-English-Premier-League-and-English-r-nChampionship-A-longitudinal-study-across-consecutive-seasons,78,54009,1,1.html](https://www.termedia.pl/Positional-training-demands-in-the-English-Premier-League-and-English-r-nChampionship-A-longitudinal-study-across-consecutive-seasons,78,54009,1,1.html)  
9. Analysis of the distances covered in professional football competitions, accessed December 30, 2025, [https://football-observatory.com/Analysis-of-the-distances-covered-in-professional](https://football-observatory.com/Analysis-of-the-distances-covered-in-professional)  
10. Physical match demands across different playing positions during transitional play and high-pressure activities in elite soccer \- PubMed, accessed December 30, 2025, [https://pubmed.ncbi.nlm.nih.gov/38524824/](https://pubmed.ncbi.nlm.nih.gov/38524824/)  
11. Positional Variations in Match Day Distance \- PlayerData, accessed December 30, 2025, [https://www.playerdata.com/en-gb/blog/positional-variations-in-match-day-distance](https://www.playerdata.com/en-gb/blog/positional-variations-in-match-day-distance)  
12. Postmatch recovery of physical performance and biochemical markers in team ball sports: a systematic review, accessed December 30, 2025, [https://bmjopensem.bmj.com/content/4/1/e000264](https://bmjopensem.bmj.com/content/4/1/e000264)  
13. Running Performance of High-Level Soccer Player Positions Induces Significant Muscle Damage and Fatigue Up to 24 h Postgame \- PMC \- PubMed Central, accessed December 30, 2025, [https://pmc.ncbi.nlm.nih.gov/articles/PMC8477007/](https://pmc.ncbi.nlm.nih.gov/articles/PMC8477007/)  
14. Tips to Reduce Player Fatigue in Football Manager \- Load FM Writes, accessed December 30, 2025, [https://loadfm.wordpress.com/2023/08/14/tips-to-reduce-player-fatigue-in-football-manager/](https://loadfm.wordpress.com/2023/08/14/tips-to-reduce-player-fatigue-in-football-manager/)  
15. A ROLLING-HORIZON APPROACH FOR MULTI-PERIOD OPTIMIZATION LUKAS GLOMB, FRAUKE LIERS, FLORIAN R¨OSEL (CA) All authors, accessed December 30, 2025, [https://optimization-online.org/wp-content/uploads/2020/05/7809.pdf](https://optimization-online.org/wp-content/uploads/2020/05/7809.pdf)  
16. Constrained Optimization, Shadow Prices, Inefficient Markets, and Government Projects, accessed December 30, 2025, [https://eml.berkeley.edu/\~webfac/saez/e131\_s04/shadow.pdf](https://eml.berkeley.edu/~webfac/saez/e131_s04/shadow.pdf)  
17. Considerations and Caveats when Applying Global Sensitivity Analysis Methods to Physiologically Based Pharmacokinetic Models \- NIH, accessed December 30, 2025, [https://pmc.ncbi.nlm.nih.gov/articles/PMC7367914/](https://pmc.ncbi.nlm.nih.gov/articles/PMC7367914/)  
18. A Review and Comparison of Different Sensitivity Analysis Techniques in Practice \- arXiv, accessed December 30, 2025, [https://arxiv.org/html/2506.11471v1](https://arxiv.org/html/2506.11471v1)  
19. Morris Vs Sobol Method Global Sensitivity analysis \- Statistics \- Julia Discourse, accessed December 30, 2025, [https://discourse.julialang.org/t/morris-vs-sobol-method-global-sensitivity-analysis/83571](https://discourse.julialang.org/t/morris-vs-sobol-method-global-sensitivity-analysis/83571)  
20. Hyperparameter Optimization of Bayesian Neural Network Using Bayesian Optimization and Intelligent Feature Engineering for Load Forecasting \- MDPI, accessed December 30, 2025, [https://www.mdpi.com/1424-8220/22/12/4446](https://www.mdpi.com/1424-8220/22/12/4446)  
21. Hybrid Biogeography-Based Optimization for Integer Programming \- PMC \- PubMed Central, accessed December 30, 2025, [https://pmc.ncbi.nlm.nih.gov/articles/PMC4065689/](https://pmc.ncbi.nlm.nih.gov/articles/PMC4065689/)  
22. My question about the optimization of Genetic Algorithm? \- ResearchGate, accessed December 30, 2025, [https://www.researchgate.net/post/My\_question\_about\_the\_optimization\_of\_Genetic\_Algorithm](https://www.researchgate.net/post/My_question_about_the_optimization_of_Genetic_Algorithm)  
23. Hyperparameter search using Bayesian Optimization and an Evolutionary Algorithm, accessed December 30, 2025, [https://rohit10patel20.medium.com/hyperparameter-search-using-bayesian-optimization-and-an-evolutionary-algorithm-bdca6331de1c](https://rohit10patel20.medium.com/hyperparameter-search-using-bayesian-optimization-and-an-evolutionary-algorithm-bdca6331de1c)  
24. BOHB: Robust and Efficient Hyperparameter Optimization at Scale \- Machine Learning Lab, accessed December 30, 2025, [https://ml.informatik.uni-freiburg.de/wp-content/uploads/papers/18-ICML-BOHB.pdf](https://ml.informatik.uni-freiburg.de/wp-content/uploads/papers/18-ICML-BOHB.pdf)  
25. Hyperband Hyperparameter Optimization | by Hey Amit \- Medium, accessed December 30, 2025, [https://medium.com/@heyamit10/hyperband-hyperparameter-optimization-d7bd66faa8e8](https://medium.com/@heyamit10/hyperband-hyperparameter-optimization-d7bd66faa8e8)  
26. A System for Massively Parallel Hyperparameter Tuning \- arXiv, accessed December 30, 2025, [https://arxiv.org/pdf/1810.05934](https://arxiv.org/pdf/1810.05934)  
27. BOHB: Robust and Efficient Hyperparameter Optimization at Scale \- Proceedings of Machine Learning Research, accessed December 30, 2025, [https://proceedings.mlr.press/v80/falkner18a/falkner18a.pdf](https://proceedings.mlr.press/v80/falkner18a/falkner18a.pdf)  
28. Linearizing Bilinear Products of Shadow Prices and Dispatch Variables in Bilevel Problems for Optimal Power System Planning and Operations \- National Renewable Energy Laboratory Research Hub, accessed December 30, 2025, [https://research-hub.nrel.gov/en/publications/linearizing-bilinear-products-of-shadow-prices-and-dispatch-varia/](https://research-hub.nrel.gov/en/publications/linearizing-bilinear-products-of-shadow-prices-and-dispatch-varia/)  
29. Linearizing Bilinear Products of Shadow Prices and Dispatch Variables in Bilevel Problems for Optimal Power System Planning and \- NREL, accessed December 30, 2025, [https://docs.nrel.gov/docs/fy23osti/80820.pdf](https://docs.nrel.gov/docs/fy23osti/80820.pdf)  
30. The Effect of Squad Rotation on Physical Activity at the 2018 World Cup in Russia. Analysis the Most Exploited Players of the 4 Best Teams \- NIH, accessed December 30, 2025, [https://pmc.ncbi.nlm.nih.gov/articles/PMC8484307/](https://pmc.ncbi.nlm.nih.gov/articles/PMC8484307/)  
31. (PDF) The rotation strategy in high-level European soccer teams \- ResearchGate, accessed December 30, 2025, [https://www.researchgate.net/publication/338230371\_The\_rotation\_strategy\_in\_high-level\_European\_soccer\_teams](https://www.researchgate.net/publication/338230371_The_rotation_strategy_in_high-level_European_soccer_teams)  
32. Must-Watch Premier League 2025/26 Fixtures During the Christmas & New Year Break, accessed December 30, 2025, [https://www.1boxoffice.com/en/blog/must-watch-epl-fixtures-during-christmas-new-year-break](https://www.1boxoffice.com/en/blog/must-watch-epl-fixtures-during-christmas-new-year-break)  
33. Every Premier League Festive Fixture This Season (2024/2025) \- GiveMeSport, accessed December 30, 2025, [https://www.givemesport.com/premier-league-every-festive-fixture-this-season/](https://www.givemesport.com/premier-league-every-festive-fixture-this-season/)  
34. The Relationship Between Acute: Chronic Workload Ratios and Injury Risk in Sports: A Systematic Review \- PMC \- NIH, accessed December 30, 2025, [https://pmc.ncbi.nlm.nih.gov/articles/PMC7047972/](https://pmc.ncbi.nlm.nih.gov/articles/PMC7047972/)  
35. A framework for player movement analysis in team sports \- PMC \- PubMed Central, accessed December 30, 2025, [https://pmc.ncbi.nlm.nih.gov/articles/PMC11334162/](https://pmc.ncbi.nlm.nih.gov/articles/PMC11334162/)  
36. Use of the Analytic Hierarchy Process and Selected Methods in the Managerial Decision-Making Process in the Context of Sustainable Development \- MDPI, accessed December 30, 2025, [https://www.mdpi.com/2071-1050/14/18/11546](https://www.mdpi.com/2071-1050/14/18/11546)  
37. A mathematical model using AHP priorities for soccer player selection \- SciELO South Africa, accessed December 30, 2025, [https://scielo.org.za/scielo.php?script=sci\_arttext\&pid=S2224-78902016000200016](https://scielo.org.za/scielo.php?script=sci_arttext&pid=S2224-78902016000200016)  
38. POLICIES \- CASTLE, accessed December 30, 2025, [https://castle.princeton.edu/Papers/Powell\_ADP\_2ndEdition\_Chapter%206.pdf](https://castle.princeton.edu/Papers/Powell_ADP_2ndEdition_Chapter%206.pdf)