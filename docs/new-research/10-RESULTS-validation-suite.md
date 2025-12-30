# **Validation Framework for FM26-Grade Squad Management Algorithms**

## **1\. Introduction: The Epistemology of Simulation Validation**

The development of algorithmic heuristics for *Football Manager* (FM) style squad management presents a unique, multi-layered challenge within the field of Operations Research. Unlike classical industrial scheduling problems—where "optimality" is often defined by singular, deterministic cost functions such as maximizing throughput or minimizing latency—squad management operates within a highly stochastic, multi-objective environment. The "optimal" decision is frequently obscured by the "fog of war" inherent in the match engine's variance, the physiological complexities of human agents (players), and the long-term strategic ramifications of short-term actions. We cannot simply execute the game engine ten thousand times to validate a single substitution decision; the computational cost is prohibitive, and the signal-to-noise ratio is insufficiently high to isolate algorithmic performance from random match events.

Consequently, the validation methodology must evolve beyond simple outcome-based testing (e.g., "Did the team win the league?") toward a rigorous, **process-based validation** framework. This approach mandates verifying that the algorithm’s internal logic adheres strictly to a set of proxy metrics derived from deep domain expertise. The core philosophy rests on **Proxy Utility Maximization**: given that we cannot directly measure "wins" during the heuristic development phase, we measure the system's ability to maximize "Aggregate Team Strength" (ATS) under a complex web of constraints. A valid algorithm is defined not merely by its results, but by its adherence to physiological, psychological, and strategic imperatives—maximizing ATS while strictly respecting fatigue thresholds, morale dynamics, and player development curves.

This report establishes a comprehensive "Validation Test Suite" designed to rigorously stress-test the four pillars of our simulation engine: the Global Selection Score (GSS) formula, the state propagation engine (fatigue dynamics), the linear optimization solver (Hungarian/MILP), and the inter-temporal shadow pricing mechanisms. By defining precise test scenarios, expected physiological trajectories, and failure conditions, we aim to ensure that the automated assistant demonstrates the nuance, foresight, and adaptability of an expert human manager.

## ---

**2\. The Global Selection Score (GSS): Atomic Utility Validation**

The Global Selection Score (GSS) serves as the atomic unit of decision-making within the system. It transforms a high-dimensional vector of player attributes, physical states, and contextual factors into a single scalar value representing the utility of playing Player $P$ in Role $R$ at Time $T$. The integrity of the entire simulation rests on the accuracy of this transformation.

The governing equation is defined as:

$$GSS \= BPS \\times \\Phi(C) \\times \\Psi(S) \\times \\Theta(F) \\times \\Omega(J)$$  
Validating this formula requires a reductionist approach: we must decompose it into its constituent multipliers, verifying that each behaves correctly in isolation before testing their interaction in complex scenarios.

### **2.1 Base Performance Score (BPS) and Attribute Weighting**

The foundation of the GSS is the Base Performance Score (BPS). In the vernacular of *Football Manager*, this is often conflated with Current Ability (CA). However, our validation regime must ensure BPS reflects **Effective Ability**—the weighted sum of attributes relevant strictly to the specific role in question. A high CA player who is ill-suited to a specific tactical role must yield a lower BPS than a lower CA specialist.

#### **2.1.1 Attribute Weighting Validation Protocols**

Research into attribute distribution highlights that the FM engine weights attributes based on positional requirements.1 A "Winger" relies heavily on Dribbling, Acceleration, and Crossing, while a "Center Back" relies on Positioning, Jumping Reach, and Strength. The validation suite must confirm that our BPS calculation mirrors this non-uniform value distribution.

Validation Protocol 1: The Specialist vs. Generalist Test  
This test is designed to catch "CA Bias," where the algorithm lazily selects the player with the highest overall rating rather than the best fit for the tactical instructions.

* **Hypothesis:** A specialist with lower overall CA but higher key attributes for a specific role should generate a higher BPS than a generalist with higher CA but mediocre key attributes.  
* **Test Setup:**  
  * **Player A (The Specialist):** CA 130\. Acceleration 17, Dribbling 16, Crossing 15\. All other stats \~10. Role: Winger (Attack).  
  * **Player B (The Generalist):** CA 150\. All stats \~14. Role: Winger (Attack).  
* **Expected Outcome:** $BPS(Player A) \> BPS(Player B)$.  
* **Pass Criteria:** Player A's BPS must exceed Player B's by at least 5%.  
* **Failure Analysis:** If Player B scores higher, the weighting schema is overvaluing "irrelevant" attributes (like Tackling or Marking for a Winger) or undervaluing the non-linear impact of elite (16+) attributes. This would suggest the weighting coefficients need sharpening—potentially moving from linear weights to exponential weights to better capture the premium of elite talent.

