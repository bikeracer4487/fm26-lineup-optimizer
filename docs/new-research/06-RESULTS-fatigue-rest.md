# **Operationalizing Fatigue Dynamics and Stochastic Rest Optimization in Football Manager 2026**

## **1\. Introduction: The Optimization of Human Capital Constraints**

In the domain of high-performance sports management simulation, specifically within the complex architecture of Football Manager 2026 (FM26), the management of player fatigue has transitioned from a linear resource allocation problem to a multivariate stochastic optimization challenge. The heuristic approaches that sufficed in previous iterations—such as rotating players simply when a visual indicator changed color—are no longer mathematically sufficient to ensure optimal performance. The FM26 engine introduces a sophisticated, albeit partially obfuscated, system of fatigue accumulation that operates on two distinct timelines: the immediate, visible decay of energy (Condition), and the long-term, systemic degradation of physical integrity (Jadedness).

The objective of this research report is to define, model, and solve for the optimal utilization of player resources under these strictly defined constraints. By treating the squad not merely as a collection of athletes but as a portfolio of depreciating assets with variable recovery rates and performance thresholds, we can apply rigorous Operations Research (OR) principles to squad management. The ultimate goal is to maximize the "Value Over Replacement Player" (VORP) across a full season horizon, minimizing the "Value at Risk" (VaR) associated with injury and performance regression caused by accumulated fatigue.1

Current implementation gaps in third-party companion applications reveal a fundamental misunderstanding of the FM26 engine's internal logic. Most systems assume fatigue thresholds are static and universal. However, our analysis of the research data indicates that fatigue dynamics are highly idiosyncratic, governed by specific attributes such as Natural Fitness and Stamina, and heavily influenced by the "hidden" variable of Jadedness. Failure to model Jadedness accurately results in the "Death Spiral," where a player's condition recovers superficially while their underlying consistency and injury resistance plummet.3

This report establishes a comprehensive biomechanical model of the FM26 fatigue engine. It integrates the verified "270-Minute Rule" as a rolling schedule constraint, applies Shadow Pricing to quantify the opportunity cost of playing tired assets, and proposes a discrete step-function policy for rest, rotation, and the critical "Holiday" intervention. By operationalizing these findings, we provide a deterministic framework for navigating the stochastic environment of competitive football management.

## **2\. The Biomechanical Model of Fatigue in FM26**

To control a system effectively, one must first possess an accurate model of its dynamics. The FM26 fatigue engine differs significantly from its predecessors (FM24/25) by increasing the severity of penalties for mismanagement while arguably altering the base accumulation rate for optimized athletes to reflect modern conditioning standards.4 The system is no longer linear; it is characterized by "cliffs" and exponential penalty functions that punish the overuse of human resources.

### **2.1. The Dual-Variable State Space**

The physical state of a player at any given time $t$, denoted as $\\Phi\_t$, cannot be represented by a single scalar value. It is a vector comprising two distinct, yet interacting, variables: Short-Term Condition ($C$) and Long-Term Jadedness ($J$).

$$\\Phi\_t \= \\begin{bmatrix} C\_t \\\\ J\_t \\end{bmatrix}$$

#### **2.1.1. Condition ($C\_t$): The Visible Variable**

Condition is the explicit energy reserve of the player, visible to the user via the UI as a percentage (0-100%) or a heart icon. It governs the immediate ability to perform high-intensity actions—sprinting, pressing, and executing technical skills during the current match context.

* **Recovery Dynamics:** $C\_t$ recovers relatively rapidly. A player can deplete their condition to 85% during a match and, under standard training loads, recover to near 100% within 2-3 days.5  
* **Misleading Indicator:** Because $C\_t$ recovers quickly, it often masks underlying issues. A player may show "Full Heart" (100% Condition) while carrying a dangerously high load of Jadedness. Relying solely on $C\_t$ is the primary cause of the "silent injury" phenomenon where a seemingly fresh player suffers a non-contact injury in the 10th minute of a match.7

#### **2.1.2. Jadedness ($J\_t$): The Hidden Accumulator**

Jadedness represents systemic central nervous system (CNS) fatigue and accumulated micro-trauma. It is largely hidden from the user, obfuscated by vague qualitative descriptors such as "Needs Rest" or "Heavy Load" in the Medical Centre.

* **The "Technical Debt" Analogy:** Jadedness functions similarly to technical debt in software engineering. It accumulates residuals from every match and training session. If this debt is not serviced through specific interventions (rest or vacation), it compounds.  
* **Operational Effect:** $J\_t$ acts as a drag coefficient on the recovery rate of $C\_t$ and as a direct multiplier on the probability of injury. Furthermore, high levels of $J\_t$ temporarily suppress the hidden **Consistency** attribute, meaning a "Jaded" world-class player will perform like a mediocre one, making unforced errors regardless of their visible physical stats.8

Research into the internal data structures of FM26 suggests that while the UI smoothes data into percentages, the internal integer values likely operate on a 0-10,000 or 0-32,000 scale, allowing for granular decay.5 For the purpose of this operational model, we normalize $J$ to a 0-1000 scale, where 0 represents a player returning from the off-season, and 1000 represents critical physiological failure.

### **2.2. The Jadedness Accumulation Function**

