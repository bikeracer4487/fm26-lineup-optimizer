# **Operationalizing Victory: A Stochastic Optimization Framework for Squad Rotation and Performance Maximization in Football Simulation Environments**

## **1\. Introduction: The Stochastic Nature of the Match Engine**

In the high-fidelity ecosystem of modern football management simulations, specifically the *Football Manager* (FM) series, the role of the manager has evolved from simple tactical selection to complex systems engineering. The simulation engine does not function as a deterministic calculator where the highest attribute values guarantee victory. Instead, it operates as a stochastic system—a probabilistic environment where outcomes are generated through the interaction of thousands of variable distributions per match event. Within this chaotic system, the manager's primary lever of control is not merely the static quality of the squad, but the dynamic optimization of "readiness."

The operational objective is straightforward yet computationally complex: maximize the accumulation of league points over a seasonal horizon ($T \= 38+$ matches) while adhering to strict physiological and logistical constraints. Traditional approaches to this problem have relied on localized heuristics—"rotate when tired," "play the best XI in big games"—which often fail to account for the catastrophic non-linearities inherent in player performance decay. A player operating at 90% capacity does not yield 90% of their output; due to the threshold-based nature of the match engine's physics and collision logic, they may yield effective outputs closer to zero in critical phases of play.

This report presents a definitive, mathematically grounded scoring model: the **Global Selection Score (GSS)**. By applying principles from Operations Research (OR)—specifically multi-objective optimization and penalty-based constraint handling—we supersede previous ad-hoc methodologies. This framework integrates the four orthogonal pillars of player readiness—Condition, Match Sharpness, Fatigue (Jadedness), and Tactical Familiarity—into a unified utility function. We will demonstrate that the resolution to the conflicts between these variables lies not in linear averaging, but in the application of Bounded Sigmoidal Utility Functions and Exponential Penalty Functions, calibrated against the specific decay rates and recovery curves observed in the simulation's underlying database.1

## **2\. Theoretical Framework: Multi-Objective Optimization in Dynamic Systems**

To construct a robust scoring model, we must first define the mathematical environment. The selection problem in football management is a classic **Assignment Problem** complicated by **Resource Depletion**. We are assigning $N=11$ resources (players) to tasks (positions) from a pool of $M$ available candidates. However, the utilization of a resource ($R\_i$) in time period $t$ depletes its capacity for time period $t+1$, creating a dependency chain that requires a forward-looking optimization strategy rather than a greedy algorithm.

### **2.1 The Utility Function and The Additive Fallacy**

A common error in previous scoring attempts is the use of weighted arithmetic means (e.g., $Score \= 0.5 \\times Ability \+ 0.3 \\times Condition \+ 0.2 \\times Sharpness$). This approach suffers from the "Additive Fallacy." In a linear model, a deficiency in one variable can be compensated by an excess in another. For instance, a player with 0% Condition (physically unable to run) but immense Ability could theoretically score highly enough to be selected.

In operational reality, the variables of readiness act as **Hard Constraints** or multipliers. If a player's Sharpness is zero, their technical ability is effectively nullified by their inability to execute actions at match speed. If Condition is zero, the probability of injury approaches 1.0, and velocity approaches zero. Therefore, the GSS must be constructed as a **Multiplicative Utility Function**, where the total utility ($U$) approaches zero if any critical component approaches its failure state.

