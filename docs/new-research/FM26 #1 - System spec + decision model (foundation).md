# **Operational Research Framework for Automated Squad Management in Competitive Sports Simulation (Football Manager 2026\)**

## **1\. System Specification: Formalizing the Lineup Selection Problem**

The development of an automated companion application for *Football Manager 2026* (FM26) necessitates the translation of complex, stochastic football management heuristics into a deterministic, solvable mathematical model. The problem of squad management is fundamentally a **resource constrained scheduling problem** where the "resources" (players) have dynamic, state-dependent attributes (condition, sharpness, fatigue) that degrade with use and recover with rest.

This system specification decomposes the problem into three distinct operational layers: the **Single-Match Assignment Problem** (optimizing $t=0$), the **Multi-Period Planning Problem** (optimizing $t=0 \\dots 4$), and the **Constraint Management Layer** (handling user overrides).

### **A) Single-Match Lineup Generation (The Assignment Module)**

The core engine for generating a valid starting XI for a single fixture is modeled as a **Generalized Assignment Problem (GAP)**, specifically a variation of the Linear Sum Assignment Problem (LSAP). While the classic LSAP seeks a one-to-one mapping between agents and tasks, the football domain introduces complexity through positional eligibility (a player can map to multiple specific slots but not others) and the new FM26 mechanic of split In-Possession (IP) and Out-of-Possession (OOP) roles.

#### **Inputs**

To solve for a single match context $\\Omega$, the system requires the following inputs:

* **Player Set ($P$):** The set of all available squad members $\\{p\_1, p\_2, \\dots, p\_n\\}$.  
* **Tactical Slot Set ($S$):** The set of 11 starting positions $\\{s\_1, s\_2, \\dots, s\_{11}\\}$. Crucially, each slot $s\_j$ is defined as a tuple of roles: $s\_j \= \\langle R\_{IP}, R\_{OOP} \\rangle$.  
  * *Example:* Slot $s\_3$ might be $\\langle \\text{Inverted Wingback (Left)}, \\text{Fullback (Left)} \\rangle$.  
* **Player State Vector ($x\_i$):** For each player $p\_i$:  
  * **Positional Ratings ($r\_{i, role}$):** A dictionary mapping every role in the game to a scalar rating (0–200).  
  * **Positional Familiarity ($fam\_{i, pos}$):** A scalar (1–20) representing experience in the geometric position (e.g., D(L), DM, ST).  
  * **Physical State:** Condition ($C\_i \\in $), Match Sharpness ($Sh\_i \\in $), and Fatigue/Jadedness ($F\_i \\in \\text{Enum}\\{Fresh, Low, High, Jaded\\}$).  
  * **Status Flags:** Boolean flags for $IsInjured$, $IsBanned$, $IsCupTied$, $IsLoanRestricted$.  
* **Match Context ($\\Omega$):**  
  * **Importance ($Imp$):** $\\in \\{High, Medium, Low, Sharpness\\}$.  
  * **Fixture Density:** Days until the *next* match ($D\_{next}$).

#### **Outputs**

The assignment module produces:

* **Assignment Matrix ($X$):** An $11 \\times n$ binary matrix where $x\_{j,i} \= 1$ implies player $p\_i$ is assigned to slot $s\_j$.  
* **Objective Value ($Z$):** The total "Match Utility Score" of the lineup, representing the theoretical strength of the XI.  
* **Exclusion Log:** A structured log of players who were eligible but not selected, with specific reason codes (e.g., "Condition Failure," "Sharpness Optimization").

#### **Hard Constraints (Must Never Be Violated)**

1. Slot Coverage: Every tactical slot must be assigned exactly one player.

   $$\\sum\_{i=1}^{n} x\_{j,i} \= 1, \\quad \\forall j \\in \\{1, \\dots, 11\\}$$  