#### **2.1.2 Hidden Attribute Integration**

The BPS must also account for hidden attributes such as Consistency and Important Matches, which act as modifiers to the visible technical and mental stats.3

Validation Protocol 2: The Reliability Coefficient  
This test ensures that the system penalizes volatility. A player who performs at an 8/10 every week is more valuable than one who oscillates between 9/10 and 4/10.

* **Test Setup:** Compare two identical players where Player A has Consistency 18 and Player B has Consistency 8\.  
* **Constraint:** The validation logic must apply a penalty to Player B *before* the match simulation logic runs.  
* Formula Check: The system should calculate a Reliability\_Coefficient $\\rho$:

  $$\\rho \= 1 \- \\frac{20 \- Consistency}{K\_{cons}}$$

  Where $K\_{cons}$ is a tuning parameter (typically \~40).  
* **Metric:** Ensure $BPS\_{adj} \= BPS\_{raw} \\times \\rho$.  
* **Pass Criteria:** Player A should have a distinct BPS advantage ($\> 10\\%$) reflecting the risk premium associated with Player B.

### **2.2 The Condition Multiplier $\\Phi(C)$ and the "91% Floor"**

The Condition multiplier $\\Phi(C)$ is the primary safeguard against acute injury risk. The validation mandate establishes a "91% Floor," meaning players below this threshold should be aggressively penalized to prevent them from starting matches, barring an emergency.

Mathematical Model:  
The proposed sigmoid function is $\\Phi(c) \= \\frac{1}{1 \+ e^{-25(c \- 0.88)}}$.  
This function creates a steep drop-off, modeling the non-linear increase in injury risk as fatigue accumulates.

* At $c=0.96$ (96%), $\\Phi \\approx 1.0$.  
* At $c=0.91$ (91%), $\\Phi \\approx 0.68$.  
* At $c=0.88$ (88%), $\\Phi \= 0.5$.

**Validation Protocol 3: Condition Cliff Sensitivity**

* **Objective:** Verify that the penalty is severe enough to force rotation but not so severe that it prevents emergency usage (e.g., in a "Left Back Crisis" where all options are tired).  
* **Test Scenario:**  
  * **Starter:** Condition 90%. BPS 160\.  
  * **Backup:** Condition 100%. BPS 120\.  
* **Calculation:**  
  * Starter Utility $\\approx 160 \\times 0.62$ (assuming adjusted sigmoid values) $\\approx 99.2$.  
  * Backup Utility $= 120 \\times 1.0 \= 120$.  
* **Outcome:** The system *must* select the Backup.  
* **Edge Case Test (The "Cup Final" Override):** If the match importance is "High" (Final Importance Score \> 90), does the system allow the 90% condition player? This requires checking if the GSS formula allows for contextual overrides or if the sigmoid parameters shift based on match importance.  
  * *Correction Logic:* The GSS formula itself is static. Contextual overrides should occur via **Shadow Pricing** (reducing the future cost of injury) or **Threshold Adjustment**. The test must verify that the *Simplex Solver* respects the GSS reduction but that a high enough Base Utility might still overcome the penalty in extreme cases.

### **2.3 The Sharpness Multiplier $\\Psi(S)$ and the "Seven-Day Cliff"**

Sharpness is the inverse of rustiness. A player who is physically fit (Condition 100%) but lacks match practice (Sharpness \< 50%) is liable to make mental errors and perform poorly. The prompt identifies a "Seven-Day Cliff" where sharpness decays rapidly after a week of inactivity.

Mathematical Model:  
$\\Psi(s) \= \\frac{1.02}{1 \+ e^{-15(s \- 0.75)}} \- 0.02$.  
This function ensures that sharpness below 75% renders a player significantly less effective, encouraging the use of "Reserve" fixtures or friendlies to build match fitness.  
**Validation Protocol 4: The Rust Accumulation Trajectory**

* **Setup:** A player rests for 21 days (3 weeks).  
* **Timeline Check:**  
  * Day 0-3: Sharpness remains 100% (Decay \= 0).  
  * Day 4-7: Slight decay (\~2%). Sharpness $\\approx$ 98%.  
  * Day 14: "Cliff" effect active. Sharpness should drop to \~85-90%.  
  * Day 21: Severe rust. Sharpness should be \< 75% (decay of 5-8% per day after Day 7).  
