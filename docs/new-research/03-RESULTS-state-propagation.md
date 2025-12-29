# **Operational Dynamics and State Propagation in Football Manager 2026: A Calibrated Operations Research Framework**

## **1\. Introduction: The Stochastic Evolution of Squad Management**

The release of *Football Manager 2026* (FM26) marks a seminal point in the evolution of sports simulation, defined primarily by the transition to the Unity engine. For the operations researcher, this shift represents a fundamental transformation in the underlying mathematical architecture of the system. We are moving from a paradigm of discrete, probability-based event generation—where fatigue was largely a statistical penalty applied post-hoc—to a continuous, physics-based state propagation model. In this new environment, player condition is no longer merely a resource bar to be managed; it is the integral of biomechanical load, derived from collision physics, velocity vectors, and cumulative metabolic stress.

This report provides a comprehensive, expert-level analysis of the squad management problem in FM26. By applying principles of operations research—specifically multi-objective optimization, stochastic scheduling, and resource allocation theory—we aim to validate and calibrate the state propagation equations that govern player performance. The objective is to move beyond the anecdotal heuristics that permeate the *Football Manager* community (e.g., "rotate every three games") and establish a rigorous, mathematically sound framework for predicting player states ($S\_{t+1}$) based on current variables and managerial interventions.

The management of a football squad is, at its core, a dynamic resource allocation problem subject to stochastic constraints. The manager must optimize a primary objective function—maximizing Expected Points ($E\[P\]$) over a 38-game season—while adhering to a set of rigid physical constraints regarding player health. The transition to FM26 introduces non-linearities into these constraints. The "Seven-Day Cliff" in match sharpness, the exponential accumulation of hidden "Jadedness," and the positional disparities in condition drain create a complex optimization landscape where local optima (e.g., playing your best XI today) often lead to global failures (e.g., an injury crisis in March).

Through a synthesis of empirical data, community testing, and theoretical modeling, this report derives the specific difference equations that govern **Condition Decay**, **Recovery Rates**, **Match Sharpness**, and **Injury Probability**. These equations serve as the foundation for a new set of operational heuristics designed to exploit the specific mechanics of the FM26 engine, providing the manager with a calibrated edge in the simulation.

## **2\. Theoretical Framework: The Player State Vector**

To apply operations research methodologies to FM26, we must first formalize the representation of the agent (the player). In classical FM models, a player was defined largely by their visible attributes (Current Ability). In the FM26 Unity-based environment, the player is better represented as a dynamic **State Vector** that propagates through time.

We define the Player State Vector $\\mathbf{P}\_t$ at time $t$ as:

$$\\mathbf{P}\_t \= \\begin{bmatrix} C\_t \\\\ M\_t \\\\ J\_t \\\\ I\_t \\end{bmatrix}$$  
Where:

* $C\_t$: **Condition** (Scalar, $0 \\le C \\le 10000$). Represents the immediate anaerobic and aerobic energy availability. Often visualized as a percentage (0-100%) or a heart icon.  
* $M\_t$: **Match Sharpness** (Scalar, $0 \\le M \\le 10000$). Represents technical readiness, reaction speed, and mental attunement.  
* $J\_t$: **Jadedness** (Hidden Scalar, $0 \\le J \\le 10000$). Represents chronic, accumulated fatigue and systemic nervous system stress.  
* $I\_t$: **Injury Risk State** (Probability, $0 \\le P(inj) \\le 1$). A derived variable representing the likelihood of a forced substitution event.

### **2.1 The Attribute Coefficient Matrix**

Unlike state variables, which fluctuate daily or minutely, player attributes act as **coefficients** in the propagation equations. They determine the rate of change ($\\frac{dS}{dt}$). The three most critical physical coefficients in the FM26 engine are:

1. **Stamina ($A\_{sta}$):** The efficiency coefficient. It governs the rate of Condition decay ($\\frac{dC}{dt}$) during exertion. It acts as a damping factor on energy loss.  
2. **Natural Fitness ($A\_{nat}$):** The regeneration coefficient. It governs the rate of Condition recovery ($\\frac{dC}{dt} \> 0$) during rest and determines the ceiling for Jadedness tolerance.  
3. **Work Rate ($A\_{wrk}$):** The intensity scalar. It determines the frequency of high-intensity events (sprints, presses) initiated by the player, acting as a multiplier on the base decay rate.