2. Player Uniqueness: A player can be assigned to at most one slot.

   $$\\sum\_{j=1}^{11} x\_{j,i} \\le 1, \\quad \\forall i \\in \\{1, \\dots, n\\}$$  
3. Availability: If player $p\_i$ has a blocking status flag (Injured, Banned), they cannot be assigned.

   $$Status\_i \\in \\{Injured, Banned\\} \\implies \\sum\_{j} x\_{j,i} \= 0$$  
4. **Goalkeeper Eligibility:** The slot corresponding to the Goalkeeper (GK) must be filled by a player capable of playing GK (Rating \> Threshold). Outfield players cannot be assigned to the GK slot under normal operations.

#### **Soft Constraints (Violated with Penalties)**

1. **Positional Familiarity:** Assigning a player to a slot where their familiarity is low ($\< 10/20$) incurs a heavy utility penalty, but is not strictly forbidden (to allow for emergency cover).  
2. **Condition Thresholds:** Assigning a player below the "Safety Threshold" (e.g., 90% Condition) incurs a non-linear penalty increasing with the severity of the deficit.  
3. **Role Suitability:** Assigning a player to a slot where their specific role rating is low incurs a penalty, even if they are familiar with the position.

#### **Failure Modes and Edge Cases**

* **Infeasibility:** If injuries reduce the pool of eligible players below 11 (or 1 GK), the algorithm must return a specific error code ("Insufficient Players") rather than an empty or partial solution.  
* **The "Polyvalent" Problem:** Players who can play 6+ positions (e.g., James Milner types) can create "swapping" instability where the algorithm drastically reconfigures the backline to accommodate one change in midfield.  
* **GK Crisis:** If no dedicated GK is available, the hard constraint on GK eligibility must be relaxable via a specific "Emergency GK" override flag.

### ---

**B) 5-Match Planning (Sequence of Assignments)**

The multi-period problem extends the single-match assignment into the temporal domain. We define a planning horizon $H=5$ matches. The decision at $t=0$ affects the state of the squad at $t=1$ through fatigue accumulation and sharpness changes.

#### **Inputs**

* **Initial Squad State ($S\_0$):** The complete state vector of all players at the current date.  
* **Fixture Schedule ($M$):** An ordered list of 5 matches $\\langle m\_1, \\dots, m\_5 \\rangle$, where each $m\_k$ contains:  
  * $Date\_k$: Calendar date of the match.  
  * $Imp\_k$: Importance level.  
  * $OpponentDifficulty\_k$: Estimated strength of the opposition.  
* **Recovery Model Parameters:**  
  * $\\rho\_{base}$: Base condition recovery per rest day.  
  * $\\delta\_{decay}$: Sharpness decay rate per week of inactivity.  
  * $\\gamma\_{fatigue}$: Fatigue accumulation rate per 90 minutes played.

#### **Outputs**

* **Plan Sequence:** A list of 5 Assignment Matrices $\\langle X\_1, \\dots, X\_5 \\rangle$.  
* **State Trajectory:** Predicted Condition ($C\_{i,k}$) and Sharpness ($Sh\_{i,k}$) for all players $i$ at each match step $k$.  
* **Fatigue Warnings:** A set of alerts identifying players at risk of entering the "Jaded" state due to the proposed schedule (e.g., "Player X is scheduled for 4 consecutive starts; high injury risk in Match 5").

#### **Hard Constraints**

* **Temporal Availability:** A player sent off (Red Card) in Match $k$ is ineligible for Match $k+1$ (assuming standard league rules).  
* **Recovery Floor:** A player cannot be scheduled for Match $k$ if their predicted condition $C\_{i,k}$ falls below the absolute minimum safety floor (e.g., 60%), regardless of importance.

#### **Soft Constraints**

* **Rotation Consistency:** Minimize "extreme" rotation where the XI changes by \>9 players between matches, as this impacts "Tactical Familiarity" (though modeled abstractly here).  
* **Key Player Preservation:** In "High Importance" matches, the system is penalized for *not* selecting the highest-rated available players.