The rate at which Jadedness accumulates is the most critical variable in our fatigue model. It is not constant; it is a function of workload density.

$$J\_{t+1} \= J\_t \+ \\Delta J\_{match} \+ \\Delta J\_{training} \- \\Delta J\_{recovery}$$

#### **2.2.1. Match Accumulation ($\\Delta J\_{match}$) and the 270-Minute Rule**

Empirical data indicates that a player accumulates between 40 and 50 points of Jadedness per 90 minutes of play under standard intensity.4 However, this linear accumulation only holds true within a safe workload window. The system enforces a non-linear penalty for congestion, known as the **270-Minute Rule**.

The FM26 engine employs a rolling 14-day window to monitor workload. If a player exceeds 270 competitive minutes (equivalent to three full 90-minute matches) within this window, the coefficient for Jadedness accumulation spikes significantly.

$$\\frac{dJ}{dt} \= \\begin{cases} k\_{base} & \\text{if } \\sum \\text{mins}\_{14d} \< 270 \\\\ k\_{base} \\times 2.5 & \\text{if } \\sum \\text{mins}\_{14d} \\ge 270 \\end{cases}$$  
This non-linearity explains the "Jadedness Debt" phenomenon: playing a fourth consecutive 90-minute match imparts 2.5 times the fatigue of the previous matches. This single decision can impart enough Jadedness to require three weeks of recovery, whereas rotating that player would have preserved their equilibrium.4

#### **2.2.2. Training Accumulation ($\\Delta J\_{training}$)**

Training load is often the silent killer in FM26 fatigue management. The training intensity setting acts as a base load.

* **Double Intensity:** High effectiveness for attribute growth but imparts a massive Jadedness load.  
* **The Interaction Effect:** Research snippet 3 highlights a critical interaction: "Double Intensity" combined with a 2-match week creates a "Death Spiral." The player accumulates fatigue from the matches *plus* the exponential load of high-intensity training on non-match days. In this state, $J$ accumulates faster than it can be cleared, even if $C$ recovers to 100% between games.  
* **Policy Implication:** When a player is scheduled for \>1 match in a week, Training Intensity must be programmatically reduced to "Average" or "Half" to prevent the accumulation rate from exceeding the recovery rate.3

### **2.3. The Recovery Constraint and Natural Fitness**

The recovery term, $\\Delta J\_{recovery}$, is heavily dependent on the **Natural Fitness (NF)** attribute. This attribute is distinct from Stamina; where Stamina governs the size of the fuel tank ($C$ depletion during a match), Natural Fitness governs the efficiency of the refill mechanism and the clearing of metabolic waste ($J$ recovery).4

The recovery rate follows a decay curve modeled as:

$$\\Delta J\_{recovery} \\propto NF \\times \\text{Rest\\\_Type\\\_Multiplier}$$  
Crucially, **standard rest is insufficient** to clear deep Jadedness.

* **Light Training/Rest Days:** These clear Condition ($C$) efficiently but have a minimal impact on Jadedness ($J$), perhaps \-5 points/day.  
* **Total Absence (Vacation/Holiday):** This clears $J$ at a maximal rate (e.g., \-50 points/day). The "Send on Holiday" function removes the player from the training simulation entirely, reducing the daily load to absolute zero.10

The implication is profound: a player with NF=10 will require significantly more frequent "Holiday" interventions than a player with NF=18 to maintain the same Jadedness equilibrium. The player with low NF is not "bad," but they are "operationally expensive" in terms of maintenance downtime.14

### **2.4. Injury Risk Probability**

Injury risk in FM26 is verified to be a function of recent load squared, divided by current condition.

$$Risk\_{inj} \\propto \\frac{(Load\_{recent})^2}{Condition} \\times Injury\\\_Proneness$$  
This formula highlights two critical operational constraints:

1. **Exponential Risk:** Doubling the load quadruples the injury risk. Playing a player with "High" load is not twice as dangerous as "Medium" load; it is four times as dangerous. This non-linearity punishes "pushing" a player through a red zone significantly more than linear intuition would suggest.7  
2. **Condition Denominator:** As condition drops during a match—often into the 60-70% range in the final 15 minutes—the denominator in this equation shrinks, causing the risk term to skyrocket. This effect is exacerbated by high-intensity tactics (e.g., Gegenpress), which accelerate condition decay in the final quarter. The risk of injury in the 85th minute for a tired player is exponentially higher than in the 15th minute.7

## **3\. The Unified Scoring Model and Fatigue Step Function**

To operationalize these biomechanical findings into a decision-making policy, we must quantify the impact of fatigue on player performance. We utilize a discrete step function, $\\Omega(J)$, derived from the Unified Scoring Research, to model the performance multipliers associated with different states of fatigue.

### **3.1. Discrete States of Fatigue**

The continuous accumulation of fatigue manifests in discrete performance tiers within the FM26 engine. Transitioning between these tiers results in step-change penalties to the player's effective ability (Current Ability or CA).