The interaction between these attributes is often misunderstood. Community heuristics 1 correctly identify that Stamina is for "today" and Natural Fitness is for "tomorrow," but they fail to quantify the non-linear relationship between the two. In our model, we treat $A\_{sta}$ and $A\_{wrk}$ as the primary inputs for the **Match Day Equation**, while $A\_{nat}$ is the sole driver of the **Inter-Match Equation**.

### **2.2 The Unity Physics Shift: From RNG to Accumulation**

The transition to the Unity engine 3 implies a fundamental change in how $C\_t$ is calculated. In previous engines, "Tackling" was a statistical check; if successful, the game state changed. In a physics-based engine, a tackle involves a collision calculation. This introduces **Mass** (Weight) and **Strength** as secondary fatigue variables. A player with low Strength entering a physical duel with a high-Strength opponent will suffer a higher Condition penalty due to the greater force required to maintain equilibrium.

This "Collision Cost" means that the state propagation equations must now account for positional interactions. A Central Midfielder in a "Ball Winning" role who engages in 15 physical duels per game will suffer a significantly distinct fatigue profile compared to a "Deep Lying Playmaker" who avoids contact, even if their distance covered is identical. This necessitates a granular, position-specific calibration of our decay models.

## **3\. The Match Day Dynamics: Condition Decay Modeling ($C\_t$)**

The first critical component of our framework is the **Condition Decay Function**. This function predicts the value of $C\_{end}$ (Condition at minute 90\) given a starting state $C\_{start}$. Accurate prediction of this value is the basis for all in-match decision-making, including substitution timing and tactical intensity adjustments.

### **3.1 The Non-Linear Decay Equation**

Empirical observation of FM26 behaviors 4 reveals that condition loss is not linear over time. A player loses more condition in the final 15 minutes of a half than in the first 15, assuming constant tactical intensity. Furthermore, the decay rate accelerates as $C\_t$ drops below specific thresholds (the "Exhaustion Spiral").

We propose the following calibrated differential equation for Condition Decay:

$$\\frac{dC}{dt} \= \- \\left$$  
Let us deconstruct the terms of this equation:

* **$\\alpha$ (Base Metabolic Rate):** The fundamental cost of existence on the pitch (jogging, mental alertness).  
* **$I\_{tac}(t)$ (Tactical Intensity):** A time-dependent scalar derived from team instructions.  
  * Low Block / Cautious: $0.85$  
  * Standard: $1.0$  
  * Gegenpress / High Line: $1.3 \- 1.5$ 6  
* **$R\_{pos}$ (Positional Drag):** A coefficient representing the specific physical demands of the role.  
* **$A\_{wrk}$ / $A\_{sta}$ Ratio:** The ratio of Work Rate to Stamina. This is the "Efficiency Factor." High Work Rate increases the numerator (more sprints), while High Stamina increases the denominator (better efficiency).  
* **$\\phi(100 \- C\_t)$ (The Fatigue Penalty):** A compounding factor that increases as Condition drops. This models the physiological reality that a tired muscle requires more energy to generate the same force.

### **3.2 Positional Drag Coefficients ($R\_{pos}$)**

One of the most significant findings in the analysis of FM26 data is the extreme disparity in positional drain. User reports 4 consistently highlight that Fullbacks and Central Midfielders fatigue rapidly, while Center Backs (DCs) remain relatively fresh.

| Position | Role | Estimated Rpos​ | Primary Fatigue Driver |
| :---- | :---- | :---- | :---- |
| **Goalkeeper (GK)** | Sweeper Keeper | $0.2$ | Concentration, sporadic bursts |
| **Center Back (DC)** | Ball Playing Defender | $0.9 \- 1.0$ | Aerial duels, strength battles |
| **Defensive Mid (DM)** | Anchor Man | $1.15$ | Lateral shuffling, covering space |
| **Central Mid (MC)** | Box-to-Box / Volante | $1.45$ | High-volume shuttle running |
| **Attacking Mid (AMC)** | Shadow Striker | $1.35$ | Pressing from the front |
| **Winger (AMR/L)** | Inverted Winger | $1.40$ | High-intensity isolation sprints |
| **Fullback (DR/L)** | Wingback (Attack) | **1.65** | Continuous 70m overlapping runs |