#### **Failure Modes**

* **Fatigue Spirals:** A greedy approach might play the best XI in matches 1, 2, and 3, leaving them at 65% condition for Match 4\. The 5-match planner must specifically detect and prevent this "cliff edge" scenario.  
* **Injury Uncertainty:** The plan is deterministic, but injuries are stochastic. The failure mode here is "Plan Invalidation," requiring a full re-calculation if an injury occurs in reality that wasn't in the simulation.

### ---

**C) Manual Overrides & Confirmed Lineups Behavior**

The system must function as a *Decision Support System*, meaning the human user retains ultimate authority. User overrides act as "locking constraints" that reduce the search space for the optimization algorithm.

#### **Inputs**

* **Locked Assignments ($L$):** A set of tuples $\\langle PlayerID, MatchIndex, SlotID \\rangle$ representing fixed decisions (e.g., "Player A *must* play ST in Match 2").  
* **Rejected Assignments ($R$):** A set of tuples $\\langle PlayerID, MatchIndex \\rangle$ representing exclusions (e.g., "Player B must *not* play in Match 2").

#### **Outputs**

* **Re-optimized Schedule:** A new set of assignment matrices that respect the locks $L$ and exclusions $R$ while optimizing the remaining free variables.  
* **Constraint Conflict Alerts:** If a user locks a player who is physically ineligible (e.g., Banned or Condition \< Hard Floor), the system produces an immediate error.

#### **Constraints on Recalculation**

1. **Immutable Anchors:** If $x\_{j,i,k} \\in L$, then in the optimization for match $k$, the variable $x\_{j,i}$ is fixed to 1\. The solver essentially solves for the remaining $11 \- |L\_k|$ slots.  
2. **Propagation:** A manual lock in Match 1 alters the fatigue state for Match 2\. The solver must re-simulate the state trajectory ($C\_{i,2}$) based on the user's forced decision in Match 1\. This ensures that "forcing" a player to start when tired correctly reflects the risk in subsequent matches.

#### **Edge Cases**

* **Conflicting Locks:** User locks Player A to Slot 1 *and* Slot 2 in the same match. (System must reject input).  
* **Impossible Locks:** User locks Player A to GK, but Player A has GK Rating \= 0\. (System allows this but flags a "Severe Utility Penalty").

## ---

**2\. Single-Match Scoring Model: The "Match Utility Score"**

The effectiveness of the Hungarian algorithm depends entirely on the quality of the cost matrix. We propose a multiplicative **Match Utility Score ($U\_{i,s}$)**. A multiplicative model is superior to an additive one in this domain because a failure in a critical dimension (e.g., 50% Condition) should render the player unusable, regardless of their raw ability. An additive model might allow a "World Class" player (Rating 190\) to play effectively even with a broken leg (Condition 0), which contradicts simulation mechanics.

### **3\. Derivation of the Utility Function**

The utility of Player $i$ in Slot $s$ is defined as:

$$U\_{i,s} \= B\_{i,s} \\cdot \\Phi(C\_i, \\Omega) \\cdot \\Psi(Sh\_i, \\Omega) \\cdot \\Theta(Fam\_{i,s}) \\cdot \\Lambda(F\_i)$$  
Where:

* $B\_{i,s}$: Base Effective Rating for the slot.  
* $\\Phi$: Condition Multiplier (Physiology).  
* $\\Psi$: Sharpness Multiplier (Form).  
* $\\Theta$: Familiarity Multiplier (Tactical).  
* $\\Lambda$: Fatigue/Jadedness Multiplier (Long-term health).

#### **3.1 Base Effective Rating ($B\_{i,s}$)**

With the FM26 split between In-Possession (IP) and Out-of-Possession (OOP) roles, the slot $s$ requires competence in both. A purely weighted average is insufficient because a defensive liability (OOP) is often fatal to match outcomes. We propose a **Harmonic Mean** to penalize imbalance between IP and OOP capability:

$$B\_{i,s} \= \\frac{2 \\cdot R\_{i, IP} \\cdot R\_{i, OOP}}{R\_{i, IP} \+ R\_{i, OOP}}$$  
This ensures that a player with ratings $\\{180, 20\\}$ (Great attacker, terrible defender) scores significantly lower ($36$) than a balanced player with $\\{100, 100\\}$ ($100$).

#### **3.2 Condition Multiplier ($\\Phi$)**

Research into FM mechanics 1 identifies a "Condition Cliff." Performance is relatively stable down to \~90-93%, degrades linearly to \~80%, and then collapses with exponential injury risk below 75%.

We define a **Safety Threshold ($T\_{safe}$)** based on match importance.

$$\\Phi(C\_i) \= \\begin{cases} 1.0 & \\text{if } C\_i \\ge 95 \\\\ 1.0 \- \\alpha\_{slope} (95 \- C\_i) & \\text{if } T\_{safe} \\le C\_i \< 95 \\\\ P\_{critical} & \\text{if } C\_i \< T\_{safe} \\end{cases}$$

* $P\_{critical}$: A severe penalty factor (e.g., 0.05), effectively benching the player unless no other option exists.

#### **3.3 Sharpness Multiplier ($\\Psi$)**

Sharpness ($Sh\_i$) dictates mental reactivity and technical consistency.3

* Standard Mode: Low sharpness is a penalty.

  $$\\Psi\_{std}(Sh\_i) \= 0.7 \+ 0.003 \\cdot Sh\_i \\quad (\\text{Range: } 0.7 \\text{ at } 0\\% \\to 1.0 \\text{ at } 100\\%)$$  
* Sharpness Build Mode: We invert the logic. We want to prioritize players in the "Recovery Zone" ($50\\% \\le Sh\_i \\le 90\\%$) to build their fitness, provided they aren't completely unready ($\<50\\%$).  
  $$ \\Psi\_{build}(Sh\_i) \= \\begin{cases}  
  1.2 & \\text{if } 50 \\le Sh\_i \\le 90 \\  
  1.0 & \\text{if } Sh\_i \> 90 \\  
  0.8 & \\text{if } Sh\_i \< 50  
  \\end{cases} $$

#### **3.4 Recommended Parameter Values**

The following table provides the tuned parameters for the scoring model based on the Match Importance context.

| Parameter | High Importance | Medium Importance | Low Importance | Sharpness Mode | Rationale |
| :---- | :---- | :---- | :---- | :---- | :---- |
| **Safety Threshold ($T\_{safe}$)** | 80% | 91% | 94% | 85% | In finals (High), we risk injury for quality. In friendlies (Low), \<94% implies incomplete recovery; risk is unjustified.1 |
| **Decay Slope ($\\alpha\_{slope}$)** | 0.005 | 0.015 | 0.05 | 0.01 | Steeper slope in Low importance aggressively filters out tired players. |
| **Sharpness Logic** | Standard | Standard | Standard | **Build (Bonus)** | High importance demands peak sharpness; Sharpness mode explicitly seeks to fix low values.5 |
| **Familiarity Min** | 15/20 | 12/20 | 5/20 | 10/20 | Low importance matches are ideal for retraining positions.6 |
| **Jadedness Penalty** | 0.9 | 0.6 | 0.1 | 0.5 | "Jaded" players perform poorly and risk long-term burnout; strict rest required in Low/Med games.7 |

#### **3.5 Explainability: Reason String Generation**

The UI requires human-readable justifications for algorithmic decisions. These are generated by analyzing which multiplier caused the greatest reduction in the Base Score.