* **Test Execution:** Run a PlayerState simulation forward in time with no match events. Assert the sharpness value at $T+21$ is within the target range.  
* **Actionable Insight:** If sharpness remains \> 90% after 3 weeks, the decay coefficient is too low. This will lead to simulated managers failing to arrange friendlies during international breaks, resulting in "undercooked" players for the next league match. The validation must confirm that the decay is aggressive enough to trigger the "Need Match Fitness" heuristic.

### **2.4 The Fatigue Step Function $\\Omega(J)$**

Fatigue (Jadedness) differs from Condition. Condition is acute energy; Jadedness is chronic burnout. We model this as a discrete step function rather than a continuous curve to represent the sudden onset of "hitting the wall."

**Validation Protocol 5: The Jadedness Threshold Gate**

* **Thresholds:**  
  * Fresh ($J \< 200$): $\\Omega \= 1.0$  
  * Match Fit ($200 \\le J \< 400$): $\\Omega \= 0.9$  
  * Tired ($400 \\le J \< 700$): $\\Omega \= 0.7$  
  * Jaded ($J \\ge 700$): $\\Omega \= 0.4$  
* **Scenario:** A "Workhorse" player (Natural Fitness 18\) accumulates 650 Jadedness points.  
* **Test:** The system must apply the 0.7 multiplier.  
* **Conflict Detection:** It is crucial to verify that high Natural Fitness reduces *Jadedness accumulation* rates, not the *penalty thresholds*. The thresholds are absolute physiological markers.  
  * *Insight:* In our model, Natural Fitness acts on the derivative $\\frac{dJ}{dt}$. A player with Natural Fitness 20 accumulates Jadedness slower, but once they reach $J=700$, they are just as "Jaded" as a player with Natural Fitness 5\. This distinction is vital for validation. We test that the Workhorse accumulates $J$ slower, not that they ignore the $\\Omega$ penalty.

## ---

**3\. State Propagation and Fatigue Dynamics**

To accurately predict future GSS and make informed rotation decisions, we must validate the "Physics Engine" of our simulation—the set of rules governing how players accrue fatigue and lose condition over time.

### **3.1 Positional Drag Coefficients**

Not all minutes are created equal. A goalkeeper playing 90 minutes exerts significantly less energy than a wing-back or a box-to-box midfielder. The system must account for this via Positional Drag Coefficients ($R\_{pos}$).

**Validation Protocol 6: Positional Fatigue Rates**

* **Data:**  
  * $R\_{pos}(GK) \= 0.2$  
  * $R\_{pos}(CB) \= 1.0$ (Baseline)  
  * $R\_{pos}(WB) \= 1.65$ (High Intensity)  
* **Test:** Simulate 3 matches in 7 days (270 minutes total).  
* **Expected Jadedness Accumulation:**  
  * $J\_{GK} \\approx 270 \\times 0.2 \= 54$ (Still in "Fresh" zone).  
  * $J\_{CB} \\approx 270 \\times 1.0 \= 270$ (In "Match Fit" zone).  
  * $J\_{WB} \\approx 270 \\times 1.65 \= 445.5$ (In "Tired" zone).  
* **Implication:** The Wing-Back *must* rotate by the 3rd match, whereas the CB and GK can likely continue. A failure here (e.g., WB still labeled "Fresh") implies the coefficients are too compressed, leading to catastrophic AI roster management in congested periods where fullbacks will burn out and suffer injuries.

### **3.2 The 270-Minute Rule (Refined)**

The "270-Minute Rule" is a heuristic derived from sports science (Acute:Chronic Workload Ratio) suggesting injury risk spikes exponentially if a player exceeds \~3 full matches in a short window.

**Validation Protocol 7: The Congestion Trigger**

* **Constraint:** Window \= 14 days. Limit \= 270 minutes.  
* **Penalty Mechanism:** If $Min\_{14d} \> 270$, Jadedness accumulation rate multiplies by 2.5x.  
* **Test Case:**  
  * Player plays Match 1 (90 mins), Match 2 (90 mins), Match 3 (90 mins) within 10 days. Total \= 270\.  
  * Player is scheduled for Match 4 on Day 13\.  
* **Logic Check:**  
  * Current minutes \= 270\. Threshold met.  
  * Simulate Match 4 play.  
  * Standard J cost would be $\\approx 100$.  
  * With Penalty: J cost $\\approx 100 \\times 2.5 \= 250$.  
* **Result:** The simulation must show a massive spike in Jadedness after Match 4, likely pushing the player immediately into the "Jaded" ($\>700$) state. The validator checks that the *marginal* cost of the 4th match was correctly inflated, acting as a soft barrier to overuse.

### **3.3 Recovery Protocols: Holiday vs. Rest**

Effective squad management involves knowing when to remove a player entirely from the environment.