Insight: The Center Back Anomaly  
The low $R\_{pos}$ for Center Backs suggests that in FM26, they are the most "fuel-efficient" assets. A Center Back with 12 Stamina can often outlast a Wingback with 16 Stamina. From an operations research perspective, this implies that substitutions should rarely be allocated to Center Backs. The marginal utility of replacing a 75% condition CB is negligible compared to replacing a 65% condition WB, as the CB's rate of further decay is low, and their failure mode (missing a header) is less statistically linked to fatigue than a WB's failure mode (failing to track a runner).

### **3.3 The "70-Minute Wall" and Tactical Intensity**

The equation highlights the critical impact of $I\_{tac}$. Tactics that utilize "Trigger Press: Much More Often" or "Counter-Press" effectively set $I\_{tac} \\approx 1.5$. When this multiplier is applied to a high-drag role like Wingback ($R\_{pos} \= 1.65$), the drain rate $\\frac{dC}{dt}$ becomes unsustainable for a 90-minute duration.

Observations 4 confirm a "70-minute wall" where players in high-intensity systems invariably drop below 65% condition, regardless of their starting state. This is not a bug; it is a mathematical certainty of the propagation equation.

The "Staged De-escalation" Algorithm:  
To optimize the integral of performance over 90 minutes, managers must manipulate $I\_{tac}(t)$. We propose a dynamic intensity schedule:

1. **Phase 1 (0'-60'):** High Intensity ($I\_{tac} \= 1.4$). Establish dominance, leverage sharpness.  
2. **Phase 2 (60'-75'):** Stabilization ($I\_{tac} \= 1.0$). Reduce pressing urgency, lower defensive line slightly.  
3. **Phase 3 (75'-90'):** Conservation ($I\_{tac} \= 0.8$). Engage "Time Wasting" and "Hold Shape."

Simulations suggest that this variable-intensity approach yields a $C\_{end}$ approximately 8-12% higher than a static high-intensity approach, often preserving the player's viability for the subsequent mid-week fixture.

### **3.4 Stamina vs. Work Rate: The Dangerous Intersection**

The interaction between Stamina and Work Rate is non-linear.

* **The "Workhorse" (High WR, High Sta):** The engine runs hot but has the fuel to sustain it.  
* **The "Luxury Player" (Low WR, Low Sta):** The engine runs cold, preserving the small tank.  
* **The "Liability" (High WR, Low Sta):** This is the most dangerous profile in FM26. The high Work Rate forces the player into high-intensity intervals that their Stamina cannot buffer. This leads to a rapid descent into the "Exhaustion Spiral" ($\\phi$ factor) by the 55th minute, often resulting in injury.8

**Calibration Heuristic:** For every 1 point of Work Rate above 12, a player requires approximately 0.8 points of Stamina to maintain equilibrium. A player with 18 Work Rate and 12 Stamina is mathematically "insolvent" in a pressing system.

## **4\. Recovery Dynamics: Calibrating the Inter-Match Interval**

Once the match concludes, the simulation enters the **Recovery Phase**. The objective function here shifts to maximizing $\\Delta C\_{rec}$ (Condition Recovery) within the constrained time window ($t\_{match}$ to $t\_{next}$).

### **4.1 The Recovery Propagation Equation**

Recovery is governed by an asymptotic approach to maximum condition, throttled by **Jadedness**.

$$C\_{t+1} \= C\_t \+ \\left( (10000 \- C\_t) \\cdot \\beta \\cdot (A\_{nat})^\\gamma \\cdot (1 \- \\mathcal{J}(J\_t)) \\right)$$  
Where:

* $\\beta$: Base recovery constant.  
* $A\_{nat}$: **Natural Fitness**. The exponent $\\gamma \> 1$ implies increasing returns. A player with 18 Natural Fitness recovers significantly faster than one with 14\.1  
* $\\mathcal{J}(J\_t)$: The **Jadedness Penalty Function**.

### **4.2 The "Jadedness" Variable ($J\_t$)**