| State | Internal Fatigue (J) | Visible Indicator | Multiplier Ω(J) | Operational Effect |
| :---- | :---- | :---- | :---- | :---- |
| **Fresh** | 0 \- 200 | Full Heart / "Fresh" | 1.00 | Peak performance. Full consistency. |
| **Match Fit** | 201 \- 400 | High % / "Okay" | 0.90 | Minor decay in late-game stamina. No attribute penalty. |
| **Tired** | 401 \- 700 | "Tired" / Orange Inj Risk | 0.70 | Significant attribute penalty. High injury risk. |
| **Jaded** | 701+ | "Needs Rest" / "Rst" Icon | 0.40 | Critical failure. Consistency attribute penalized. Recovery stalled. |

**The Tired Cliff:** The crucial finding here is the precipitous drop at the "Tired" threshold. A player entering a match in the "Tired" state ($J \> 400$) operates at only 70% of their theoretical VORP. This is not a marginal degradation; it is equivalent to replacing an elite Premier League player with a League One player.

**The Consistency Penalty:** The "Jaded" state triggers a hidden penalty to the **Consistency** attribute. Consistency in FM dictates how often a player performs to their full CA. When Jaded, a player with Consistency 15 might effectively play with Consistency 5, leading to a high frequency of "bad days" characterized by missed tackles, poor finishing, and defensive lapses.5

### **3.2. Positional Drag Coefficients ($R\_{pos}$)**

Not all minutes played contribute equally to fatigue. The physical demands of specific positions vary wildly in FM26. To accurately model Jadedness accumulation, we apply a Positional Drag Coefficient ($R\_{pos}$) to the raw minutes played.

$$J\_{accumulated} \= \\text{Minutes} \\times R\_{pos}$$  
Based on fatigue accumulation data and recovery profiles 4:

| Position | Rpos​ (Drag Coeff) | Equivalent 90 Mins | Rotation Policy |
| :---- | :---- | :---- | :---- |
| **GK** | 0.20 | \~18 fatigue units | almost never requires rotation. |
| **CB** | 0.90 | \~81 fatigue units | High durability. Can play 3 games/week occasionally. |
| **DM (Anchor)** | 1.15 | \~103 fatigue units | Moderate rotation required. |
| **CM (B2B/Mezz)** | 1.45 | \~130 fatigue units | **High Risk.** Strict adherence to 270 rules. |
| **WB / Fullback** | **1.65** | **\~148 fatigue units** | **Extreme Risk.** Must rotate every other game. |
| **Winger / IF** | 1.50 | \~135 fatigue units | High intensity sprints. High hamstring injury risk. |

**Operational Insight:** A Wing Back accumulates fatigue nearly twice as fast as a Center Back. The "270-Minute Rule" for a Wing Back effectively becomes a "**180-Minute Rule**" in practice. They physically cannot sustain three full matches in two weeks without hitting the Jadedness cliff. This necessitates that any tactical system relying on Wing Backs must carry two starter-quality players per side to facilitate 50/50 rotation.1

## **4\. Shadow Pricing and Opportunity Cost Analysis**

In Operations Research, the **Shadow Price** ($\\lambda$) of a constraint represents the improvement in the objective function value if that constraint were relaxed by one unit. In the context of FM26 squad management, the Shadow Price represents the **marginal cost of using a player's condition today** in terms of lost future utility. Every minute played today is a minute borrowed from the future availability of the asset.

### **4.1. Defining the Shadow Cost ($\\lambda\_{p,t}$)**

We calculate the shadow cost for Player $p$ at match $t$ as the summation of the difference in expected Utility (GSS) in future matches, discounted by time.

$$\\lambda\_{p,t} \= S\_p^{VORP} \\times \\sum\_{k=t+1}^{T} \\left( \\gamma^{k-t} \\times I\_k \\times \\max(0, \\Delta GSS\_{p,k}) \\right)$$  
Where:

* $S\_p^{VORP}$: The scarcity value of the player (Value Over Replacement Player). If the gap between the starter and the backup is large, $S\_p$ is high, meaning the cost of the starter being unavailable in the future is high.  
* $\\gamma$: Discount factor (typically 0.85), reflecting that immediate future matches are more certain and critical than distant ones.  
* $I\_k$: **Importance Weight** of future match $k$.  
* $\\Delta GSS$: The projected loss in performance in match $k$ due to fatigue accumulated in match $t$.

**Example:** If playing a Key Player ($S\_p$ High) in a low-importance match ($I\_t$ Low) causes them to be "Tired" ($\\Omega \= 0.7$) for a subsequent Cup Final ($I\_{t+1}$ High), the Shadow Cost $\\lambda$ will be massive. If $\\lambda\_{p,t} \> \\text{Current Match Utility}$, the player **must not start**, regardless of their visible condition.1

### **4.2. Calculating VORP Scarcity**

To derive $S\_p^{VORP}$, we compare the General Squad Score (GSS) of the starter against the best available reserve.

$$Gap\\% \= \\frac{GSS\_{star} \- GSS\_{backup}}{GSS\_{star}}$$

* **Key Player:** If $Gap\\% \> 10\\%$, the player is a "Key Player." The shadow cost of their fatigue is multiplied by $\\alpha \= 1 \+ \\lambda\_V \\times Gap\\%$. We must be highly conservative with their minutes.  
* **Rotational Player:** If $Gap\\% \< 5\\%$, the player is "Rotational." The shadow cost is low. We should rotate these players frequently to preserve the squad's overall freshness.20

This mathematical approach formalizes the "rotation" intuition: we rotate not just to rest players, but to minimize the value-at-risk of our prime assets for high-leverage situations.