**Validation Protocol 8: The Recovery Rate Differential**

* **Hypothesis:** Sending a player on "Holiday" (removing them from training entirely) recovers Jadedness significantly faster than simple bench rest (where they still participate in training sessions).  
* **Rates:**  
  * Rest at Club: \~5 points/day.  
  * Holiday: \~50 points/day.  
* **Scenario:** Player is Jaded ($J=800$).  
* **Test A (Bench):** 1 week rest. Recovery $\\approx 35$. End State $J=765$ (Still Jaded).  
* **Test B (Holiday):** 1 week holiday. Recovery $\\approx 350$. End State $J=450$ (Tired, approaching Match Fit).  
* **Decision Logic:** The optimizer should recommend "Holiday" for any player with $J \> 700$ if the schedule permits a 1-week absence. The validation suite must confirm that the AI suggests this action rather than keeping the player at the club where recovery is inefficient.

## ---

**4\. Optimization Engine Validation (Hungarian & Big M)**

The core of the selection process is the assignment problem: mapping $N$ players to 11 slots to maximize $\\sum GSS$. While the Hungarian Algorithm is the standard for $N \\times N$ assignment, our problem involves side constraints (e.g., "Max 5 foreign players") that often require Mixed-Integer Linear Programming (MILP).

### **4.1 Solver Selection and Unit Testing**

We utilize scipy.optimize.linear\_sum\_assignment for base assignment and scipy.optimize.milp or pulp for constrained problems.

**Validation Protocol 9: Solver Correctness**

* **Unit Test:** Create a $15 \\times 11$ cost matrix where the optimal solution is known (manually calculated or derived from a brute-force solver on a small subset).  
* **Execution:** Run the Python solver.  
* **Check:** Does the solver return the exact set of indices corresponding to the global maximum?  
* **Shadow Price Extraction:**  
  * Standard Hungarian solvers do not natively return shadow prices (dual variables).4  
  * **Workaround Validation:** We must validate a "perturbation method" to extract shadow prices.  
  * *Test:* Increase the utility of a non-selected player by $\\epsilon$. Does the objective function value change? If not, the shadow price is 0\. If it requires a pivot, the shadow price represents the opportunity cost. The validation suite must automate this check to ensure we have accurate "Marginal Value" data for bench selection.

### **4.2 "Big M" and Safe Constraints**

In Operations Research, hard constraints (e.g., "Player A *cannot* play GK") are often modeled by assigning a cost of $-\\infty$ or a "Big M" penalty.

**Validation Protocol 10: The Safe Big M**

* **Risk:** Using float('inf') can cause numerical instability in some solvers.6  
* **Implementation:** Set $M \= 10^6$ (sufficiently larger than any possible GSS sum, which is $\\approx 11 \\times 200 \= 2200$, but small enough to avoid overflow).  
* **Test:**  
  * Constraint: Player X cannot play GK.  
  * Matrix setup: $Utility(X, GK) \= \-10^6$.  
  * Scenario: All other GKs are injured.  
  * Result: The solver should *still* avoid assigning X to GK unless strictly impossible. If impossible (all GKs injured), the objective value will be negative.  
* **Pass Criteria:** The validation suite must detect the negative objective value and flag a "Constraint Violation Warning" rather than crashing with a "No Solution" error. This ensures graceful degradation of the AI in crisis scenarios.

### **4.3 Multi-Objective Scalarization**

We optimize for multiple competing goals: Win Now ($w\_1$), Develop Youth ($w\_2$), Manage Fatigue ($w\_3$).

**Validation Protocol 11: Scalarization Weight Sensitivity**

* **Objective Function:** $Z \= w\_1 \\cdot ATS \+ w\_2 \\cdot DevBonus \+ w\_3 \\cdot RotationScore$.  
* **Scenario A (Cup Final):** $w\_1 \= 1.0, w\_2 \= 0.0, w\_3 \= 0.0$.  
  * *Result:* Best XI selected regardless of age or fatigue.  
* **Scenario B (Dead Rubber):** $w\_1 \= 0.2, w\_2 \= 0.8$.  
  * *Result:* High-potential youth players selected over veterans, even if Current Ability is lower.  
* **Test Metric:** Calculate the "Youth Selection Rate" across 100 simulations as $w\_2$ increases from 0.0 to 1.0. The relationship should be monotonic positive. The validation plots this curve to ensure linearity in the scalarization; a step-function response would indicate issues with the underlying utility magnitudes (e.g., Development Bonus being too small relative to ATS).

## ---

**5\. Shadow Pricing and Opportunity Cost Research**