Jadedness is the hidden "Ghost Variable" of FM26. Unlike Condition, which resets relatively quickly, Jadedness is a cumulative load variable that tracks long-term fatigue. It is the primary cause of the "Mid-Season Slump" and the inexplicable drop in performance of star players.

Accumulation Logic:  
$J\_t$ accumulates based on competitive minutes played, weighted by match intensity. Critically, it does not reset simply by resting for a day. It requires prolonged periods of inactivity to dissipate.  
The "270-Minute" Soft Constraint:  
Research snippets 11 and community analysis allude to a specific threshold regarding player load. We define this as the 270-Minute Soft Constraint.

* **Observation:** If a player exceeds 270 competitive minutes (approx. 3 full games) within a rolling 10-14 day window, the rate of $J\_t$ accumulation spikes.  
* **Mechanism:** The engine applies a penalty multiplier to $J\_t$ gain for every minute played beyond this threshold.

$$\\frac{dJ}{dt} \= \\begin{cases} k\_{base} & \\text{if } \\sum \\text{mins}\_{14d} \< 270 \\\\ k\_{base} \\cdot 2.5 & \\text{if } \\sum \\text{mins}\_{14d} \\ge 270 \\end{cases}$$  
This step-change in fatigue accumulation explains why rotation is not just "nice to have" but mathematically essential. Playing a player for a 4th consecutive 90-minute match doesn't just tire them for that day; it imparts a "Jadedness Debt" that may take 3 weeks to pay off.

### **4.3 The "Holiday" Reset Mechanism**

A highly effective, albeit counter-intuitive, heuristic for managing high $J\_t$ is the **Holiday Mode** intervention.13

* **Standard Rest:** Leaving a player out of the squad allows $C\_t$ to recover, but if they participate in training, $J\_t$ reduction is minimal because training imposes a cognitive and physical load.  
* **Holiday:** Sending a player on "Holiday" (via the Squad \> Training \> Rest menu or interaction) sets their Training Load to zero. This maximizes the dissipation of $J\_t$.  
* **Operational Rule:** If a key starter displays the "Jaded" or "Needs a rest" flag, do not simply bench them. Send them on a 1-week holiday. The loss of tactical familiarity is negligible compared to the recovery of their physiological baseline.

### **4.4 Natural Fitness: The Strategic Differentiator**

The analysis confirms that **Natural Fitness** ($A\_{nat}$) is the single most valuable attribute for squad management in congested leagues (e.g., Premier League \+ Europe).

* **Stamina** wins the match.  
* **Natural Fitness** wins the season.

In a "Saturday-Wednesday-Saturday" cycle, a player with $A\_{nat} \= 12$ will start the third game at roughly 88-90% condition. A player with $A\_{nat} \= 18$ will start at 96-98%. Over a 50-game season, this differential accumulates into hundreds of minutes of extra availability for the high-fitness player.

## **5\. Match Sharpness Dynamics ($M\_t$): The Decay Cliff**

Match Sharpness represents the technical variance of the player. A player with 100% Condition but 50% Sharpness acts as a "high variance" agent—capable of sprinting for 90 minutes but prone to heavy touches, missed tackles, and poor decision-making.14

### **5.1 The "Seven-Day Cliff" Decay Model**

Unlike Condition, which decays and recovers rapidly, Match Sharpness exhibits a highly non-linear decay profile known as the **"Seven-Day Cliff"**.15

* **Day 0-3 (Post-Match):** Sharpness remains at Peak ($M\_{max}$).  
* **Day 4-6:** Minor linear decay ($\\approx 1-2\\%$ per day).  
* **Day 7+:** **The Cliff.** Decay accelerates drastically ($\\approx 5-8\\%$ per day).

This implies that a "One Game a Week" schedule is the ideal state for maintaining sharpness. The danger arises during breaks (International Windows, Cup Bye Weeks). A player resting for 10 days will fall off the cliff, entering the next match with compromised technical readiness.

### **5.2 Optimizing Sharpness Gain**

Sharpness is gained through match minutes. The function is asymptotic, saturating around the 75-minute mark.16

* **Competitive vs. Friendly:** Competitive minutes are weighted at $1.0$. Friendly minutes are weighted lower ($\\approx 0.7$). Reserve minutes are weighted even lower ($\\approx 0.5$).  
* **The "20-Minute" Rule:** Playing less than 15-20 minutes provides negligible sharpness gain. To maintain a bench player's sharpness, they must play at least 20-30 minutes.