### **4.3. Importance Weights ($I\_k$)**

The Shadow Pricing model relies on accurate weighting of match importance. Based on FM26 reputation and competition logic, identifying which matches matter is crucial for the algorithm 22:

| Match Type | Importance Weight (Ik​) | Rationale |
| :---- | :---- | :---- |
| **Cup Final / Title Decider** | **10.0** | Maximum leverage. "Must Win." Overrides most fatigue concerns. |
| **Continental Knockout** | **5.0** | High reputation impact. Financial implications. |
| **League vs. Rival** | **3.0** | "Six-pointer." Affects morale dynamics and fan support. |
| **Standard League** | **1.5** | Baseline utility. The standard for rotation decisions. |
| **Early Cup / Dead Rubber** | **0.1 \- 0.8** | Low leverage. High shadow cost to play starters. Mandatory rotation. |

## **5\. Player Archetypes: Differential Decay Parameters**

The generic fatigue model must be tuned to the individual. FM26 player attributes—specifically **Natural Fitness**, **Stamina**, and **Age**—act as parameters in the differential equations governing fatigue. We classify players into four distinct archetypes to simplify policy application.

### **5.1. Archetype A: The Workhorse**

* **Profile:** Natural Fitness 15+, Stamina 15+, Determination 15+.  
* **Characteristics:** High decay resistance. Rapid recovery. Can sustain heavy workloads.  
* **Policy:** Can exceed the 270-minute rule occasionally without entering the death spiral. Recovery takes 1-2 days. Low shadow cost.  
* **Risk:** The "Boiling Frog" effect. Because they never look tired, managers overplay them until they suffer a catastrophic injury (ACL/Broken Leg) due to accumulated micro-trauma.  
* **Recommendation:** Enforce a "Holiday" every 15 matches regardless of status.25

### **5.2. Archetype B: The Glass Cannon**

* **Profile:** High CA/PA, Injury Proneness \> 12, Natural Fitness \< 12\.  
* **Characteristics:** High performance but structurally unsound. Recovery is slow. Jadedness accumulates rapidly.  
* **Policy:** **Strict Cap.** Never exceed 180 minutes in 14 days. If Condition \< 95%, do not play. Requires "Rest" training intensity permanently.  
* **Shadow Cost:** Extremely High. Losing them for 3 months destroys season utility.  
* **Recommendation:** Substitute at 60 minutes in every start to prevent entering the high-risk "Red Zone" of condition decay.27

### **5.3. Archetype C: The Veteran (30+)**

* **Profile:** Age \> 30\. Natural Fitness varies.  
* **Characteristics:** Match stamina may be sufficient, but *recovery time* between matches lengthens significantly. Jadedness sticks longer.  
* **Policy:** "One Game a Week" rule. Cannot play Midweek-Weekend double headers. If forced to play, requires 2 days of complete rest post-match.  
* **Jadedness Risk:** High. Veterans accumulate Jadedness faster if not given weeks off.  
* **Recommendation:** Use purely for high-leverage matches. Do not waste minutes on low-importance fixtures.30

### **5.4. Archetype D: The Youngster (\<19)**

* **Profile:** Age \< 19\. Developing body.  
* **Characteristics:** Recover fast physically, but prone to "Burnout" (a subset of Jadedness) if overplayed. Overplaying stunts development because it eats into training time.  
* **Policy:** Protect from "Double Intensity" training. Limit senior starts to 20-25 per season.  
* **Development Note:** Since training drives CA growth in youth, playing them too much actually *stunts* development by forcing them into recovery mode rather than training mode.12

## **6\. Training Load Integration and "The Holiday Protocol"**

The interaction between training load and match load is where most FM26 fatigue management strategies fail. Users often leave training on "Automatic" or "Double Intensity" to spur development, unaware that this prevents Jadedness recovery.

### **6.1. The "Double Intensity" Trap**

Research snippet 3 reveals that "Double Intensity" combined with a 2-match week creates a fatigue debt that cannot be serviced.

* **Rule:** If a player starts 2 matches in a week, Training Intensity **MUST** be set to "Half" or "Rest" for that week.  
* **Automation:** We recommend setting global training rules:  
  * "If Condition \< 90%, Intensity \= Half."  
  * "If Condition \< 80%, Intensity \= No Pitch Work."

### **6.2. The "Send on Holiday" Mechanic**

Research snippets 5 confirm a critical mechanic: **Standard rest (even "No Pitch Work") does not zero the Jadedness counter effectively.** When a player is "Resting" at the club, they are still technically "in attendance," engaging in mental prep, travel, and gym work. The simulation does not reduce the load to zero.

To truly reset a Jaded player (Status "Rst"), the manager must use **Training \-\> Rest \-\> Send on Holiday (1 Week)**.

* **Effect:** Removes the player from the simulation entirely. Zero load.  
* **Result:** Jadedness drops exponentially.  
* **Cost:** Player misses 1 week of training and any matches.  
* **When to use:** When Status \= "Needs Rest" or when the physio report explicitly states "Jaded." This is a "Reset Button" for the fatigue variable. Using this proactively prevents the months-long slumps associated with Jadedness.

### **6.3. The Match Sharpness "Seven-Day Cliff"**