This section addresses the most advanced component of the validation suite. Shadow prices represent the *marginal value of a resource*—in this case, a player's condition or availability. Understanding the cost of playing a star player today in terms of their lost utility tomorrow is crucial for inter-temporal optimization.

### **5.1 Theoretical Validation of Integer Shadow Prices**

Standard Linear Programming (LP) provides dual variables (shadow prices) automatically. However, squad selection is an Integer Program (IP). In IP, the shadow price is defined by the "convex hull" or via Lagrangian Relaxation.7

**Validation Protocol 12: The Lagrangian Dual Test**

* **Concept:** We relax the constraint "Player X can only play once in 3 days" into the objective function with a penalty multiplier $\\lambda$ (Lagrange multiplier).  
* **Test:**  
  * Solve the relaxed problem iteratively.  
  * Adjust $\\lambda$ until the constraint is satisfied.  
  * The final $\\lambda$ is the valid shadow price.  
* **Insight:** This value $\\lambda$ tells us exactly how much "utility" we lose by resting the player. If $\\lambda \> GSS(Replacement)$, then resting the player is a net negative *for this specific match*. However, if $\\lambda$ is lower than the *Future Value* of the player (derived from the Schedule Importance), then resting is optimal.

### **5.2 Scenario: Cup Final Protection (Trajectory Bifurcation)**

This scenario tests the system's ability to look ahead and sacrifice short-term utility for a major future payoff.

**Validation Protocol 13: Trajectory Bifurcation**

* **Setup:**  
  * Match 3: League (Low Importance).  
  * Match 5: Cup Final (Importance 10.0).  
  * Star Player: Kevin De Bruyne (KDB).  
* **Logic:**  
  * Calculate $ShadowCost(KDB, Match3)$.  
  * This cost must include the *probability* that playing in Match 3 reduces his GSS for Match 5 (via Condition \< 100% or Jadedness).  
  * Formula: $Cost \= P(Play\_{M3} \\to Suboptimal\_{M5}) \\times (Utility\_{M5}^{Full} \- Utility\_{M5}^{Tired}) \\times Weight\_{M5}$.  
* **Pass Criteria:**  
  * The shadow cost calculated for KDB in Match 3 must exceed his direct utility contribution to Match 3\.  
  * The solver must therefore choose to bench him in Match 3\.  
  * The validation suite confirms that $Utility(KDB, M3) \< ShadowCost(KDB, M3)$.

### **5.3 VORP Scarcity Index**

Value Over Replacement Player (VORP) determines how "irreplaceable" a player is. The shadow cost of a player should be proportional to the drop-off to their backup.

**Validation Protocol 14: The Scarcity Gap**

* **Calculation:** For each position, calculate $Gap\\% \= \\frac{GSS(Starter) \- GSS(Backup)}{GSS(Starter)}$.  
* **Test:**  
  * Player A (Star LB): Gap \= 30% (No good backup).  
  * Player B (Star CM): Gap \= 5% (Good backup).  
* **Shadow Price Correlation:** The shadow price for Player A must be significantly higher than for Player B.  
* **Trend Analysis:** The validation suite plots ShadowPrice vs. Gap%. The correlation coefficient $r$ should be $\> 0.8$. If not, the system is underestimating the risk of losing the unique asset (Player A). This ensures the AI prioritizes protecting the "uniques" over the "generics."

## ---

**6\. Position Training and Retraining Heuristics**

When depth is compromised, the system must recommend retraining or "out-of-position" usage. This section validates the heuristics for adaptation.

### **6.1 Gap Severity Index (GSI)**

The Gap Severity Index quantifies the urgency of a squad depth issue.

$$GSI \= (Scarcity\_{pos} \\times Weight\_{pos}) \+ InjuryRisk\_{starter} \+ ScheduleDensity$$  
**Validation Protocol 15: Gap Detection Sensitivity**

* **Input:** Squad with 1 Natural LB, 0 Backups.  
* **Event:** Natural LB gets injured for 3 weeks.  
* **Result:** GSI for LB position spikes to \> 0.9 (Critical).  
* **Action:** The system must trigger a "Candidate Search" for retraining.  
* **Negative Test:** If there are 4 Natural CBs, an injury to one should yield a low GSI (\< 0.3), triggering no action.

### **6.2 Euclidean Distance Candidate Selection**

How do we pick who to retrain? We treat player attributes as a vector in $N$-dimensional space and find the closest match to the target role profile.

**Validation Protocol 16: The Mascherano Protocol (DM to CB)**