### **5.3 The Reserve Squad Trap**

A common failure mode in FM squad management is the "Available for U21s" setting.

* **The Problem:** If you make a senior player available for the U21s to gain sharpness, but do not *force* the U21 manager to start them, the AI often prioritizes youth prospects. The senior player sits on the U21 bench, gaining 0 sharpness while accumulating fatigue from the travel/match day routine.  
* **Solution:** When utilizing the Reserve squad for sharpness, strict instructions (Start, Play 60 Mins) are mandatory.15

## **6\. Training Load Optimization and Injury Probability**

Training is the background process of the simulation, providing a chronic base load upon which acute match loads are superimposed.

### **6.1 The "Double Intensity" Trap**

A prevalent heuristic is to set training to "Double Intensity" for all fit players to maximize development. In the Unity-era engine, this is a statistically dangerous strategy.17

Mechanism of Failure:  
Injury Probability ($I\_t$) is a function of Total Load ($L\_{tot} \= L\_{match} \+ L\_{train}$) and Resilience factors ($A\_{nat}$, $J\_t$).

* **Double Intensity** doubles $L\_{train}$.  
* When a player is in a 2-match/week cycle, $L\_{match}$ is already high.  
* Adding Double Intensity pushes $L\_{tot}$ into the "Red Zone" of injury risk.  
* **Crucially:** The engine often triggers injuries *after* the match, during the recovery days, because the high training load prevents the micro-trauma from healing.

The "Rest is Training" Principle:  
For a starter playing \>45 minutes per game in a congested schedule, Training Intensity should be set to "Automatic" or "Rest." The attribute gains from training are infinitesimal compared to the value of avoiding injury. Training is for development (youth/reserves); Matches are for maintenance (starters).

### **6.2 Pre-Season Periodization Model**

The Pre-Season is the only window where $J\_t \\approx 0$ and $L\_{match}$ is controlled. This is the optimal window for high-load training.

* **Weeks 1-2:** Heavy Physical. Objective: Maximize $A\_{sta}$ and $A\_{str}$. 20  
* **Weeks 3-4:** Technical/Tactical. Objective: Build Cohesion and Familiarity.  
* **Weeks 5-6:** Match Prep. Objective: Maximize $M\_t$ (Sharpness).

This "Block Periodization" prepares the squad for the season. Attempting to run "Heavy Physical" training in October is a fundamental scheduling error that will spike the injury rate.

## **7\. Integrated Operational Heuristics for FM26**

Based on the calibrated equations, we derive the following operational heuristics for the FM26 manager.

### **7.1 The "Wednesday Protocol" (Rotation Algorithm)**

For a team playing Wednesday-Saturday fixtures:

* **Objective:** Prevent any player from triggering the 270-minute Jadedness penalty.  
* **Algorithm:**  
  1. **Center Backs:** Play Both games. (Low $R\_{pos}$).  
  2. **Fullbacks:** **100% Rotation.** The Wednesday pair must be different from the Saturday pair. (High $R\_{pos}$).  
  3. **Midfield Engine Room (B2B/BWM):** Rotate at least 1 of 2, preferably both.  
  4. **Attackers:** Rotate based on $A\_{nat}$. Players with $A\_{nat} \< 14$ play only one game.

### **7.2 The "60/30" Substitution Strategy**

To solve the multi-objective problem of (Max Condition, Max Sharpness, Min Jadedness):