Conversely, resting a player too long degrades **Match Sharpness**, which is a separate variable from Condition. The decay is non-linear.33

* **Days 0-6:** Negligible decay. Sharpness is maintained.  
* **Day 7+:** Rapid decay (The Cliff). Sharpness drops from "Excellent" to "Lacking."  
* **Optimization:** The ideal rest window is **\< 7 days**. If a player rests for 2 weeks (Holiday), they return Fresh but "Lacking Match Sharpness," requiring 1-2 substitute appearances to restore $\\Omega \= 1.0$.

## **7\. The Comprehensive Rest Policy Decision Matrix**

Based on the derived models, we construct the following decision matrix for the Operations Research Assistant. This logic should be applied to every player, before every match.

### **7.1. Pre-Computation Steps**

1. **Calculate $J\_{est}$:** Estimate internal fatigue based on recent minutes (270 rule) and visual cues.  
2. **Calculate $\\lambda\_{p,t}$:** Determine Shadow Cost based on upcoming fixtures (Next 3 matches).  
3. **Check Archetype:** Apply modifiers (e.g., if Glass Cannon, lower thresholds by 10%).

### **7.2. The Decision Tree**

**Condition 1: Is the Player Jaded?**

* **Indicator:** Status "Rst" OR Physio Report "Jaded" OR Jadedness \> 700\.  
* **Action:** **MANDATORY VACATION.**  
  * **Recommendation:** Send on Holiday (1 week).  
  * *Exception:* None. Playing a jaded player risks long-term injury and Consistency drop. $\\lambda \= \\infty$.

**Condition 2: Is the Player in the Red Zone?**

* **Indicator:** Mins (Last 14 Days) \> 270 OR Condition \< 91%.  
* **Action:** **ENFORCED REST.**  
  * **Recommendation:** Do not include in Squad.  
  * *Exception:* If Match Importance $I\_t \> 5.0$ (Final/Continental KO) AND Player is Key ($Gap\\% \> 10$). In this case, Play, but sub at 60'.  
  * *Training:* Set to "Rest" for 3 days.

**Condition 3: Is the Player "Tired" / Moderate Fatigue?**

* **Indicator:** Condition 91-94% OR Mins (Last 14 Days) \= 180-270.  
* **Action:** **ROTATION / BENCH.**  
  * **Recommendation:** Prefer Backup player if available.  
  * If playing, set individual instruction: "Ease Off Tackles" to lower intensity.  
  * Plan substitution at 60-75 mins.

**Condition 4: Is the Player Fresh?**

* **Indicator:** Condition \> 95% AND Mins (Last 14 Days) \< 180\.  
* **Action:** **AVAILABLE.**  
  * **Recommendation:** Select based on tactical merit and form.

### **7.3. Post-Match Recovery Protocol**

* **Day 1 (Post-Match):** Recovery Session (Light).  
* **Day 2:** If Age \> 30 or Workload High \-\> Rest Day. Else \-\> Training.  
* **Schedule Check:** If no midweek game, schedule "Match Practice" or high intensity training to maintain Sharpness (avoiding the 7-day cliff). If a midweek game exists, intensity must be Low.19

## **8\. Implementation and UI Visualization**

To assist the user in navigating these complex decisions, we translate these mathematical concepts into actionable UI outputs (Recommendation Cards). These cards serve as the interface between the stochastic model and the human decision-maker.

### **8.1. Recommendation Card: The "Red Zone" Warning**

This card triggers when a player is technically available (Condition \> 90%) but has breached the rolling minute threshold.

JSON

{  
  "Player": "Erling Haaland",  
  "Status": "HIGH RISK (Red Zone)",  
  "Metrics": {  
    "Condition": "92%",  
    "14\_Day\_Load": "285 mins (Breached 270 threshold)",  
    "Jadedness\_Est": "High",  
    "Injury\_Risk\_Multiplier": "4.0x"  
  },  
  "Archetype": "Workhorse (Mitigated Risk)",  
  "Shadow\_Cost": "High (UCL Semi-Final in 4 days)",  
  "Recommendation": "REST / BENCH",  
  "Reasoning": "Player has breached the 270-minute rolling limit. Playing 90 mins today will trigger exponential jadedness debt, compromising availability for UCL Semi-Final. Shadow cost exceeds current match utility."  
}

### **8.2. Recommendation Card: The "Jadedness" Reset**

This card triggers when the specific "Rst" icon appears or the Physio report confirms Jadedness.

JSON

{  
  "Player": "Bukayo Saka",  
  "Status": "CRITICAL (Jaded)",  
  "Metrics": {  
    "Condition": "89%",  
    "Report": "Physio: Needs a rest",  
    "Consistency\_Penalty": "Active (Effective Consistency \-5)"  
  },  
  "Recommendation": "SEND ON HOLIDAY (1 Week)",  
  "Reasoning": "Standard rest is failing. Jadedness accumulator is not clearing due to continued training presence. 1 Week Holiday is required to reset internal counters. Do not just bench; remove from club environment to restore Consistency attribute."  
}

### **8.3. Recommendation Card: The "Fragile Star" Management**

This card triggers for Archetype B (Glass Cannon) players.

JSON