* **Target Profile (CB):** High Tackling, Heading, Positioning, Strength.  
* **Candidate (DM):** High Tackling, Positioning, Strength. Moderate Heading.  
* **Metric:** Euclidean Distance $d(u, v) \= \\sqrt{\\sum (u\_i \- v\_i)^2}$.  
* **Test:**  
  * Compare DM candidate distance to CB profile vs. ST candidate distance to CB profile.  
  * Pass: $d(DM, CB) \\ll d(ST, CB)$.  
* **Archetype Validation:**  
  * The system should identify "Archetypes" to refine the suggestion.  
  * **Mascherano Archetype:** High Defensive stats, low height/jumping.  
  * **Recommendation:** The system should suggest retraining to "Ball Playing Defender" or "Libero," *not* "No-Nonsense CB" (which requires Jumping). The validation checks that the specific *Role* suggestion minimizes the distance vector.

### **6.3 Retraining Efficiency and Age Plasticity**

Old players learn new tricks slowly. The validation must enforce this reality.

**Validation Protocol 17: The Age Plasticity Constraint**

* **Model:** $Plasticity(Age) \= \\max(0.1, 1.0 \- \\frac{Age \- 18}{15})$.  
* **Test:**  
  * Candidate A: Age 19\. Plasticity $\\approx 0.93$.  
  * Candidate B: Age 32\. Plasticity $\\approx 0.1$.  
* **Scenario:** Attempt to retrain both from ST to AMR.  
* **Expected Output:**  
  * Candidate A: "Recommended (Class II Conversion \- 12 weeks)."  
  * Candidate B: "Rejected (Low Plasticity \- inefficient)."  
* **Failure Mode:** If the system recommends retraining a 32-year-old, it wastes Current Ability points (CA) on a new position that will never reach familiarity. The test ensures the AI avoids this "sunk cost" trap.

## ---

**7\. Player Removal and Roster Management**

Squad management is as much about who leaves as who stays. This section validates the logic for selling and loaning players.

### **7.1 Contribution Score Validation**

The Contribution Score dictates the "keep/sell" logic.

**Validation Protocol 18: Effective Ability vs. Raw CA**

* **Setup:**  
  * Player A: CA 150\. Poor distribution (High Finishing for a CB).  
  * Player B: CA 130\. Optimized distribution (High Tackling/Heading for a CB).  
* **BPS Calculation:** As validated in Protocol 1, Player B might have higher BPS.  
* **Contribution Score:** $CS \= 0.45 \\times BPS\_{avg} \+ 0.25 \\times Rating\_{avg} \+ 0.10 \\times Scarcity$.  
* **Test:** Ensure the system identifies Player A as an "Inefficient Resource" (High CA/Wage but low output) and Player B as "High Value."  
* **Action:** Recommend selling Player A to free up wage bill (Wage Efficiency Ratio test).

### **7.2 Financial Wage Structure Efficiency (30-30-30-10)**

A healthy squad maintains a specific wage structure: 30% Key, 30% First Team, 30% Rotation, 10% Backup.

**Validation Protocol 19: The Wage Dump Trigger**

* **Rule:** The "Rotation" tier (Players ranked 12-22) should consume \~30% of the wage budget.  
* **Scenario:** A single Rotation player is on "Key Player" wages ($\> 10\\%$ of total budget).  
* **Metric:** Wage\_Efficiency\_Ratio for that player \> 1.5.  
* **Result:** System flags "Urgent Wage Dump."  
* **Gate Priority:** If this player also triggers the "Peak Sell" gate (Age 29-30), the priority elevates to "Critical." The validation confirms that financial burden \+ declining asset value \= immediate sell recommendation.

## ---

**8\. Match Importance and Contextual Awareness**

The simulation must understand that a Champions League Semi-Final requires different logic than a pre-season friendly.

### **8.1 Final Importance Score (FIS)**

$$FIS \= (Base \\times M\_{opp} \\times M\_{sched} \\times M\_{user}) \+ B\_{context}$$  
**Validation Protocol 20: The "Giant Killing" Context**

* **Scenario:** FA Cup 3rd Round. Premier League User vs. League Two Opponent.  
* **Base:** 40 (Cup Early).  
* **Opponent Modifier:** User Rep (8000) vs Opp Rep (2000). $R\_s \= 0.25$. Classification: "Minnow." $M\_{opp} \= 0.6$.  
* **Calculation:** $FIS\_{raw} \= 40 \\times 0.6 \= 24$.  
* **Level:** Low (\< 25).  
* **Recommendation:** Heavy Rotation.  
* **Override Check:** If the user has "Cup Glory" as a board objective, does $M\_{user}$ increase?  
  * *Test:* Set Board Objective \= "Win FA Cup."  
  * *Expectation:* $M\_{user} \\to 1.5$. New FIS \= $24 \\times 1.5 \= 36$ (Medium-Low). This allows some backups but ensures a stronger spine. The validation confirms the system respects user/board priorities.