* **Scenario 1: Fatigue Exclusion**  
  * *Logic:* If $\\Phi(C\_i) \< 0.5$ (Critical Penalty applied).  
  * *Output:* "Excluded due to high injury risk (Condition {C\_i}% \< Safety Threshold {T\_safe}%)."  
* **Scenario 2: Sharpness Prioritization**  
  * *Logic:* If Mode \== Sharpness AND $\\Psi(Sh\_i) \> 1.0$.  
  * *Output:* "Selected to build match fitness (Sharpness {Sh\_i}% is in target zone)."  
* **Scenario 3: Positional Incompatibility**  
  * *Logic:* If $\\Theta(Fam\_{i,s}) \< 0.7$ AND $R\_{i, IP} \> 150$.  
  * *Output:* "Avoided despite high rating: Lack of tactical familiarity ({Fam}/20)."  
* **Scenario 4: Jadedness Warning**  
  * *Logic:* If $F\_i \== Jaded$ AND Match \== High.  
  * *Output:* "Starting despite jadedness warning (High Importance Match Override)."

## ---

**3\. Five-Match Planning: The Receding Horizon Approach**

Optimizing a 5-match sequence is computationally distinct from optimizing a single match. A naive approach (solving Match 1, then Match 2, etc.) fails because it is **greedy**: it consumes the stamina of key players in early, low-importance games, leaving them unavailable for later, high-importance games.

We propose a **Receding Horizon Control (RHC)** heuristic. RHC solves for the current control action (Match 1 Lineup) by optimizing a finite time horizon ($t=0 \\dots 4$) and accounting for the *future cost* of current actions.

### **6\. The RHC Method with Shadow Pricing**

Instead of solving a massive 5-period integer program (which is NP-hard and slow for 40 players over 5 steps), we use an iterative solver with **Shadow Pricing**. We assign a "Shadow Cost" to using a player's condition today, based on their value in future matches.

#### **Pseudo-Code Implementation**

Python

FUNCTION Optimize\_Schedule(Squad, Fixtures\[0..4\]):  
    Schedule \=  
    Simulated\_Squad \= DeepCopy(Squad)

    \# Calculate "Shadow Prices" for each player  
    \# A player has a high shadow price if they are critical for a future High-Imp match  
    Shadow\_Costs \= Calculate\_Shadow\_Costs(Simulated\_Squad, Fixtures)

    FOR k FROM 0 TO 4:  
        Current\_Match \= Fixtures\[k\]  
        Cost\_Matrix \= Initialize\_Matrix(rows=Players, cols=11)

        FOR player IN Simulated\_Squad:  
            \# 1\. Calculate Standard Utility for this match  
            Utility \= Calculate\_Single\_Match\_Utility(player, Current\_Match)  
              
            \# 2\. Apply Shadow Price Penalty  
            \# If playing now prevents playing in a future High-Imp match, penalize.  
            \# We look at the "Future Value" lost.  
            Future\_Value\_At\_Risk \= Shadow\_Costs\[k\]   
              
            \# Adjusted Utility subtracts the opportunity cost  
            Adjusted\_Utility \= Utility \- Future\_Value\_At\_Risk  
              
            \# Fill Matrix (Invert to Cost for Hungarian Min)  
            Cost\_Matrix\[player\]\[slots\] \= Max\_Score \- Adjusted\_Utility

        \# 3\. Solve Assignment for Match k  
        Lineup\_k \= Hungarian\_Algorithm(Cost\_Matrix)  
        Schedule.append(Lineup\_k)

        \# 4\. State Propagation (Simulation Step)  
        FOR player IN Simulated\_Squad:  
            IF player IN Lineup\_k:  
                \# Fatigue Accumulation Mechanics   
                player.Condition \-= Estimate\_Condition\_Loss(player.Stamina, Current\_Match.Tactics)  
                player.Sharpness \+= Estimate\_Sharpness\_Gain(90\_mins)  
                player.Recent\_Minutes \+= 90  
            ELSE:  
                \# Recovery Mechanics \[8\]  
                Days\_Rest \= Days\_Between(Current\_Match, Fixtures\[k+1\])  
                player.Condition \+= Calculate\_Recovery(player.Natural\_Fitness, Days\_Rest)  
                player.Sharpness \-= Calculate\_Decay(Days\_Rest)  
                player.Recent\_Minutes \= Decay\_Recent\_Minutes(player.Recent\_Minutes)

            \# Check for Fatigue Spirals  
            IF player.Recent\_Minutes \> Threshold AND player.Natural\_Fitness \< 12:  
                player.Fatigue\_Status \= "Jaded"

    RETURN Schedule