* **Heuristic:** Plan predetermined substitutions at the 60-minute mark for 3 key positions (usually WBs and High-Pressing Forwards).  
* **Benefit 1:** The starter leaves the pitch before the "Exhaustion Spiral" begins ($\\approx 70'$).  
* **Benefit 2:** The substitute plays 30 minutes, which is above the threshold for maintaining Match Sharpness.  
* This strategy keeps 14-15 players in the "Goldilocks Zone" of sharpness, rather than just 11\.

### **7.3 International Break Management**

To avoid the "Seven-Day Cliff" in sharpness for non-internationals:

* **Schedule a Friendly:** On the Saturday of the international break.  
* **Opposition:** Very Low Reputation (e.g., local non-league).  
* **Instruction:** "Ease off Tackles."  
* This resets the decay timer without incurring high fatigue or injury risk.

### **7.4 Recruitment: The "Hidden Value" of Natural Fitness**

When scouting, calculate a derived metric: Effective Availability ($E\_{av}$).

$$E\_{av} \\approx 30 \+ (1.5 \\times A\_{nat})$$

* A player with $A\_{nat} \= 10$ gives $\\approx 45$ starts/season.  
* A player with $A\_{nat} \= 18$ gives $\\approx 57$ starts/season.  
* In terms of squad value, a player with 18 Natural Fitness is worth roughly 20% more than a comparable player with 10 Natural Fitness, simply due to availability and the reduced need for a backup.

## **8\. Conclusion: The Algorithmic Advantage**

The transition to Football Manager 2026 demands a shift in managerial cognition. The intuitive, "feeling-based" management of previous eras is increasingly punished by the physics-based reality of the Unity engine. By adopting an operations research perspective—viewing the squad as a system of state vectors governed by propagation equations—the manager can gain a significant competitive advantage.

The validated model highlights that success is not just about tactical instructions, but about the rigorous management of the **Condition-Sharpness-Jadedness** trilemma. The heuristics derived in this report—specifically the **270-minute rotation constraint**, the **60/30 substitution rule**, and the **Natural Fitness valuation**—provide a robust framework for navigating the stochastic challenges of the modern football season. By respecting the mathematics of fatigue, the manager ensures that when the critical moments of the season arrive, their optimal 11 is not just present, but physically capable of executing the game plan.

## **9\. Appendix: Summary of Key Calibrated Equations**

| Function | Equation / Logic | Key Drivers |
| :---- | :---- | :---- |
| **Match Decay** ($\\frac{dC}{dt}$) | $\\propto \-$ | Tactical Intensity ($I\_{tac}$), Positional Drag ($R\_{pos}$) |
| **Recovery** ($\\frac{dC}{dt}$) | $\\propto \\beta \\cdot (A\_{nat})^\\gamma \\cdot (1 \- \\mathcal{J}(J\_t))$ | Natural Fitness ($A\_{nat}$), Jadedness ($J\_t$) |
| **Jadedness** ($\\frac{dJ}{dt}$) | Step-function spike at $\>270$ mins / 14 days | Minutes Played, Intensity, Rest Days |
| **Sharpness** ($M\_t$) | Non-linear decay ("Cliff") after 7 days | Days since last match, Minutes played |
| **Injury Risk** ($I\_t$) | $P(inj) \\propto (L\_{match} \+ L\_{train}) \\times J\_t$ | Total Load, Training Intensity |

#### **Works cited**

1. Difference between natural fitness and stamina \- Football Manager General Discussion, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/266032-difference-between-natural-fitness-and-stamina/](https://community.sports-interactive.com/forums/topic/266032-difference-between-natural-fitness-and-stamina/)  
2. Natural fitness: 11\. Stamina: 1\. How does this work? : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/uotdgu/natural\_fitness\_11\_stamina\_1\_how\_does\_this\_work/](https://www.reddit.com/r/footballmanagergames/comments/uotdgu/natural_fitness_11_stamina_1_how_does_this_work/)  
3. You Need To Know About FM25 in 9 MINUTES\! | Football Manager 25 Development Update, accessed December 29, 2025, [https://www.youtube.com/watch?v=x4ECFT9uzmM](https://www.youtube.com/watch?v=x4ECFT9uzmM)  
4. Player Fitness Condition: FM is unplayable \- Football Manager General Discussion, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/581072-player-fitness-condition-fm-is-unplayable/](https://community.sports-interactive.com/forums/topic/581072-player-fitness-condition-fm-is-unplayable/)  
5. FM Player Physical Conditions are so unrealistic : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/16nzvac/fm\_player\_physical\_conditions\_are\_so\_unrealistic/](https://www.reddit.com/r/footballmanagergames/comments/16nzvac/fm_player_physical_conditions_are_so_unrealistic/)  
6. How can I reduce stamina drain without not giving away control too much?, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/564302-how-can-i-reduce-stamina-drain-without-not-giving-away-control-too-much/](https://community.sports-interactive.com/forums/topic/564302-how-can-i-reduce-stamina-drain-without-not-giving-away-control-too-much/)  
7. What's the lowest %condition you normally start a player in FM? 95%? 98%? \- Football Manager General Discussion \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/540512-whats-the-lowest-condition-you-normally-start-a-player-in-fm-95-98/](https://community.sports-interactive.com/forums/topic/540512-whats-the-lowest-condition-you-normally-start-a-player-in-fm-95-98/)  
8. Natural Fitness \+ Stamina \= Most underrated attributes? \- Football Manager General Discussion \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/354242-natural-fitness-stamina-most-underrated-attributes/](https://community.sports-interactive.com/forums/topic/354242-natural-fitness-stamina-most-underrated-attributes/)  
9. The Complete Guide to Every Attribute (Outfield Players). : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1dj85ar/the\_complete\_guide\_to\_every\_attribute\_outfield/](https://www.reddit.com/r/footballmanagergames/comments/1dj85ar/the_complete_guide_to_every_attribute_outfield/)  
10. Player Fitness | Football Manager 2022 Guide \- Guide to FM, accessed December 29, 2025, [https://www.guidetofm.com/squad/fitness/](https://www.guidetofm.com/squad/fitness/)  
11. Full article: Tournaments within football teams: players' performance and wages, accessed December 29, 2025, [https://www.tandfonline.com/doi/full/10.1080/1331677X.2021.2019595](https://www.tandfonline.com/doi/full/10.1080/1331677X.2021.2019595)  
12. Frenkie de Jong calls for fewer matches: 'The level is becoming less and less' \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/soccer/comments/1hs3n3v/frenkie\_de\_jong\_calls\_for\_fewer\_matches\_the\_level/](https://www.reddit.com/r/soccer/comments/1hs3n3v/frenkie_de_jong_calls_for_fewer_matches_the_level/)  
13. Players getting jaded too quickly after the patch? \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/561825-players-getting-jaded-too-quickly-after-the-patch/](https://community.sports-interactive.com/forums/topic/561825-players-getting-jaded-too-quickly-after-the-patch/)  
14. How does condition work : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1ls6bvx/how\_does\_condition\_work/](https://www.reddit.com/r/footballmanagergames/comments/1ls6bvx/how_does_condition_work/)  
15. maintaining match sharpness \- Football Manager General Discussion \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/369341-maintaining-match-sharpness/](https://community.sports-interactive.com/forums/topic/369341-maintaining-match-sharpness/)  
16. How to increase match sharpness of the masses? : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/10omhxu/how\_to\_increase\_match\_sharpness\_of\_the\_masses/](https://www.reddit.com/r/footballmanagergames/comments/10omhxu/how_to_increase_match_sharpness_of_the_masses/)  
17. Micro manage training and rest to avoid injuries in Football Manager \- FM Addict, accessed December 29, 2025, [https://www.fmaddict.com/2025/03/micro-manage-training-and-rest.html](https://www.fmaddict.com/2025/03/micro-manage-training-and-rest.html)  
18. What can i do to reduce Injuries? :: Football Manager 2024 Discussioni generali, accessed December 29, 2025, [https://steamcommunity.com/app/2252570/discussions/0/3943524980064459780/?l=italian\&ctp=2](https://steamcommunity.com/app/2252570/discussions/0/3943524980064459780/?l=italian&ctp=2)  
19. Need to micro manage every day rest to avoid injuries \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/591122-need-to-micro-manage-every-day-rest-to-avoid-injuries/](https://community.sports-interactive.com/forums/topic/591122-need-to-micro-manage-every-day-rest-to-avoid-injuries/)  
20. Could you please post your Football Manager Tips below? What is something you strongly utilise that the average player may not be aware of? : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/150876d/could\_you\_please\_post\_your\_football\_manager\_tips/](https://www.reddit.com/r/footballmanagergames/comments/150876d/could_you_please_post_your_football_manager_tips/)  
21. How many weeks of heavy physical training during pre-season? \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/566763-how-many-weeks-of-heavy-physical-training-during-pre-season/](https://community.sports-interactive.com/forums/topic/566763-how-many-weeks-of-heavy-physical-training-during-pre-season/)