### **8.2 Schedule Context and ACWR**

**Validation Protocol 21: The 72-Hour Rule**

* **Setup:** High Importance match in 3 days ($T+3$).  
* **Current Match:** Medium Importance ($T$).  
* **Modifier:** $M\_{sched}$.  
* **Logic:** Since $Gap \\le 3$ and $Importance\_{next} \\gg Importance\_{curr}$, apply $M\_{sched} \= 0.7$.  
* **Result:** FIS drops from Medium to Low-Medium, encouraging earlier substitutions or resting key starters.

## ---

**9\. Integration Test Scenarios (The Full System)**

After validating components in isolation, we stress-test the holistic system. These scenarios represent the "Integration Tests" of the suite.

### **9.1 Scenario 1: The Christmas Crunch**

**Context:** The English Premier League "festive period" involves \~5 matches in 13 days. This is the ultimate stress test for rotation logic.

* **Setup:** 5 League matches (Medium importance). 13 days.  
* **Metrics to Monitor:**  
  1. **Rotation Index (RI):** $\\frac{\\text{Unique Starters}}{\\text{Squad Size}}$. Target: $\> 0.7$. The system must use the bench.  
  2. **Condition Floor Violation:** Count of starters with Condition \< 91%. Target: 0\.  
  3. **Jadedness Spikes:** No player should cross the Jaded threshold (700) unless $NaturalFitness \> 16$.  
* **Success Definition:** The system voluntarily drops points in Match 3 or 4 (fielding a weaker team) to ensure the First XI is fresh for Match 5\. A naive system plays the First XI until they break; the valid system rotates *proactively*, sacrificing local utility for global ATS maximization.

### **9.2 Scenario 2: The "Death Spiral" Prevention**

**Context:** A team with a small squad suffers injuries. The remaining players play every game. They get tired. They get injured. The cycle accelerates.

* **Test:** Induce 3 injuries to starters.  
* **Observation:** Does the system:  
  1. Call up youth players (lowering ATS but preserving health)?  
  2. Or keep playing the same exhausted 11?  
* **Pass Criteria:** The system *must* accept a lower ATS (fielding youth) rather than violating the 270-minute rule or the 91% Condition floor. It calculates that the risk of long-term injury (Shadow Price of health) outweighs the utility of winning the immediate match.

## ---

**10\. Technical Implementation and Metrics Library**

To execute these protocols, we define a Python-based harness utilizing pytest and standard data structures.

### **10.1 Data Structures**

We utilize a TestSquadSnapshot dataclass that mirrors the FM database schema.9

Python

@dataclass  
class PlayerState:  
    id: str  
    attributes: Dict\[str, int\]  \# e.g., {'pace': 15, 'finishing': 12}  
    condition: float            \# 0.0 to 1.0  
    sharpness: float            \# 0.0 to 1.0  
    jadedness: int              \# 0 to 1000  
    positions: Dict\[str, int\]   \# {'ST': 20, 'AMR': 15}  
    hidden\_attributes: Dict\[str, int\] \# {'consistency': 15}

### **10.2 Metric Functions**

Aggregate Team Strength (ATS):  
The primary optimization objective.

$$ATS \= \\sum\_{p \\in XI} GSS(p)$$

Validation Note: We normalize ATS against the "Theoretical Max ATS" (Best XI fully fresh) to track performance degradation over a season.  
Fatigue Violation Count (FVC):

$$FVC \= \\sum\_{m \\in Matches} \\sum\_{p \\in XI\_m} \\mathbb{I}(Condition\_p \< 0.91)$$

Target: 0\. Any violation represents a failure of the constraint solver.

### **10.3 Pytest Parametrization Strategy**

We leverage pytest's parametrization 11 to run thousands of permutations efficiently.

Python

@pytest.mark.parametrize("condition,expected\_multiplier", \[  
    (0.96, 1.0),  
    (0.91, 0.68),  
    (0.88, 0.50),  
    (0.80, 0.20)  
\])  
def test\_condition\_sigmoid(condition, expected\_multiplier):  
    assert abs(calculate\_phi(condition) \- expected\_multiplier) \< 0.05

This allows us to validate the "Condition Cliff" across the entire curve, ensuring no unexpected bumps or discontinuities exist in the utility function.

## ---

**11\. Conclusion and Recommendations**

This Validation Test Suite provides a robust, scientifically grounded framework for verifying the Football Manager squad management algorithms. By moving from outcome-based validation ("Did we win?") to process-based validation ("Did we respect physiological constraints?"), we ensure the system behaves with the logic and foresight of a skilled human manager.