#### **The Shadow Cost Formula**

The critical innovation here is Future\_Value\_At\_Risk.  
For a player $p$ at Match $k$:

$$Cost\_{shadow}(p, k) \= \\sum\_{m=k+1}^{4} \\left( \\frac{Imp\_m}{Imp\_{avg}} \\cdot \\frac{Utility(p, m)}{\\Delta Days\_{k,m}} \\cdot \\mathbb{I}(IsKeyPlayer(p)) \\right)$$

* **Interpretation:** If Match $m$ (in the future) is High Importance, and player $p$ is a "Key Player" (Utility is high), and the gap $\\Delta Days$ is small, the Shadow Cost is high. This effectively "reserves" the player for the future match by making them expensive to use in the current match.

#### **Complexity Analysis**

* **Hungarian Algorithm:** $O(n^3)$ where $n$ is squad size ($\\approx 40$).  
* **Horizon:** $H=5$ iterations.  
* **Total Complexity:** $O(H \\cdot n^3)$.  
* With $n=40$, $n^3 \= 64,000$. $5 \\times 64,000 \= 320,000$ operations.  
* **Performance:** In JavaScript V8 engine, this executes in $\< 50ms$, making it perfectly suitable for a real-time Electron app.

#### **Preventing Fatigue Spirals**

The "State Propagation" step explicitly models the "Death Spiral." By updating player.Condition after each assignment, the solver for Match 3 sees a player at 78% condition (due to playing M1 and M2). The Condition Multiplier ($\\Phi$) for Match 3 will naturally penalize this player, forcing rotation *before* the injury occurs. The Shadow Pricing mechanism proactively encourages this rotation earlier (in Match 2\) to ensure peak fitness for Match 3\.

## ---

**4\. Validation Plan: Evaluation and Calibration**

Validating a stochastic heuristic system requires offline simulation and metric-based analysis. We cannot rely on "Match Results" (Wins/Losses) because the FM Match Engine is RNG-heavy. Instead, we evaluate the **efficiency of resource utilization**.

### **7\. Evaluation Metrics**

1. Aggregate Team Strength (ATS):

   $$ATS \= \\sum\_{k=0}^{4} \\left( W\_{Imp, k} \\cdot \\sum\_{p \\in XI\_k} U\_{p, k} \\right)$$  
   * *Goal:* Maximize ATS. This measures if we are fielding our best players in the most important games.  
2. **Fatigue Violation Count (FVC):**  
   * Count of instances where a player starts a match with $Condition \< T\_{safe}$.  
   * *Goal:* Minimize to 0\. A non-zero FVC indicates the planner is taking dangerous risks.  
3. **Sharpness Efficiency:**  
   * Measure the standard deviation of Match Sharpness across the squad at $t=5$.  
   * *Goal:* Minimize dispersion. A low standard deviation implies the system successfully rotated fringe players (building their sharpness) while resting key players (preventing burnout).  
4. **Key Player Availability:**  
   * Percentage of "High Importance" matches where the Top 3 rated players (by CA) are eligible to start (Condition \> 90%).  
   * *Goal:* Maximize.

### **Calibration Strategy (Offline)**

To tune the parameters (e.g., $\\alpha\_{slope}$, Shadow Cost weights), we employ a **"Synthetic Season"** test suite:

* **Test Case A: "The Christmas Crunch"**  
  * *Setup:* 5 matches in 13 days (Sat-Tue-Fri-Mon-Thu). All Medium importance.  
  * *Expected Behavior:* High rotation. No player should start \> 3 consecutive games. The "Rotation Index" (unique starters / squad size) should be \> 0.7.  
* **Test Case B: "The Cup Final Protection"**  
  * *Setup:* Matches 1-4 are Low Importance. Match 5 is High Importance.  
  * *Expected Behavior:* The Top XI must be fully rested (Condition \> 98%) for Match 5\. If the system plays the Star Striker in Match 4, causing them to enter Match 5 at 94%, the test FAILS.  
* **Test Case C: "The Injury Crisis"**  
  * *Setup:* Mark all Natural Left Backs as Injured.  
  * *Expected Behavior:* The system identifies the best "out of position" candidate (e.g., a Right Back with 12/20 Left Back familiarity) rather than leaving the slot empty or picking a 1-star grey player.

### **Unit Tests for Edge Cases**

1. **The "Confirmed Lineup" Conflict:**  
   * *Action:* User locks an Injured player into the lineup.  
   * *Result:* Function must throw specific ValidationError("Player X is injured and cannot be locked").  
2. **The "GK Shortage":**  
   * *Action:* All GKs injured.  
   * *Result:* System selects outfield player with highest (albeit tiny) GK rating or specifically requests user intervention.

## ---

**5\. Explainability and UI Feedback**

To build user trust, the system must explain *why* it made specific decisions, particularly when those decisions seem counter-intuitive (e.g., benching a star player). The scoring model generates these strings dynamically.

**Example 1: The "Future Protection" Bench**

* *Situation:* Star player benched in Match 2 (Medium) ahead of Match 3 (High).  
* *Reason String:* "Resting for upcoming Derby (Match 3). Projected condition if played today: 89% (Risk)."

**Example 2: The "Sharpness Build" Selection**

* *Situation:* Rotation player selected in Match 1 (Low).  
* *Reason String:* "Selected to improve Match Sharpness (currently 62%). Opponent difficulty allows rotation."

**Example 3: The "Injury Risk" Exclusion**

* *Situation:* Key player excluded despite High Importance match.  
* *Reason String:* "Excluded: Extreme Injury Risk. Condition (74%) is below critical safety floor (75%)."

**Example 4: The "Familiarity" Warning**

* *Situation:* Player selected in unfamiliar role due to injuries.  
* *Reason String:* "Emergency Cover: Playing as 'Inverted Wingback' despite low familiarity (8/20) due to lack of alternatives."

## ---

**6\. Open Questions and Limitations**

Despite the robust mathematical framework, several "Black Box" elements of the Football Manager simulation engine remain opaque, limiting the precision of any external tool.

1. **The Jadedness Accumulator (Impact: High):**  
   * *Problem:* "Jadedness" is a hidden variable. While we can see the "Rest" icon, we do not know the exact rate of accumulation or the threshold at which it triggers.  
   * *Implication:* The companion app relies on proxies (Recent Minutes). It may underestimate jadedness for players with low Natural Fitness or hidden "Consistency" attributes.7  
   * *Mitigation:* User must be able to manually flag a player as "Needs Rest" in the UI to override the app's estimation.  
2. **Hidden Attributes Influence (Impact: Medium):**  
   * *Problem:* Attributes like **Consistency** and **Important Matches** heavily influence in-game performance ratings 1 but are invisible without save-game editing.  
   * *Implication:* The app might overvalue a flashy inconsistent player over a reliable veteran.  
   * *Mitigation:* If the app can read the "Coach Report," it can parse text strings like "Struggles in big matches" to apply heuristic penalties.  