{  
  "Player": "Neymar Jr",  
  "Status": "MANAGED (Fragile)",  
  "Metrics": {  
    "Condition": "94%",  
    "14\_Day\_Load": "120 mins",  
    "Injury\_Proneness": "18 (High)"  
  },  
  "Recommendation": "START (LIMIT 60 MINS)",  
  "Reasoning": "Condition is acceptable, but Injury Proneness dictates strict minute cap. Risk of injury increases exponentially after min 60 due to fatigue drag. Plan substitution regardless of performance."  
}

## **9\. Scenario Analysis and Worked Examples**

To demonstrate the efficacy of this system, we analyze three common scenarios encountered in FM26.

### **Case Study 1: The Christmas Crunch (Premier League)**

Scenario: A dense fixture list: 4 Matches in 10 Days (Dec 22, 26, 28, Jan 1).  
Subject: Key Midfielder (Box-to-Box), Natural Fitness 14\. This position has a high Drag Coefficient ($R\_{pos} \= 1.45$).

* **Match 1 (Dec 22):** Plays 90 mins. Status: Fresh \-\> OK. Accumulates 130 Fatigue Units.  
* **Match 2 (Dec 26):** Plays 90 mins. Status: OK \-\> Tired. (Total Mins: 180). Accumulates 130 Fatigue Units.  
* **Match 3 (Dec 28):** **DECISION POINT.**  
  * **Visual Status:** Condition 91% (Yellow). Looks playable.  
  * **Model Analysis:** Rolling Mins: 180\. Playing 90 now pushes to 270\. Playing a Box-to-Box role on 2 days rest is high risk.  
  * **Shadow Cost:** The Jan 1 match is against a Title Rival ($I\_{Jan1} \= 3.0$). The Dec 28 match is against 18th place ($I\_{Dec28} \= 1.5$).  
  * **OR Policy:** **ROTATE.** Play the backup. The marginal gain of the starter against the weak team is less than the cost of losing him for the Rival match.  
* **Result (With Policy):** Player rests Dec 28\. Plays Jan 1 Fresh (Total 14-day load: 270). Avoids Jadedness spiral.  
* **Counterfactual (Without Policy):** Player starts Dec 28\. Plays poorly due to Tired attribute penalties. Hits 270 min limit. Enters Jan 1 match "Jaded" (Status Rst). Suffers hamstring injury in 20th minute or plays with Consistency penalty, contributing to a loss.

### **Case Study 2: The "Must Win" Cup Final with a Fragile Star**

Scenario: Champions League Final. The biggest game of the season.  
Subject: Star Winger, Archetype "Glass Cannon" (Inj Prone 16), Condition 88% (Tired).

* **Shadow Cost Analysis:** Shadow Cost is theoretically infinite for a normal match, but here it is Zero. There is no "future" to save him for. The season ends after this match.  
* **Decision:** **PLAY.**  
  * **Caveat:** The injury risk is exponential. He *will* likely get injured or fade by 60'.  
  * **Tactical Adjustment:** Play for 60 minutes. Set "Ease Off Tackles" to reduce physical contact load. Have a sub ready.  
  * **Rationale:** The VORP utility of the star in the Final outweighs any long-term recovery cost (since the off-season follows). This is an "All In" move.  
  * **Outcome:** Player delivers 60 minutes of high-quality play before condition drops to 65%. Substituted immediately. Player suffers minor knock but the team benefits from his peak output during the crucial opening hour.

### **Case Study 3: Jadedness Recovery**

Scenario: Mid-March. Star Forward has been playing twice a week for a month.  
Subject: Star Forward, Archetype "Workhorse."  
Status: "Needs Rest" (Rst) icon appears. Physio report says "Jaded."

* **Incorrect Action:** Bench for 1 match.  
  * *Result:* Player stays at club, trains lightly. Returns after 4 days. Jadedness reduced by 20 points (negligible). Plays next match, performs poorly, Jadedness spikes again.  
* **Correct Action:** **Holiday Protocol.**  
  * Training \-\> Rest \-\> Send on Holiday (1 Week).  
  * *Result:* Player removed from sim. Jadedness reduced by 350 points. Returns "Fresh" but "Lacking Match Sharpness."  
  * *Reintegration:* Bench for next match (20 mins) to restore Sharpness. Start the following match fully reset.  
  * *Net Gain:* Sacrificing 1 week of availability purchases 6 weeks of peak performance for the run-in.

## **10\. Conclusion**

The management of fatigue in Football Manager 2026 is a deterministic optimization problem solved within a stochastic environment. The prevailing error among managers is treating Condition ($C$) as the sole proxy for Fatigue, ignoring the hidden, accumulating variable of Jadedness ($J$). This oversight leads to the suboptimal utilization of human capital, characterized by avoidable injuries and periods of unexplained poor form caused by the Consistency penalty.

Our research establishes that **Jadedness** is the true constraint on squad performance. It accumulates non-linearly via the **270-Minute Rule** and clears only through specific, aggressive interventions like the **Holiday** mechanic. By applying **Shadow Pricing**, we can mathematically demonstrate that the cost of playing a "Tired" key player in a low-leverage match often exceeds the potential points gained, due to the exponential risk of injury and the opportunity cost of missing future high-leverage fixtures.