**Key Recommendations for the Development Team:**

1. **Prioritize Shadow Pricing:** The most common failure mode in simulations is short-termism. The Shadow Price logic (Protocol 12 & 13\) is the antidote. Invest heavily in tuning the discount factor $\\gamma$ to balance immediate results with season-long stability.  
2. **Visualize the Cliffs:** Build debugging tools that graph the sigmoid curves for Condition and Sharpness. Visualizing where players sit on these curves during a "Christmas Crunch" simulation is invaluable for tuning.  
3. **Respect the Integers:** Do not rely solely on continuous LP solvers. The "Safe Big M" and specific integer constraints are necessary to handle the discrete nature of player selection (you cannot play 0.5 of a Goalkeeper).

By adhering to these protocols, the simulation engine will demonstrate not just computational efficiency, but tactical and strategic intelligence.

#### **Works cited**

1. Young player attributes going down :: Football Manager 26 General Discussions, accessed December 30, 2025, [https://steamcommunity.com/app/3551340/discussions/0/693120661167567122/](https://steamcommunity.com/app/3551340/discussions/0/693120661167567122/)  
2. (Table) How each Attribute contributes to players' Current Ability for each Position \- Reddit, accessed December 30, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1ebzb6j/table\_how\_each\_attribute\_contributes\_to\_players/](https://www.reddit.com/r/footballmanagergames/comments/1ebzb6j/table_how_each_attribute_contributes_to_players/)  
3. \[FM23\] \[Experiment\] Attributes influence on average rating for outfield players in various domestic leagues \- Sports Interactive Community, accessed December 30, 2025, [https://community.sports-interactive.com/forums/topic/589468-fm23-experiment-attributes-influence-on-average-rating-for-outfield-players-in-various-domestic-leagues/](https://community.sports-interactive.com/forums/topic/589468-fm23-experiment-attributes-influence-on-average-rating-for-outfield-players-in-various-domestic-leagues/)  
4. linear\_sum\_assignment — SciPy v1.16.2 Manual, accessed December 30, 2025, [https://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.linear\_sum\_assignment.html](https://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.linear_sum_assignment.html)  
5. Derive "true" shadow price for degenerated LPs using commercial solvers (e.g. Gurobi), accessed December 30, 2025, [https://or.stackexchange.com/questions/5030/derive-true-shadow-price-for-degenerated-lps-using-commercial-solvers-e-g-gu](https://or.stackexchange.com/questions/5030/derive-true-shadow-price-for-degenerated-lps-using-commercial-solvers-e-g-gu)  
6. linear\_sum\_assignment with infinite weights · Issue \#6900 · scipy/scipy \- GitHub, accessed December 30, 2025, [https://github.com/scipy/scipy/issues/6900](https://github.com/scipy/scipy/issues/6900)  
7. ksiegler1/LagrangianRelaxation: Implementation of Lagrangian Relaxation Method for approximating constrained optimization problems \- GitHub, accessed December 30, 2025, [https://github.com/ksiegler1/LagrangianRelaxation](https://github.com/ksiegler1/LagrangianRelaxation)  
8. Use Lagrangian relaxation — Resource hub | IBM Cloud Pak for Data, accessed December 30, 2025, [https://dataplatform.cloud.ibm.com/exchange/public/entry/view/133dfc4cd1480bbe4eaa78d3f6d12e8e?context=cpdaas](https://dataplatform.cloud.ibm.com/exchange/public/entry/view/133dfc4cd1480bbe4eaa78d3f6d12e8e?context=cpdaas)  
9. davidhamann/python-fmrest: Python wrapper around the FileMaker Data API \- GitHub, accessed December 30, 2025, [https://github.com/davidhamann/python-fmrest](https://github.com/davidhamann/python-fmrest)  
10. soliantconsulting/fm-data-api-client \- GitHub, accessed December 30, 2025, [https://github.com/soliantconsulting/fm-data-api-client](https://github.com/soliantconsulting/fm-data-api-client)  
11. Advanced Pytest Patterns: Harnessing the Power of Parametrization and Factory Methods, accessed December 30, 2025, [https://www.fiddler.ai/blog/advanced-pytest-patterns-harnessing-the-power-of-parametrization-and-factory-methods](https://www.fiddler.ai/blog/advanced-pytest-patterns-harnessing-the-power-of-parametrization-and-factory-methods)  
12. How to parametrize fixtures and test functions \- pytest documentation, accessed December 30, 2025, [https://docs.pytest.org/en/stable/how-to/parametrize.html](https://docs.pytest.org/en/stable/how-to/parametrize.html)