3. **Dynamic Recovery Rates (Impact: Medium):**  
   * *Problem:* Recovery depends on the club's "Physio" quality and "Training Intensity" settings.10 The app does not technically know the user's training schedule (Double vs. Normal intensity).  
   * *Implication:* Predicted condition for Match 5 may drift from reality if the user employs "Double Intensity" training, which slows recovery.  
   * *Mitigation:* Include a global setting in the app: "Training Intensity Profile (Low/Medium/High)" to adjust the $\\rho\_{base}$ recovery parameter.  
4. **IP/OOP Weighting Obscurity (Impact: Low):**  
   * *Problem:* It is unknown exactly how the FM Match Engine weights IP vs. OOP roles for overall performance. Is it 50/50? Does it depend on the team mentality?  
   * *Implication:* Our Harmonic Mean heuristic ($B\_{i,s}$) is an educated guess.  
   * *Mitigation:* Allow advanced users to tweak the weighting (e.g., set OOP Importance to 70% for defensive tactics).

#### **Works cited**

1. WHY FATIGUE MATTERS \- OPC YOU KNOW ME : r ... \- Reddit, accessed December 28, 2025, [https://www.reddit.com/r/footballmanagergames/comments/18mv2zq/why\_fatigue\_matters\_opc\_you\_know\_me/](https://www.reddit.com/r/footballmanagergames/comments/18mv2zq/why_fatigue_matters_opc_you_know_me/)  
2. Tips to Reduce Player Fatigue in Football Manager \- Load FM Writes, accessed December 28, 2025, [https://loadfm.wordpress.com/2023/08/14/tips-to-reduce-player-fatigue-in-football-manager/](https://loadfm.wordpress.com/2023/08/14/tips-to-reduce-player-fatigue-in-football-manager/)  
3. Match sharpness | by Kumara Raghavendra | A Good Life \- Medium, accessed December 28, 2025, [https://medium.com/a-good-life/match-sharpness-a2d78d24f874](https://medium.com/a-good-life/match-sharpness-a2d78d24f874)  
4. Everything You Wish You Didn't Have To Experience But Really Ought To Know Regarding Injuries \- Strikerless, accessed December 28, 2025, [https://strikerless.com/2016/11/05/everything-you-wish-you-didnt-have-to-experience-but-really-ought-to-know-regarding-injuries/](https://strikerless.com/2016/11/05/everything-you-wish-you-didnt-have-to-experience-but-really-ought-to-know-regarding-injuries/)  
5. Super efficient Match Sharpness tip. : r/footballmanagergames \- Reddit, accessed December 28, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1cue9i6/super\_efficient\_match\_sharpness\_tip/](https://www.reddit.com/r/footballmanagergames/comments/1cue9i6/super_efficient_match_sharpness_tip/)  
6. Which role calculator that you think the best? : r/footballmanagergames \- Reddit, accessed December 28, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1j0wooc/which\_role\_calculator\_that\_you\_think\_the\_best/](https://www.reddit.com/r/footballmanagergames/comments/1j0wooc/which_role_calculator_that_you_think_the_best/)  
7. Jadedness \- Football Manager General Discussion \- Sports Interactive Community, accessed December 28, 2025, [https://community.sports-interactive.com/forums/topic/86824-jadedness/](https://community.sports-interactive.com/forums/topic/86824-jadedness/)  
8. Ambition, determination & professionalism and their effect on player development : r/footballmanagergames \- Reddit, accessed December 28, 2025, [https://www.reddit.com/r/footballmanagergames/comments/ufxwmy/ambition\_determination\_professionalism\_and\_their/](https://www.reddit.com/r/footballmanagergames/comments/ufxwmy/ambition_determination_professionalism_and_their/)  
9. FM24 Matchday Mechanics 4 \- Match Sharpness \- YouTube, accessed December 28, 2025, [https://www.youtube.com/watch?v=C6Rv2S7WbVA](https://www.youtube.com/watch?v=C6Rv2S7WbVA)