$$U\_{total} \= BPS \\cdot \\prod\_{k} \\phi\_k(x\_k)$$  
Where $BPS$ is the Base Performance Score (the player's intrinsic quality) and $\\phi\_k(x\_k)$ represents the normalized utility coefficient (0.0 to 1.0) of each readiness variable $k$.

### **2.2 Penalty Methods for Soft Constraints**

While some constraints are absolute (e.g., a suspension), most are "soft" constraints. A player *can* play at 88% condition, but it is suboptimal. In Operations Research, **Penalty Methods** are used to convert constrained problems into unconstrained ones by adding a penalty term to the objective function that scales with the degree of violation.4

For our model, we employ **Barrier Functions**. As a variable approaches a critical threshold (e.g., the "Injury Danger Zone" of roughly \<85% Condition), the penalty should not increase linearly, but exponentially. This mimics the behavior of the simulation engine, where the risk of a muscle tear does not rise gently; it spikes dramatically once the physiological buffer is depleted.5 The subsequent sections will derive the specific penalty functions—Logistic and Sigmoidal—necessary to model this behavior accurately.

## **3\. Variable Analysis I: The Thermodynamics of Physical Condition**

Physical Condition ($C$) is the primary fuel source of the athlete. It represents the immediate energy reservoir available for the match. Through rigorous analysis of community findings and simulation behavior, we can characterize $C$ as a renewable resource with non-linear depletion and recovery dynamics.

### **3.1 The Decay and Recovery Cycle**

Empirical observations confirm that Condition is the most volatile variable. A player typically ends a match with 60-75% condition depending on Stamina and Work Rate.1 Recovery to the baseline (100% or near-maximum) is governed by the player's "Natural Fitness" attribute and their current level of "Jadedness."

The crucial insight from the data is the non-linearity of risk. The "Green Heart" icon, often utilized by managers as a binary "Go/No-Go" signal, is deceptively broad, covering the range of roughly 91% to 100%.7 However, the internal mechanics distinguish sharply within this range. A player starting at 92% is significantly more likely to drop into the "Red Zone" (\<60%) by the 70th minute than a player starting at 99%.

| Condition State | UI Representation | Risk Profile | Operational Status |
| :---- | :---- | :---- | :---- |
| **98% \- 100%** | Full Green Heart | Minimal | **Optimal.** Can play 90 minutes \+ stoppage. |
| **91% \- 97%** | Green Heart | Moderate | **Viable.** Performance dip likely \>75 mins. Substitution required. |
| **80% \- 90%** | Green/Yellow Heart | High | **Critical Risk.** Sprint speed penalized immediately. Injury risk exponential. |
| **\< 80%** | Orange/Red Heart | Catastrophic | **Failure.** Player is an active liability. |

### **3.2 The Logistic Penalty Function Derivation**

To model this risk profile mathematically, we require a function that stays close to 1.0 for high values of $C$ and drops precipitously as $C$ approaches the danger threshold. The **Logistic Function** (or Sigmoid) is the ideal candidate for this transformation.8

We define the Condition Utility $\\Phi(c)$ as:

$$\\Phi(c) \= \\frac{1}{1 \+ e^{-k\_c(c \- c\_0)}}$$  
Where:

* $c$ is the condition percentage (normalized 0.0–1.0).  
* $c\_0$ is the inflection point (the midpoint of the penalty curve).  
* $k\_c$ is the steepness parameter.

Parameter Selection and Justification:  
Based on the "91% Rule" identified in heuristics—where 91% is the lowest acceptable starting condition for a professional match without severe performance penalty—we set the inflection point $c\_0$ slightly below this to allow for a gradient of risk.

* **Inflection Point ($c\_0 \= 0.88$):** We set the 50% utility mark at 88%. If a player is at 88% condition, they are effectively "half the player" they usually are due to the necessity of early substitution or rationing of sprints.  
* **Steepness ($k\_c \= 25$):** A high steepness value is required to create a "cliff." The difference between 95% and 85% is the difference between a starter and a reserve. A linear slope would underestimate the danger of 85% and overestimate the utility of 99% vs 98%.

Calculated outputs using these parameters:

* $\\Phi(0.98) \\approx 0.92$ (Near perfect utility)  
* $\\Phi(0.93) \\approx 0.78$ (Noticeable penalty, reflecting the risk of late-game fatigue)  
* $\\Phi(0.90) \\approx 0.62$ (Significant reduction; marginal selection)  
* $\\Phi(0.85) \\approx 0.32$ (Severe penalty; unselectable for competitive fixtures)

This curve aligns with the "Injury Risk" notifications in the game, which transition from "Low" to "High" over a similarly narrow band of condition loss.6

## **4\. Variable Analysis II: The Mechanics of Match Sharpness**

If Condition is the fuel, Match Sharpness ($S$) is the efficiency of the engine. It is a measure of the player's temporal calibration—their ability to process the game's physics and decision trees at speed. The "Condition-Sharpness Paradox" is the central conflict of squad management: resting restores Condition but degrades Sharpness.5

### **4.1 The Kinetics of Rust**

Research indicates a specific decay rate for Sharpness: approximately **1% per day** of inactivity.1 This linear decay is relentless. A player sidelined for three weeks (21 days) drops from 100% to \~79%. While 79% sounds high, in the context of the match engine, it implies a severe degradation in "Mental" attributes like Anticipation and Concentration.

The impact of low sharpness is often described as "rust." In simulation terms, this likely manifests as an increased error term in the calculation of technical outcomes. A pass with a success probability of 0.9 might drop to 0.7, not because the Passing attribute changed, but because the Sharpness multiplier suppressed the effective decision-making window.12

### **4.2 The Bounded Sigmoid Build-Up**

Unlike Condition, which recovers passively with rest, Sharpness requires active stimulus (match minutes). The relationship between minutes played and Sharpness gain is **Logarithmic** or **Sigmoidal**. The first 45-60 minutes of play provide the bulk of the stimulus, traversing the steep part of the learning curve. Minutes 60-90 provide diminishing returns in sharpness while incurring escalating costs in Fatigue.5

To model the utility of Sharpness in our scoring system, we cannot use the same curve as Condition. A player with 90% Sharpness is still elite. A player with 50% Sharpness is useless. We need a curve that penalizes the low end aggressively but plateaus early.

**The Gompertz-Style Utility Function $\\Psi(s)$:**

$$\\Psi(s) \= \\frac{1.02}{1 \+ e^{-k\_s(s \- s\_0)}} \- 0.02$$  
**Parameter Selection and Justification:**

* **Inflection Point ($s\_0 \= 0.75$):** This represents the boundary between "Unfit" and "Building Fitness." Below 75%, a player is in pre-season mode. Above 75%, they are competitive.  
* **Steepness ($k\_s \= 15$):** This is shallower than the Condition curve ($k\_c=25$). The transition from unfit to fit is more gradual.  
  * $\\Psi(1.00) \\approx 1.00$ (Peak)  
  * $\\Psi(0.90) \\approx 0.91$ (Excellent)  
  * $\\Psi(0.80) \\approx 0.68$ (Acceptable for rotation/subs)  
  * $\\Psi(0.60) \\approx 0.08$ (Unusable)

This function solves the **"Bench Sitter" problem**. A player on the bench with 100% Condition but 50% Sharpness yields a Score near zero ($\\Psi(0.50) \\approx 0.02$), correctly identifying that they are not a viable solution for the first team and should instead be assigned to the U21s to build readiness.5

## **5\. Variable Analysis III: The Hidden Variable of Jadedness**

Perhaps the most misunderstood aspect of the simulation is "Fatigue," often referred to as **Jadedness**. Unlike Condition and Sharpness, Jadedness is often a **Hidden Attribute** or a background variable that accumulates over the medium-to-long term. It is the accumulation of micro-trauma and mental burnout.2

### **5.1 The Accumulation Proxy**

Jadedness accumulates linearly with workload (minutes played \+ training intensity) but dissipates logarithmically. It acts as a scalar penalty on the player's *maximum* recoverable Condition and their attribute development.10 A "Jaded" player might show 95% Condition, but their performance ceiling is capped, and their injury risk is equivalent to a player with 60% Condition.

Since Jadedness is often hidden until the "Jaded" status flag appears, our model must use a proxy variable: **Overall Physical Condition (OPC)** or **Rolling Workload**.

### **5.2 Natural Fitness: The Decay Coefficient**

The rate of Jadedness accumulation and the speed of Condition recovery are modulated by the **Natural Fitness** attribute. This attribute is the single most critical factor in squad rotation planning.16

* **High Natural Fitness (16-20):** Players recover to \>95% Condition within 2-3 days. They resist Jadedness accumulation.  
* **Low Natural Fitness (1-10):** Players require 4-5 days to recover. They accumulate Jadedness rapidly if played twice in a week.

### **5.3 The Fatigue Penalty Step-Function $\\Omega(J)$**

Because Jadedness is often categorical in the UI (e.g., "Fresh," "Lacking Match Fitness," "Jaded"), we model it as a discrete step function or a continuous penalty based on recent minutes.

$$\\Omega(J) \= \\begin{cases} 1.0 & \\text{if status is "Fresh"} \\\\ 0.9 & \\text{if status is "Match Fit"} \\\\ 0.7 & \\text{if status is "Tired"} \\\\ 0.4 & \\text{if status is "Jaded" / "Needs Rest"} \\end{cases}$$  
The "Hidden Jadedness" Correction:  
If a player has played \>270 minutes in the last 10 days, apply a specific penalty factor of 0.85, regardless of the UI status. This preemptive heuristic accounts for the lag between actual physiological fatigue and the UI notification, preventing the "mid-season collapse" where players suddenly underperform despite green hearts.17

## **6\. Variable Analysis IV: Tactical Familiarity**

Tactical Familiarity ($F$) represents the cognitive load required to execute the manager's instructions. In Operations Research terms, this is a **Efficiency Multiplier**. A player with 100% familiarity executes actions at 100% of their attribute capacity. A player with 50% familiarity suffers from latency in positioning and decision making.12

### **6.1 The Linear Scalar**

Unlike the physiological variables, Familiarity does not exhibit a catastrophic failure threshold. A player with 50% familiarity is clumsy but functional; they do not risk injury or collapse. Therefore, we model this as a linear scaling function rather than a sigmoid.

$$\\Theta(f) \= 0.7 \+ (0.3 \\times f)$$  
Justification:  
We set a floor at 0.7 (70%). Even with 0% familiarity, a world-class player (e.g., Lionel Messi) retains significant utility due to raw technical ability. A 0% multiplier would be absurd. A 30% penalty represents the loss of "system efficiency" (pressing triggers, defensive structure) while preserving individual brilliance.20

* $f=1.00 \\rightarrow \\Theta \= 1.00$  
* $f=0.50 \\rightarrow \\Theta \= 0.85$  
* $f=0.00 \\rightarrow \\Theta \= 0.70$

This formulation ensures that while we prefer familiar players, we are not forced to play a mediocre player with 100% familiarity over a superstar with 80% familiarity. The BPS differential will usually override the familiarity penalty, which aligns with observed "Meta" strategies where talent often trumps system coherence.20

## **7\. Variable Analysis V: The Base Performance Score (BPS)**

Before applying the readiness multipliers, we must quantify the player's intrinsic value: the **Base Performance Score (BPS)**. The common error here is treating all attributes as equal. The FM match engine is heavily biased toward specific "Meta-Attributes".20

### **7.1 The Meta-Physical Hierarchy**

Extensive community testing and reverse-engineering efforts suggest that **Physical Attributes** (Pace, Acceleration) act as a gating mechanism for all other actions. A player who cannot reach the ball cannot pass, shoot, or tackle. Therefore, Pace and Acceleration are the independent variables that determine the volume of opportunities a player receives.

Weighting Vector $\\vec{w}$:  
To calculate BPS, we apply a weighted sum to the attributes relevant to the player's role ($A\_k$).

$$BPS\_i \= \\sum\_{k=1}^{n} (w\_k \\times A\_{i,k})$$  
**Recommended Weighting Specification:**

1. **Tier 1: The Engine (Weight 2.0):** Pace, Acceleration. (For virtually all outfield roles).  
2. **Tier 2: The Role Essentials (Weight 1.5):**  
   * *Strikers:* Finishing, Dribbling, Composure.  
   * *Playmakers:* Passing, Vision, Technique.  
   * *Defenders:* Jumping Reach, Strength, Positioning.  
3. **Tier 3: The Mental Framework (Weight 1.2):** Anticipation, Concentration, Decisions, Work Rate.  
4. **Tier 4: The Marginal Gains (Weight 0.5):** Aggression, Bravery, Flair (unless specific to role).

Hidden Attributes Consideration:  
Hidden attributes such as Consistency and Important Matches act as variance modifiers. A high Consistency attribute reduces the standard deviation of the player's match performance distribution. In our deterministic model, we can treat high Consistency as a flat bonus to BPS (e.g., \+10%) or simply acknowledge that BPS represents the "mean expected performance".23

### **7.2 The Age-Decline Adjustment**

The BPS is not static over time. Players over age 30 experience physical decline. However, this decline is strongly correlated with **Natural Fitness**.

* **Heuristic:** For players Age \> 29, monitor Pace/Acceleration monthly.  
* **Correction:** If Natural Fitness \< 15, anticipate a BPS degradation of \~5-10% per season. If Natural Fitness \> 15, the BPS remains stable often until age 34-35.25 The GSS model naturally handles the eventual decline because as physical stats drop, the raw BPS drops, leading to the player being gradually phased out by younger, faster options.

## **8\. The Definitive Scoring Model: The Global Selection Score (GSS)**

Having defined the components, we now assemble the unified Global Selection Score. This single value determines the optimal squad selection for any given match state $t$.

$$GSS\_{i,t} \= BPS\_i \\times \\underbrace{\\left\[ \\frac{1}{1 \+ e^{-25(C\_{i,t} \- 0.88)}} \\right\]}\_{\\text{Condition Utility}} \\times \\underbrace{\\left}\_{\\text{Sharpness Utility}} \\times \\underbrace{\\Theta(F\_{i,t})}\_{\\text{Familiarity}} \\times \\underbrace{\\Omega(J\_{i,t})}\_{\\text{Fatigue}}$$

### **8.1 Parameter Summary**

| Parameter | Value | Description |
| :---- | :---- | :---- |
| **$k\_c$** | **25** | Steepness of Condition drop-off. Creates hard floor at \~85%. |
| **$c\_0$** | **0.88** | Midpoint of Condition curve. Defines the "Safe Zone" \> 91%. |
| **$k\_s$** | **15** | Steepness of Sharpness build-up. |
| **$s\_0$** | **0.75** | Midpoint of Sharpness curve. Defines "Match Ready" \> 80%. |
| **$\\Theta\_{floor}$** | **0.70** | Minimum multiplier for 0% Tactical Familiarity. |
| **$\\Omega\_{jaded}$** | **0.40** | Severe penalty multiplier for "Jaded" status. |

### **8.2 Resolving the Conflicts**

This formula resolves the user's core conflicts through the interplay of the logistic and sigmoidal curves.

* **Conflict: Condition vs. Sharpness.**  
  * *Scenario:* A player returns from injury. Condition is 100%, Sharpness is 50%.  
  * *Result:* The Condition term is $\\approx 0.99$. The Sharpness term is $\\approx 0.02$. The total GSS is decimated ($0.99 \\times 0.02 \\approx 0.02$). The model correctly identifies that physical health does not compensate for lack of match practice. The player is unselectable for the first team.  
  * *Scenario:* A player is overplayed. Condition is 88%, Sharpness is 100%.  
  * *Result:* The Sharpness term is $1.0$. The Condition term drops to $0.50$ (the inflection point). The score is halved. This forces a comparison: Is half of this Star Player better than a fully fit Rotation Player? If the Rotation Player has a BPS at least 50% of the Star, they are the better choice.  
* **Conflict: Fatigue vs. Ability.**  
  * *Scenario:* A world-class player (BPS 180\) is "Jaded" ($\\Omega \= 0.4$).  
  * *Result:* Effective Score \= 72\. A mediocre backup (BPS 120\) who is Fresh ($\\Omega=1.0$) scores 120\. The model forces the manager to rest the star, preventing long-term injury and the inevitable poor performance associated with jadedness.

## **9\. Implementation Guide: From Theory to Practice**

To apply this OR framework without performing calculus before every match, we can implement the GSS via a spreadsheet tool or through strict operational heuristics.

### **9.1 Data Export and Spreadsheet Integration**

Managers can utilize the "Print Screen" or "Export" function in FM to extract squad data (Name, Attributes, Condition, Sharpness, etc.) into a CSV file.27

**Spreadsheet Columns Setup:**

1. **Input:** Pace, Accel, Key Technicals, Key Mentals $\\rightarrow$ Calculate BPS.  
2. **Input:** Condition (0-100), Sharpness (0-100) $\\rightarrow$ Apply Sigmoid Formulas (using EXP() functions).  
3. **Input:** Fatigue Status (Text) $\\rightarrow$ VLOOKUP penalty table (1.0, 0.9, 0.4).  
4. **Output:** GSS \= Product of columns.  
5. **Sort:** Descending GSS per position.

This provides an objective, mathematically rigorous depth chart for the next match.

### **9.2 The "Sharpness Build" Heuristic**

For managers not using spreadsheets, the model dictates the following routine for players with Low Sharpness (low GSS due to $\\Psi(S)$):

1. **The Reserve Calibration:** Any player with Sharpness \< 85% is unavailable for the First XI. They must be made available for the U21/Reserve squad.  
2. **The 60-Minute Dose:** Instruct the U21 manager to play them for 60 minutes. This maximizes the $\\Delta S$ (Sharpness gain) while minimizing the fatigue cost, traversing the steep part of the sigmoid curve efficiently.5  
3. **No Back-to-Back:** Ensure U21 matches do not occur the day before a first-team fixture.

### **9.3 The "Red Zone" Rotation Rule**

The exponential nature of the Condition penalty $\\Phi(c)$ gives rise to the **91% Rule**.

* **Rule:** If a player's Condition is \< 91% (often indistinguishable from "Full Green" at a glance), they **Must Not Start**.  
* **Reasoning:** Starting at 91% means they will hit the 75% "Collapse Threshold" around minute 60\. This forces a wasted substitution or risks a goal conceded in the final 30 minutes due to the defensive error rate spiking as condition falls.14

## **10\. Case Studies and Simulations**

To validate the model, let us examine two common managerial dilemmas.

### **Case Study A: The Cup Final Dilemma**

*Context:* It is the Champions League Final. No future games exist. Long-term fatigue is irrelevant.

* **Player A (Star):** BPS 180\. Condition 89%. Sharpness 100%.  
* **Player B (Backup):** BPS 140\. Condition 100%. Sharpness 100%.

*Standard Model Calculation ($k\_c=25$):*

* Player A: $\\Phi(0.89) \\approx 0.56$. $GSS \= 180 \\times 0.56 \= 100.8$.  
* Player B: $\\Phi(1.00) \\approx 0.99$. $GSS \= 140 \\times 0.99 \= 138.6$.  
* *Result:* The model recommends Player B.

*Context Adjustment:* In a final, we accept higher risk. We relax the steepness parameter $k\_c$ to 15 (flattening the penalty).

* Player A (Adjusted): $\\Phi(0.89, k=15) \\approx 0.75$. $GSS \= 180 \\times 0.75 \= 135$.  
* *Result:* The gap closes significantly. The manager might choose Player A for their "moment of magic" potential, accepting the risk that they will need to be subbed at minute 50\. The model quantifies exactly how much "fitness risk" the manager is accepting (a 25% drop in operational efficiency).

### **Case Study B: The "Rusty" Return**

*Context:* A key winger returns from a broken leg.

* **Stats:** Condition 95%. Sharpness 50%. BPS 160\.  
* **Standard GSS:** $\\Psi(0.50) \\approx 0.02$. $GSS \= 160 \\times 0.02 \= 3.2$.  
* *Result:* Unselectable.  
* **Heuristic Check:** Many managers would sub them on for 20 minutes "to get fitness."  
* **Model Validation:** Subbing them on for the *First Team* risks the result because for those 20 minutes, the team effectively plays with 10 men ($Score \\approx 3$). The model confirms the correct operational procedure is **Reserve Team** minutes first, where the cost of failure is zero.

## **11\. Long-Term Horizons: Age, Decline, and Planning**

The GSS model is primarily a short-term selection tool, but it informs long-term strategy. The interaction between **Natural Fitness** and **Age** determines the useful lifespan of a player's BPS.

### **11.1 The Decline Curve**

Players with High Natural Fitness (16+) maintain their Physical BPS components (Pace/Accel) into their mid-30s. Players with Low Natural Fitness (\<10) see these components degrade rapidly after age 29\.25

* **Strategic Implication:** A player with Low Natural Fitness requires a replacement to be scouted 2 years earlier than a high-fitness counterpart.  
* **Squad Depth:** For low-fitness players, the squad requires a "1A/1B" rotation structure (two equal players) rather than "Starter/Backup," because the low-fitness player will be unavailable for 30-40% of the season due to slow recovery dynamics.

## **12\. Conclusion**

The management of a football squad in a high-fidelity simulation is not an art; it is an optimization problem constrained by biological decay functions. The **Global Selection Score (GSS)** presented here supersedes localized intuition by quantifying the relationships between Condition, Sharpness, Fatigue, and Ability.

By adhering to the multiplicative structure of the GSS, managers avoid the catastrophic failure states associated with "playing through the pain" or fielding "rusty" players. The model enforces a disciplined, mathematically justified rotation policy that maximizes the aggregate readiness of the squad over the entire season. The result is not just a fitter team, but a team that consistently operates at the peak of its probability distribution, minimizing variance and maximizing expected points (xPts).

### **Summary of Operational Rules**

1. **The 91% Floor:** Never start a player with $\<91\\%$ Condition ($k\_c=25$ Penalty).  
2. **The 85% Sharpness Gate:** Use U21 matches to traverse the sigmoid curve before First Team selection.  
3. **The Jadedness Cap:** A Jaded player is an operational liability ($\\Omega=0.4$); rest is the only cure.  
4. **The Meta-Attribute Weighting:** Prioritize Pace/Acceleration in the BPS calculation to align with the match engine's physics bias.

This framework transforms the manager from a passive observer of fitness icons into an active engineer of human performance.

#### **Works cited**

1. maintaining match sharpness \- Football Manager General ..., accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/369341-maintaining-match-sharpness/](https://community.sports-interactive.com/forums/topic/369341-maintaining-match-sharpness/)  
2. Any tips for dealing with jadedness? : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/rvxuzz/any\_tips\_for\_dealing\_with\_jadedness/](https://www.reddit.com/r/footballmanagergames/comments/rvxuzz/any_tips_for_dealing_with_jadedness/)  
3. Operational Research: methods and applications \- Taylor & Francis Online, accessed December 29, 2025, [https://www.tandfonline.com/doi/full/10.1080/01605682.2023.2253852](https://www.tandfonline.com/doi/full/10.1080/01605682.2023.2253852)  
4. Penalty method \- Wikipedia, accessed December 29, 2025, [https://en.wikipedia.org/wiki/Penalty\_method](https://en.wikipedia.org/wiki/Penalty_method)  
5. How important is it to keep match sharpness? : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/18ha4rw/how\_important\_is\_it\_to\_keep\_match\_sharpness/](https://www.reddit.com/r/footballmanagergames/comments/18ha4rw/how_important_is_it_to_keep_match_sharpness/)  
6. WHY FATIGUE MATTERS \- OPC YOU KNOW ME : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/18mv2zq/why\_fatigue\_matters\_opc\_you\_know\_me/](https://www.reddit.com/r/footballmanagergames/comments/18mv2zq/why_fatigue_matters_opc_you_know_me/)  
7. I hate the new Condition/Sharpness Icons... \- Football Manager General Discussion, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/532881-i-hate-the-new-conditionsharpness-icons/](https://community.sports-interactive.com/forums/topic/532881-i-hate-the-new-conditionsharpness-icons/)  
8. Logistic function \- Wikipedia, accessed December 29, 2025, [https://en.wikipedia.org/wiki/Logistic\_function](https://en.wikipedia.org/wiki/Logistic_function)  
9. Sigmoid function \- Wikipedia, accessed December 29, 2025, [https://en.wikipedia.org/wiki/Sigmoid\_function](https://en.wikipedia.org/wiki/Sigmoid_function)  
10. Player Fitness | Football Manager 2022 Guide, accessed December 29, 2025, [https://www.guidetofm.com/squad/fitness/](https://www.guidetofm.com/squad/fitness/)  
11. Struggling with match sharpness after break : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1172b6w/struggling\_with\_match\_sharpness\_after\_break/](https://www.reddit.com/r/footballmanagergames/comments/1172b6w/struggling_with_match_sharpness_after_break/)  
12. FM24 » Attributes You Need At Every Position...UPDATED 2025 \- Steam Community, accessed December 29, 2025, [https://steamcommunity.com/sharedfiles/filedetails/?id=3300852257](https://steamcommunity.com/sharedfiles/filedetails/?id=3300852257)  
13. FIGHT FATIGUE \#FM23 \- YouTube, accessed December 29, 2025, [https://www.youtube.com/watch?v=noymFV9NRMs](https://www.youtube.com/watch?v=noymFV9NRMs)  
14. Player Fitness Condition: FM is unplayable \- Football Manager General Discussion, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/581072-player-fitness-condition-fm-is-unplayable/](https://community.sports-interactive.com/forums/topic/581072-player-fitness-condition-fm-is-unplayable/)  
15. Jaded and exhausted... \- Football Manager General Discussion \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/295115-jaded-and-exhausted/](https://community.sports-interactive.com/forums/topic/295115-jaded-and-exhausted/)  
16. Natural fitness??? \- Football Manager General Discussion \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/208968-natural-fitness/](https://community.sports-interactive.com/forums/topic/208968-natural-fitness/)  
17. Fatigue?? :: Football Manager 2024 General Discussions \- Steam Community, accessed December 29, 2025, [https://steamcommunity.com/app/2252570/discussions/0/4029095281637786919/](https://steamcommunity.com/app/2252570/discussions/0/4029095281637786919/)  
18. Add "Fatigue" to your Selection Info / Team Selection screen views \- and how much is too much? : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/raz2yk/add\_fatigue\_to\_your\_selection\_info\_team\_selection/](https://www.reddit.com/r/footballmanagergames/comments/raz2yk/add_fatigue_to_your_selection_info_team_selection/)  
19. Does 'Position/Role/Duty' familiarity do anything? \- Tactics, Training & Strategies Discussion \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/569971-tactical-familiarity-does-positionroleduty-familiarity-do-anything/](https://community.sports-interactive.com/forums/topic/569971-tactical-familiarity-does-positionroleduty-familiarity-do-anything/)  
20. A (not so) short guide to "meta" player attributes and development : r/footballmanagergames, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/16fuksi/a\_not\_so\_short\_guide\_to\_meta\_player\_attributes/](https://www.reddit.com/r/footballmanagergames/comments/16fuksi/a_not_so_short_guide_to_meta_player_attributes/)  
21. Attributes Weights \[THEORYCRAFTING\] : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/13gfru4/attributes\_weights\_theorycrafting/](https://www.reddit.com/r/footballmanagergames/comments/13gfru4/attributes_weights_theorycrafting/)  
22. My thoughts on the whole "Physical stats vs Mental Stats" testing/debate that's been going on, and why I think the match engine's behaviour is (mostly) justified. : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1avs156/my\_thoughts\_on\_the\_whole\_physical\_stats\_vs\_mental/](https://www.reddit.com/r/footballmanagergames/comments/1avs156/my_thoughts_on_the_whole_physical_stats_vs_mental/)  
23. Football Manager Hidden Attributes Guide \- GitHub Pages, accessed December 29, 2025, [https://zfn4fun.github.io/fm/att/](https://zfn4fun.github.io/fm/att/)  
24. How player performance is affected by current ability vs. attributes \- Football Manager General Discussion \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/509679-how-player-performance-is-affected-by-current-ability-vs-attributes/](https://community.sports-interactive.com/forums/topic/509679-how-player-performance-is-affected-by-current-ability-vs-attributes/)  
25. They should nerf physical decline with age : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/oqseay/they\_should\_nerf\_physical\_decline\_with\_age/](https://www.reddit.com/r/footballmanagergames/comments/oqseay/they_should_nerf_physical_decline_with_age/)  
26. At what age do players peak on their CA? : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/w8n325/at\_what\_age\_do\_players\_peak\_on\_their\_ca/](https://www.reddit.com/r/footballmanagergames/comments/w8n325/at_what_age_do_players_peak_on_their_ca/)  
27. FM Squad Assessment Spreadsheet v7 (FM24 ready) : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/17hkiip/fm\_squad\_assessment\_spreadsheet\_v7\_fm24\_ready/](https://www.reddit.com/r/footballmanagergames/comments/17hkiip/fm_squad_assessment_spreadsheet_v7_fm24_ready/)  
28. FM23 Squad Assessment Spreadsheet : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/yc873v/fm23\_squad\_assessment\_spreadsheet/](https://www.reddit.com/r/footballmanagergames/comments/yc873v/fm23_squad_assessment_spreadsheet/)  
29. What fitness percentage do you consider not match fit? \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/268261-what-fitness-percentage-do-you-consider-not-match-fit/](https://community.sports-interactive.com/forums/topic/268261-what-fitness-percentage-do-you-consider-not-match-fit/)  
30. Physical attributes in the mid-30s \- Football Manager General Discussion \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/561646-physical-attributes-in-the-mid-30s/](https://community.sports-interactive.com/forums/topic/561646-physical-attributes-in-the-mid-30s/)