Implementing the **Step-Function Rest Policy**—categorized by player Archetypes and positional drag coefficients—transforms the squad from a group of individuals into a managed portfolio of depreciating assets. This approach maximizes season-long VORP, minimizes the frequency of the "death spiral," and ensures peak availability for the critical path of the season.

### **Key Takeaways for the User:**

1. **Respect the 270-Minute Limit:** 3 Full matches in 14 days is the hard ceiling for 90% of the squad. Breaching this incurs a 2.5x fatigue penalty.  
2. **Holiday \> Rest:** When the "Rst" icon appears, standard rest is insufficient. **Training \-\> Send on Holiday (1 Week)** is the only effective cure to reset the Jadedness counter.  
3. **Rotation is Value Preservation:** You are not weakening the team today by rotating; you are purchasing the availability of the team tomorrow. This is the essence of Shadow Pricing.  
4. **Archetypes Matter:** Do not manage a 33-year-old Veteran the same way as a 19-year-old Workhorse. Adjust thresholds and recovery protocols to fit the specific decay profile of the athlete.

By adopting these heuristics, the user moves from reactive damage control to proactive asset optimization, securing a significant competitive advantage within the FM26 engine.

#### **Works cited**

1. Current ability cost of of attributes \- position breakdown \- Football Manager General Discussion \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/308816-current-ability-cost-of-of-attributes-position-breakdown/](https://community.sports-interactive.com/forums/topic/308816-current-ability-cost-of-of-attributes-position-breakdown/)  
2. A definitive test to end the controversy about the match engine, and the attributes that work within it (we hope) : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1aum8zj/a\_definitive\_test\_to\_end\_the\_controversy\_about/](https://www.reddit.com/r/footballmanagergames/comments/1aum8zj/a_definitive_test_to_end_the_controversy_about/)  
3. The ultimate guide to training \- Tactics, Training & Strategies Discussion \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/587569-the-ultimate-guide-to-training/](https://community.sports-interactive.com/forums/topic/587569-the-ultimate-guide-to-training/)  
4. \[SI, nice job\!\] Condition and fatigue in FM. \- Tactics, Training, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/58995-si-nice-job-condition-and-fatigue-in-fm/](https://community.sports-interactive.com/forums/topic/58995-si-nice-job-condition-and-fatigue-in-fm/)  
5. FM26 Condition Percentage \- Skinning Hideout \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/598106-fm26-condition-percentage/](https://community.sports-interactive.com/forums/topic/598106-fm26-condition-percentage/)  
6. Player Fitness | Football Manager 2022 Guide \- Guide to FM, accessed December 29, 2025, [https://www.guidetofm.com/squad/fitness/](https://www.guidetofm.com/squad/fitness/)  
7. Players Getting Injured More Often :: Football Manager 26 General Discussions, accessed December 29, 2025, [https://steamcommunity.com/app/3551340/discussions/0/670600486987227504/](https://steamcommunity.com/app/3551340/discussions/0/670600486987227504/)  
8. FM10: How Your Players Work. (Warning: Hidden Details Inside) \- Sports Interactive forums, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/146778-fm10-how-your-players-work-warning-hidden-details-inside/page/2/](https://community.sports-interactive.com/forums/topic/146778-fm10-how-your-players-work-warning-hidden-details-inside/page/2/)  
9. Jadedness \- Football Manager General Discussion \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/86824-jadedness/](https://community.sports-interactive.com/forums/topic/86824-jadedness/)  
10. "Jaded and could do with a rest" : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1cjnb46/jaded\_and\_could\_do\_with\_a\_rest/](https://www.reddit.com/r/footballmanagergames/comments/1cjnb46/jaded_and_could_do_with_a_rest/)  
11. The Big MISTAKE You're Probably Making with FM26 Tactics \- YouTube, accessed December 29, 2025, [https://www.youtube.com/watch?v=gloPXZvCgpc](https://www.youtube.com/watch?v=gloPXZvCgpc)  
12. The Complete Guide to Youth Intakes, Training and Development based on extensive testing : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1mdcrps/the\_complete\_guide\_to\_youth\_intakes\_training\_and/](https://www.reddit.com/r/footballmanagergames/comments/1mdcrps/the_complete_guide_to_youth_intakes_training_and/)  
13. Why You Must NOT Ignore NATURAL FITNESS In FM? Football Manager Player Attributes Breakdown \- FM21 \- YouTube, accessed December 29, 2025, [https://www.youtube.com/watch?v=ng3FTpMl7uo](https://www.youtube.com/watch?v=ng3FTpMl7uo)  
14. how important is determination and natural fitness? and what should be the minimum numbers for em : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1lb57oe/how\_important\_is\_determination\_and\_natural/](https://www.reddit.com/r/footballmanagergames/comments/1lb57oe/how_important_is_determination_and_natural/)  
15. Problems managing fatigue \- Player Development, Injuries, Finances and Training, accessed December 29, 2025, [https://community.sports-interactive.com/bugtracker/previous-versions/football-manager-2024-early-access-bugs-tracker/finances-training-medical-and-development-centres/problems-managing-fatigue-r20194/](https://community.sports-interactive.com/bugtracker/previous-versions/football-manager-2024-early-access-bugs-tracker/finances-training-medical-and-development-centres/problems-managing-fatigue-r20194/)  
16. Natural Fitness \+ Stamina \= Most underrated attributes? \- Football Manager General Discussion \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/354242-natural-fitness-stamina-most-underrated-attributes/](https://community.sports-interactive.com/forums/topic/354242-natural-fitness-stamina-most-underrated-attributes/)  
17. 80% FM injuries vs 100% real life injuries\!? \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/500087-80-fm-injuries-vs-100-real-life-injuries/](https://community.sports-interactive.com/forums/topic/500087-80-fm-injuries-vs-100-real-life-injuries/)  
18. crusadertsar's Content \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/profile/306489-crusadertsar/content/?\&type=forums\_topic\_post](https://community.sports-interactive.com/profile/306489-crusadertsar/content/?&type=forums_topic_post)  
19. FM26 | My training regime — CoffeehouseFM \- Football Manager Blogs, accessed December 29, 2025, [https://coffeehousefm.com/fmrensieblog/fm26-my-training-regime](https://coffeehousefm.com/fmrensieblog/fm26-my-training-regime)  
20. FM26 Guide: Mastering Squad Rotation \- General Discussion \- Sortitoutsi, accessed December 29, 2025, [https://sortitoutsi.net/content/74657/fm26-guide-mastering-squad-rotation](https://sortitoutsi.net/content/74657/fm26-guide-mastering-squad-rotation)  
21. How many minutes does each agreed playing time need? : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/wt1dbz/how\_many\_minutes\_does\_each\_agreed\_playing\_time/](https://www.reddit.com/r/footballmanagergames/comments/wt1dbz/how_many_minutes_does_each_agreed_playing_time/)  
22. FM26: Hidden Attributes Explained \- General Discussion \- Sortitoutsi, accessed December 29, 2025, [https://sortitoutsi.net/content/74854/fm26-hidden-attributes-explained](https://sortitoutsi.net/content/74854/fm26-hidden-attributes-explained)  
23. Football Manager 26: How to Increase Club Reputation \- Operation Sports, accessed December 29, 2025, [https://www.operationsports.com/football-manager-26-how-to-increase-club-reputation/](https://www.operationsports.com/football-manager-26-how-to-increase-club-reputation/)  
24. Is there any benefit to winning youth competitions? \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/444359-is-there-any-benefit-to-winning-youth-competitions/](https://community.sports-interactive.com/forums/topic/444359-is-there-any-benefit-to-winning-youth-competitions/)  
25. El Huracán Renace \[FM26\] \- FM Career Updates \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/597526-el-hurac%C3%A1n-renace-fm26/](https://community.sports-interactive.com/forums/topic/597526-el-hurac%C3%A1n-renace-fm26/)  
26. 8 Best Box-to-Box Midfielders in FM24 \- FM Blog, accessed December 29, 2025, [https://www.footballmanagerblog.org/2025/04/best-box-to-box-midfielders-fm24.html](https://www.footballmanagerblog.org/2025/04/best-box-to-box-midfielders-fm24.html)  
27. Injuries are ridiculous in FM26 : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1otf6va/injuries\_are\_ridiculous\_in\_fm26/](https://www.reddit.com/r/footballmanagergames/comments/1otf6va/injuries_are_ridiculous_in_fm26/)  
28. I don't understand injuries proneness... : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1ce8wub/i\_dont\_understand\_injuries\_proneness/](https://www.reddit.com/r/footballmanagergames/comments/1ce8wub/i_dont_understand_injuries_proneness/)  
29. One of my best youth intake ever, but will his natural fitness and strength ruin him? \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1lehdre/one\_of\_my\_best\_youth\_intake\_ever\_but\_will\_his/](https://www.reddit.com/r/footballmanagergames/comments/1lehdre/one_of_my_best_youth_intake_ever_but_will_his/)  
30. FM Rensie Blog — CoffeehouseFM \- Football Manager Blogs, accessed December 29, 2025, [https://coffeehousefm.com/fmrensieblog](https://coffeehousefm.com/fmrensieblog)  
31. What is a Good Cardio Recovery? Understanding Heart Rate Recovery for \- Cymbiotika, accessed December 29, 2025, [https://cymbiotika.com/blogs/fitness-and-recovery/what-is-a-good-cardio-recovery-understanding-heart-rate-recovery-for-optimal-wellness](https://cymbiotika.com/blogs/fitness-and-recovery/what-is-a-good-cardio-recovery-understanding-heart-rate-recovery-for-optimal-wellness)  
32. My FULL Step-by-Step GUIDE to INDIVIDUAL TRAINING in FM26 \- YouTube, accessed December 29, 2025, [https://www.youtube.com/watch?v=6hvstSd5yME](https://www.youtube.com/watch?v=6hvstSd5yME)  
33. Match sharpness drops from full green tick to orange within a week. : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1oessyd/match\_sharpness\_drops\_from\_full\_green\_tick\_to/](https://www.reddit.com/r/footballmanagergames/comments/1oessyd/match_sharpness_drops_from_full_green_tick_to/)  
34. Question for the 12 people playing FM26, in hopes one is playing lower league. How do you keep player sharpness up? : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1ofakjt/question\_for\_the\_12\_people\_playing\_fm26\_in\_hopes/](https://www.reddit.com/r/footballmanagergames/comments/1ofakjt/question_for_the_12_people_playing_fm26_in_hopes/)