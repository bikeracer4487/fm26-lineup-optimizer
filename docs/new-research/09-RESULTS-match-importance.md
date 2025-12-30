# **Automated Match Importance Classification System: A Multi-Objective Optimization Framework for Football Simulation**

## **1\. Executive Summary**

The modernization of football management simulations requires a departure from manual, high-friction user inputs toward intelligent, context-aware automation. This report details the research, design, and implementation specifications for an **Automated Match Importance Classification System (AMICS)**. Currently, the burden of designating match priority—determining whether a fixture requires the strongest XI, a rotated squad, or a youth-development focus—falls entirely on the user. This manual process is prone to fatigue, inconsistency, and a lack of strategic foresight, often leading to suboptimal squad management and reduced immersion.

Our proposed solution leverages principles from **Operations Research (OR)**, specifically multi-objective optimization and the knapsack problem, combined with **Sports Science** heuristics regarding acute-chronic workload ratios and fatigue recovery. The AMICS engine calculates a dynamic **Final Importance Score (FIS)** for every fixture by synthesizing static competition tiers with dynamic modifiers including Championship Leverage (mathematical impact on season outcomes), Opponent Strength (Elo/Reputation metrics), and Physiological Necessity (squad sharpness and fatigue latency).

This report provides a granular breakdown of the mathematical models governing these classifications, the algorithmic logic for identifying "Sharpness" opportunities, and the user interface protocols required to present these suggestions transparently. By automating this critical strategic layer, we shift the user's cognitive load from administrative tedium to high-level managerial decision-making, aligning the simulation with the operational realities of modern elite football management.

## ---

**2\. Introduction: The Strategic Imperative of Rotation**

In the realm of football management simulations, the manager's primary resource is not money, but **player fitness**. The accumulation of fatigue and the degradation of match sharpness are the twin constraints that govern all tactical decisions. As highlighted in guides for *Football Manager 2026*, successful rotation is essential to keep injuries to a minimum, maintain morale, and ensure backup players remain match-sharp.1 However, the current paradigm relies on the user to manually assess the "importance" of a match to determine the level of rotation required. This manual assessment is fraught with cognitive bias and operational inefficiency.

The complexity of modern football scheduling—where teams may compete in domestic leagues, primary and secondary cups, and continental tournaments simultaneously—creates a dense web of interdependencies. A decision to play a full-strength squad in a league match on Sunday has direct physiological repercussions for a Champions League tie on Wednesday. Operations research defines this as a resource allocation problem under uncertainty.2 The objective is to maximize the probability of achieving season goals (titles, qualification) while satisfying constraints on player health and availability.

The AMICS framework proposes to solve this by quantifying "Importance" as a unified scalar value. This value serves as a heuristic guide for the simulation's underlying squad selection algorithms, effectively translating the abstract concept of "match significance" into a concrete set of instructions for the AI or the user: *Play Best XI*, *Rotate Key Players*, or *Develop Youth*.

## ---

**3\. Theoretical Framework and Operations Research**

To design a robust classification system, we must first establish the theoretical underpinnings of "importance" in a competitive zero-sum game environment. We draw upon three primary domains: Operations Research, Game Theory, and Sports Analytics.

### **3.1 The Knapsack Problem in Squad Selection**

The fundamental challenge of squad management can be modeled as a variation of the **Knapsack Problem** or the **Assignment Problem**.3 The "Knapsack" represents the limited capacity of the team to expend energy in a given match. Each player represents an item with a "Value" (their contribution to winning) and a "Cost" (the fatigue incurred and the opportunity cost of not resting).

In a standard 0/1 Knapsack Problem, the goal is to maximize total value without exceeding weight capacity. In football simulation, the "capacity" is the team's collective fatigue threshold. If the Match Importance is **High**, the "Knapsack" is effectively larger; we are willing to "spend" more condition and risk higher fatigue to secure the win. If the Match Importance is **Low**, the capacity is constricted; we must prioritize low-cost items (youth players, reserves) to preserve the high-value assets (star players) for future, high-capacity events.

The AMICS acts as the regulator of this capacity. By assigning a Match\_Importance label, the system dynamically adjusts the constraints of the optimization problem. For a **High** importance match, the solver allows:

* $Fatigue\_{max} \\approx 95\\%$ (Playing tired players is acceptable).  
* $Quality\_{threshold} \= \\text{Maximum}$ (Must field best available).

For a **Low** importance match, the constraints tighten:

* $Fatigue\_{max} \\approx 85\\%$ (Risk aversion).  
* $Quality\_{threshold} \= \\text{Flexible}$ (Rotation is mandated).

### **3.2 Championship Leverage and Utility Theory**

Game Theory provides the concept of **Expected Utility**. In sports analytics, this is quantified as the **Leverage Index (LI)**.5 The LI measures how critical a specific match (or moment) is to the ultimate outcome of a season. A match with high leverage is one where the swing in "Championship Probability" (or Relegation Probability) between a win and a loss is maximal.6

We define the mathematical leverage, $L$, of a match $m$ for Team $T$ as the delta in probabilities for a specific objective $\\Omega$ (e.g., Title, Top 4, Survival):

$$L(m, T, \\Omega) \= P(\\Omega | \\text{Win}\_m) \- P(\\Omega | \\text{Loss}\_m)$$  
In a "Dead Rubber" scenario 7, the leverage approaches zero ($L \\to 0$). Operations research suggests that in scenarios of low leverage, the utility of "winning" is outweighed by the utility of "resource preservation" (resting players) or "resource development" (playing youth). The AMICS must calculate this leverage to distinguish between a league match in August (high potential variance) and a league match in May where the team is cemented in mid-table (zero variance).

### **3.3 Multi-Objective Optimization**

Real-world management involves conflicting objectives:

1. **Maximize Short-Term Success:** Win the current match.  
2. **Maximize Long-Term Success:** Win future matches (requires rest).  
3. **Asset Development:** Improve youth players (requires playing time).

This is a classic **Multi-Objective Optimization Problem (MOOP)**.8 The AMICS functions as a scalarization technique, converting these vector objectives into a single weighted score that guides the user. For instance, prioritizing "Develop Youth" in the user configuration increases the weight of objective \#3, which mathematically lowers the "Importance" threshold required to field weaker players.

## ---

**4\. The Physiological Engine: Fatigue and Sharpness**

A unique requirement of this research is the integration of "Sharpness" as a distinct importance level. This necessitates a deep dive into the physiological mechanics of football simulation, modeled on real-world sports science.

### **4.1 The Acute:Chronic Workload Ratio (ACWR)**

Research indicates that injury risk is non-linear. It spikes when the **Acute Load** (workload in the last 7 days) exceeds the **Chronic Load** (average workload over the last 28 days) by a ratio of roughly 1.5.10 Conversely, *undertraining* (a ratio \< 0.8) also increases injury risk due to a lack of conditioning.

This informs the **Schedule Modifier**. If a team faces fixture congestion (3 matches in 7 days), the acute load on key starters approaches the "danger zone" ($Ratio \> 1.5$). The system must identify the middle fixture as the optimal point to reduce load, artificially lowering its "Importance" to enforce rotation and bring the ACWR back into the "sweet spot" (0.8 – 1.3).10

### **4.2 The 72-Hour Recovery Rule**

Biological recovery is time-dependent. Studies show that 48 hours is insufficient for the full restoration of neuromuscular force production and the clearance of metabolic markers like creatine kinase.13 Performance decrements are significant at 48 hours but largely resolved by 72-96 hours.

Therefore, the AMICS must apply a severe penalty to the importance of any match occurring within 48-72 hours of a **Tier 1 (High)** fixture. If the "Next Match" is a Cup Final on Saturday, a League match on Wednesday (offset \-3 days) effectively has a "physiological cost" that is double the norm. The system must suggest **Low** or **Medium** importance for the Wednesday game to ensure the "Best XI" is on the ascending arm of the recovery curve for Saturday.

### **4.3 Match Sharpness Mechanics**

Sharpness is distinct from fatigue. It represents a player's familiarity with match intensity and tactical execution. In *Football Manager 2024*, sharpness degrades linearly with inactivity and increases with match minutes.15 A player who is "Rusty" suffers penalties to decision-making and physical output.

A **"Sharpness" Match** is a specific optimization classification where the objective function flips:

* *Standard:* Maximize Team Performance ($P\_{win}$).  
* *Sharpness:* Maximize Minutes for Rusty Players ($Min\_{rusty}$).

The system detects "Sharpness" opportunities by scanning the squad state. If the aggregate sharpness of the "Rotation" and "First Team" strata falls below a threshold (e.g., 70%), and the current match has a low Base Importance (e.g., Friendly or Dead Rubber), the system suggests **Sharpness** mode. This overrides the desire to win with the desire to rehabilitate the asset base.

## ---

**5\. Algorithmic Determination of Match Importance**

The core of the AMICS is a scoring algorithm that synthesizes the theoretical and physiological factors into a Final Importance Score (FIS). The FIS scale runs from 0 to 120+, broken down into the four required tiers.

### **5.1 Base Importance Lookup Table**

The starting point is a static value derived from the competition's prestige and the current stage. This establishes the "Default" stakes before context is applied.

**Table 1: Competition Base Importance Matrix**

| Competition Context | Stage | Base Score (0-100) | Rationale |
| :---- | :---- | :---- | :---- |
| **League (Title Race)** | Last 10 Games | **100** | Maximum leverage; outcome decides the trophy. |
| **League (Relegation)** | Last 10 Games | **100** | Existential threat; survival is paramount. |
| **League (Contention)** | Regular Season | **80** | Consistent accumulation of points is vital. |
| **League (Mid-Table)** | Any | **60** | Low leverage on title/drop; moderate stakes. |
| **League (Dead Rubber)** | Last 5 Games | **20** | Mathematically fixed position; zero leverage. |
| **Champions League** | Knockout (R16+) | **95** | Highest prestige; massive financial/reputation gain. |
| **Champions League** | Group (Open) | **85** | Qualification determines season success. |
| **Champions League** | Group (Safe/Out) | **50** | Qualification secured; opportunity to rotate. |
| **Domestic Cup (Major)** | Semi-Final / Final | **100** | Trophy opportunity; high narrative weight. |
| **Domestic Cup (Major)** | Early Rounds | **40** | Opponents often lower league; rotation expected. |
| **Secondary Cup** | Late Stages | **70** | Moderate prestige; useful for morale. |
| **Secondary Cup** | Early Rounds | **30** | Lowest competitive priority; often youth-focused. |
| **Friendlies** | Any | **10** | Purely for fitness; Base Importance is effectively zero. |

### **5.2 Dynamic Modifier Logic**

The Base Score is subjected to multipliers ($M$) and additive bonuses ($B$) to reflect the specific context of the match.

#### **5.2.1 Opponent Strength Modifier ($M\_{opp}$)**

We utilize the Relative Strength Ratio ($R\_s$):

$$R\_s \= \\frac{\\text{Opponent Reputation}}{\\text{User Team Reputation}}$$

* **Logic:** Beating a stronger opponent requires maximum resources (Best XI). Beating a significantly weaker opponent implies a high win probability even with rotation.  
* **Data Source:** Use Elo ratings or Reputation values (0-10000 scale in FM databases).16

**Table 2: Opponent Modifiers**

| Relative Strength (Rs​) | Classification | Modifier (Mopp​) |
| :---- | :---- | :---- |
| $\> 1.3$ | **Titan** | **1.2x** (Escalates importance) |
| $1.1 \- 1.3$ | **Superior** | **1.1x** |
| $0.9 \- 1.1$ | **Peer** | **1.0x** (Neutral) |
| $0.6 \- 0.9$ | **Inferior** | **0.8x** (Rotation encouraged) |
| $\< 0.6$ | **Minnow** | **0.6x** (Heavy rotation expected) |

#### **5.2.2 Schedule Context Modifier ($M\_{sched}$)**

This modifier integrates the physiological constraints (ACWR and 72-hour rule). It looks ahead to the *next* fixture to determine if the current match acts as a "setup" or "sacrifice."

$$M\_{sched} \= f(\\text{Days to Next}, \\text{Next Match Priority})$$

* **Condition A:** Next match is **High** priority AND Days $\\le$ 3\.  
  * **Modifier:** **0.7x** (Heavy penalty). The current match is a "trap game"; resources must be conserved.  
* **Condition B:** Next match is **High** priority AND Days \= 4\.  
  * **Modifier:** **0.9x** (Slight penalty). Slight rotation advised.  
* **Condition C:** Current match is the 3rd in 7 days.  
  * **Modifier:** **0.8x** (Fatigue management). Rotation mandated by ACWR limits.  
* **Condition D:** Days since last match $\\ge$ 7\.  
  * **Modifier:** **1.1x** (Freshness bonus). Squad is fully recovered; can push harder.

#### **5.2.3 Contextual Bonuses ($B\_{context}$)**

These additive values account for narrative and psychological factors that defy pure mathematical leverage.

* **Rivalry Bonus:** $+20$. Matches against local rivals (Derbies) behave like Cup Finals due to fan expectations.18 Even a "dead rubber" derby has high narrative weight.  
* **Form Correction:** $+15$. If the user is on a losing streak ($\\ge$ 3 losses), the importance increases to secure a "morale-boosting" win.  
* **Cup Run:** $+10$. If User\_Objective includes "Cup Glory" and Round $\\ge$ QF.

## ---

**6\. Implementation Specifications: Formulating the System**

This section translates the logic into specific formulas and code structures required for implementation.

### **6.1 The Master Calculation Formula**

$$FIS \= (Base \\times M\_{opp} \\times M\_{sched} \\times M\_{user}) \+ B\_{context}$$  
Where $M\_{user}$ represents the user's customized priorities (see Section 7).

### **6.2 Python Implementation Logic**

The following Python function demonstrates the integration of these factors into a cohesive classification engine.

Python

def calculate\_match\_importance(match, team\_context, user\_config):  
    """  
    Calculates the Suggested Match Importance based on context and constraints.  
      
    Args:  
        match (Match object): Contains competition, opponent, date, etc.  
        team\_context (Context object): League position, squad freshness, upcoming schedule.  
        user\_config (Config object): User objectives and rotation tolerance.  
          
    Returns:  
        Recommendation object containing level, confidence, and reasoning.  
    """  
      
    \# \--- 1\. Base Importance Retrieval \---  
    base\_score \= get\_competition\_base\_score(match.competition, match.stage)  
    reasoning \=

    \# \--- 2\. Opponent Modifier (Elo/Reputation) \---  
    \# Relative strength calculation  
    rel\_strength \= match.opponent.reputation / team\_context.reputation  
      
    opp\_mod \= 1.0  
    if rel\_strength \> 1.3:  
        opp\_mod \= 1.2  
        reasoning.append(f"Opponent is significantly stronger (x1.2).")  
    elif rel\_strength \< 0.6:  
        opp\_mod \= 0.6  
        reasoning.append(f"Opponent is significantly weaker (x0.6).")  
      
    \# \--- 3\. Schedule Modifier (Physiological Constraints) \---  
    sched\_mod \= 1.0  
    next\_match \= team\_context.get\_next\_match(match.date)  
      
    if next\_match:  
        days\_gap \= (next\_match.date \- match.date).days  
        next\_base \= get\_competition\_base\_score(next\_match.competition, next\_match.stage)  
          
        \# 72-Hour Rule Check  
        if next\_base \>= 80 and days\_gap \<= 3:  
            sched\_mod \= 0.7  
            reasoning.append(f"Prioritizing recovery for upcoming {next\_match.opponent.name} clash (x0.7).")  
          
        \# Congestion Check (ACWR Proxy)  
        matches\_last\_7\_days \= team\_context.get\_recent\_matches\_count(7)  
        if matches\_last\_7\_days \>= 2:  
            sched\_mod \*= 0.8  
            reasoning.append("Fixture congestion active; rotation required (x0.8).")

    \# \--- 4\. User Objective Modifier \---  
    \# Adjusts weights based on user 'Manager Persona'  
    user\_mod \= user\_config.get\_weight(match.competition.type)  
    if user\_mod\!= 1.0:  
        reasoning.append(f"User objective adjustment: {user\_mod}")

    \# \--- 5\. Calculation \---  
    fis\_raw \= (base\_score \* opp\_mod \* sched\_mod \* user\_mod)  
      
    \# \--- 6\. Contextual Bonuses \---  
    if match.is\_derby:  
        fis\_raw \+= 20  
        reasoning.append("Derby match bonus (+20).")  
          
    if team\_context.losing\_streak \>= 3:  
        fis\_raw \+= 15  
        reasoning.append("Critical form correction needed (+15).")

    \# \--- 7\. Sharpness Detection Logic \---  
    \# Specialized check for 'Sharpness' designation  
    is\_sharpness\_candidate \= (  
        fis\_raw \< 50 and   
        team\_context.count\_rusty\_key\_players() \>= 3 and  
        sched\_mod \>= 1.0 \# Only if we have recovery time  
    )  
      
    if is\_sharpness\_candidate:  
        return Recommendation(  
            level="Sharpness",  
            score=fis\_raw,  
            reasoning=\["Match stakes are low.", "Key players require match fitness."\],  
            confidence=0.9  
        )

    \# \--- 8\. Final Classification \---  
    if fis\_raw \>= 85:  
        final\_level \= "High"  
    elif fis\_raw \>= 50:  
        final\_level \= "Medium"  
    else:  
        final\_level \= "Low"

    return Recommendation(level=final\_level, score=fis\_raw, reasoning=reasoning)

### **6.3 Threshold Calibration**

The mapping of the continuous FIS to discrete categories requires careful calibration to match user expectations.

* **High (FIS $\\ge$ 85):** Corresponds to "Must Win." These are matches where losing has severe consequences on the primary objective.  
* **Medium (50 $\\le$ FIS \< 85):** Corresponds to "Important." Winning is desired, but not at the cost of long-term injury risks.  
* **Low (FIS \< 50):** Corresponds to "Rotation." The marginal utility of fielding a star player is lower than the utility of resting them.  
* **Sharpness (Logic Override):** Takes precedence over "Low" when the "Rusty Player" count is high.

## ---

**7\. User Configuration and Persona Profiling**

To ensure the system feels responsive rather than restrictive, it must adapt to the user's specific managerial style. We introduce **Manager Profiles** in the configuration schema. These profiles fundamentally alter the user\_mod weights in the algorithm.

### **7.1 Configuration Schema (JSON)**

JSON

{  
  "manager\_persona": {  
    "id": "youth\_developer",  
    "name": "The Architect",  
    "description": "Prioritizes long-term development over short-term cup success.",  
    "weights": {  
      "league": 1.0,  
      "major\_cup": 0.8,  
      "secondary\_cup": 0.5,  
      "continental": 1.2  
    },  
    "rotation\_tolerance": "high",  
    "youth\_bias": true  
  },  
  "objectives": {  
    "primary": "win\_league",  
    "secondary": "develop\_youth"  
  },  
  "overrides": {  
    "always\_high": \["derby", "final"\],  
    "always\_low": \["friendly"\]  
  }  
}

### **7.2 Profile Impact Analysis**

* **"The Architect" (Youth Developer):** Reduces the importance of Cup matches significantly (0.8 / 0.5). This artificially lowers the FIS for early cup rounds, triggering the "Low" classification more often, which is the system's signal to play youth.  
* **"The Pragmatist" (Relegation Fighter):** Increases League weight to 1.3 while reducing Continental/Cup weights to 0.6. This ensures the system prioritizes survival over "distractions," suggesting heavy rotation in cups even against strong opponents.  
* **"The Glory Hunter" (Cup Specialist):** Sets Cup weights to 1.2. The system will suggest "High" importance for a Quarter-Final even if it causes fatigue issues for a subsequent league match.

## ---

**8\. User Interface Specification: Explainable AI (XAI)**

The success of an automated system depends on **trust**. Users will only accept the recommendation if they understand *why* it was made. The UI must present the "Reasoning" vector generated by the algorithm.

### **8.1 The Match Briefing Card**

The UI should display a "Assistant Manager's Recommendation" card during the pre-match flow.

**Visual Components:**

1. **The Verdict:** Large, color-coded badge (e.g., **HIGH** in Red).  
2. **The Confidence Meter:** A percentage bar indicating how "clear-cut" the decision was. (e.g., FIS=95 is 100% confidence; FIS=84 \[borderline\] is 60% confidence).  
3. **Key Drivers (Bullet Points):**  
   * *“Title Race Implications: A win moves us to 1st place.”*  
   * *“Opponent Strength: Manchester City is a Tier 1 opponent.”*  
   * *“Schedule Warning: Short turnaround (2 days) before Champions League semi-final.”*  
4. **The "Sharpness" Call to Action:**  
   * If "Sharpness" is selected: *“Target: Give 60+ minutes to \[Player A\], to restore match fitness.”*

### **8.2 Override Feedback Loop**

When a user disagrees with the suggestion, the system should offer immediate feedback based on the simulated consequences.

* **Scenario:** System suggests **High**, User selects **Low**.  
* **Warning Modal:** *"Warning: Reducing importance against a Tier 1 opponent decreases win probability by roughly 40%. A loss here places the 'Board Confidence' metric at risk. Are you sure?"*

This immediate feedback loop reinforces the mathematical reality of the simulation, educating the user on the trade-offs they are making (Operations Research concept: **Shadow Price** of a decision).

## ---

**9\. Validation Scenarios and Edge Cases**

To verify the robustness of the AMICS, we apply it to three distinct archetypal scenarios found in football simulations.

### **Scenario A: The "Giant Killing" Setup**

* **Context:** FA Cup 3rd Round. User (Premier League) vs. League Two Team (Minnow).  
* **Base Score:** 40 (Cup Early Round).  
* **Opponent Mod:** 0.6 (Minnow).  
* **Schedule Mod:** 1.0 (Standard week).  
* **Calculation:** $40 \\times 0.6 \\times 1.0 \= 24$.  
* **Result:** **Low** (FIS \< 50).  
* **Validation:** Correct. The user should rotate heavily. If the user plays the Best XI, they are wasting resources.

### **Scenario B: The "Congestion Crunch"**

* **Context:** League Match (Mid-table opponent). Wednesday fixture. User is chasing the title. Crucial Champions League QF follows on Saturday (3 days later).  
* **Base Score:** 80 (League Contention).  
* **Opponent Mod:** 1.0 (Peer).  
* **Schedule Mod:** 0.7 (Next match is Tier 1, gap $\\le$ 3 days).  
* **Calculation:** $80 \\times 1.0 \\times 0.7 \= 56$.  
* **Result:** **Medium**.  
* **Validation:** Correct. The system recognizes the league points are valuable (Base 80\) but the physiological cost of the upcoming CL tie forces a compromise. The suggestion shifts from "High" to "Medium," advising partial rotation rather than full strength.

### **Scenario C: The "Sharpness" Opportunity**

* **Context:** Pre-season Friendly or Dead Rubber League Match. 4 Star players have Match Sharpness \< 70%.  
* **Base Score:** 20 (Dead Rubber).  
* **Opponent Mod:** 0.8 (Weaker).  
* **Calculation:** $20 \\times 0.8 \= 16$.  
* **Classification Logic:**  
  1. FIS \= 16 (Low).  
  2. Check ShouldSuggestSharpness:  
     * Is Low? Yes.  
     * Rusty Key Players \> 3? Yes.  
     * Recovery time \> 3 days? Yes.  
* **Result:** **Sharpness**.  
* **Validation:** Correct. The system identifies that the *utility* of this match is not the result, but the conditioning.

## ---

**10\. Conclusion**

The design of the Automated Match Importance Classification System (AMICS) represents a shift from passive data entry to active strategic assistance. By rigorously applying operations research principles—treating the squad as a constrained resource and the season as a multi-objective optimization problem—we can generate recommendations that are mathematically sound and narratively satisfying.

The key innovation is the integration of the **Schedule Modifier** and **Sharpness Detection**. These mechanisms directly address the "grind" of squad management, automating the complex calculus of fatigue management that casual users often struggle with and hardcore users find tedious. By making the reasoning transparent through the UI, the system not only suggests *what* to do but educates the user on *how* to think like a manager, ultimately deepening the simulation experience.

## ---

**11\. Appendix: Deliverables Summary**

### **A. Base Importance Tables**

(See Table 1 in Section 5.1)

### **B. Modifier Formulas**

(See Python Code in Section 6.2 and Formulas in Section 5.2)

### **C. Sharpness Detection Logic**

(See Section 4.3 and Code in 6.2)

### **D. User Configuration Schema**

(See JSON in Section 7.1)

### **E. UI Specifications**

(See Section 8.1)

### **F. Override Handling**

(See Section 8.2)

#### **Works cited**

1. FM26 Guide: Mastering Squad Rotation \- General Discussion \- Sortitoutsi, accessed December 29, 2025, [https://sortitoutsi.net/content/74657/fm26-guide-mastering-squad-rotation](https://sortitoutsi.net/content/74657/fm26-guide-mastering-squad-rotation)  
2. Decision Support System Applications for Scheduling in Professional Team Sport. The Team's Perspective \- PMC \- NIH, accessed December 29, 2025, [https://pmc.ncbi.nlm.nih.gov/articles/PMC8213205/](https://pmc.ncbi.nlm.nih.gov/articles/PMC8213205/)  
3. The Knapsack Problem, accessed December 29, 2025, [https://www.utdallas.edu/\~scniu/OPRE-6201/documents/DP3-Knapsack.pdf](https://www.utdallas.edu/~scniu/OPRE-6201/documents/DP3-Knapsack.pdf)  
4. Knapsack problem \- Wikipedia, accessed December 29, 2025, [https://en.wikipedia.org/wiki/Knapsack\_problem](https://en.wikipedia.org/wiki/Knapsack_problem)  
5. LI | Sabermetrics Library \- FanGraphs, accessed December 29, 2025, [https://library.fangraphs.com/misc/li/](https://library.fangraphs.com/misc/li/)  
6. (PDF) Measuring the importance of football match \- ResearchGate, accessed December 29, 2025, [https://www.researchgate.net/publication/259975676\_Measuring\_the\_importance\_of\_football\_match](https://www.researchgate.net/publication/259975676_Measuring_the_importance_of_football_match)  
7. Out-of-sample prediction accuracy of different models over 1000... \- ResearchGate, accessed December 29, 2025, [https://www.researchgate.net/figure/Out-of-sample-prediction-accuracy-of-different-models-over-1000-repetitions-Values-are\_fig5\_373417279](https://www.researchgate.net/figure/Out-of-sample-prediction-accuracy-of-different-models-over-1000-repetitions-Values-are_fig5_373417279)  
8. (PDF) Optimizing Team Sport Training With Multi-Objective Evolutionary Computation, accessed December 29, 2025, [https://www.researchgate.net/publication/354845934\_Optimizing\_Team\_Sport\_Training\_With\_Multi-Objective\_Evolutionary\_Computation](https://www.researchgate.net/publication/354845934_Optimizing_Team_Sport_Training_With_Multi-Objective_Evolutionary_Computation)  
9. Players' selection for basketball teams, through Performance Index Rating, using multiobjective evolutionary algorithms \- NIH, accessed December 29, 2025, [https://pmc.ncbi.nlm.nih.gov/articles/PMC6726145/](https://pmc.ncbi.nlm.nih.gov/articles/PMC6726145/)  
10. Acute to chronic workload ratio (ACWR) for predicting sports injury risk: a systematic review and meta-analysis \- PMC \- NIH, accessed December 29, 2025, [https://pmc.ncbi.nlm.nih.gov/articles/PMC12487117/](https://pmc.ncbi.nlm.nih.gov/articles/PMC12487117/)  
11. The acute:chonic workload ratio in relation to injury risk in professional soccer \- PubMed, accessed December 29, 2025, [https://pubmed.ncbi.nlm.nih.gov/27856198/](https://pubmed.ncbi.nlm.nih.gov/27856198/)  
12. Spikes in acute:chronic workload ratio (ACWR) associated with a 5–7 times greater injury rate in English Premier League football players: a comprehensive 3-year study | British Journal of Sports Medicine, accessed December 29, 2025, [https://bjsm.bmj.com/content/54/12/731](https://bjsm.bmj.com/content/54/12/731)  
13. Differences between 48 and 72-hour intervals on match load and subsequent recovery: a report from the Brazilian under-20 national football team \- PMC \- NIH, accessed December 29, 2025, [https://pmc.ncbi.nlm.nih.gov/articles/PMC10850290/](https://pmc.ncbi.nlm.nih.gov/articles/PMC10850290/)  
14. 72 Hours Not Enough? – FSI Lab Examines Recovery in Football \- FSI Training, accessed December 29, 2025, [https://fsi.training/en/post-match-recovery-footballers-fsi-lab/](https://fsi.training/en/post-match-recovery-footballers-fsi-lab/)  
15. FM24 Matchday Mechanics 4 \- Match Sharpness \- YouTube, accessed December 29, 2025, [https://www.youtube.com/watch?v=C6Rv2S7WbVA](https://www.youtube.com/watch?v=C6Rv2S7WbVA)  
16. Manager reputation and levels \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/342877-manager-reputation-and-levels/](https://community.sports-interactive.com/forums/topic/342877-manager-reputation-and-levels/)  
17. Football Club Elo Ratings, accessed December 29, 2025, [http://clubelo.com/](http://clubelo.com/)  
18. Assessing the Intensity of Sports Rivalries Using Data From Secondary Market Transactions, accessed December 29, 2025, [https://www.researchgate.net/publication/309105853\_Assessing\_the\_Intensity\_of\_Sports\_Rivalries\_Using\_Data\_From\_Secondary\_Market\_Transactions](https://www.researchgate.net/publication/309105853_Assessing_the_Intensity_of_Sports_Rivalries_Using_Data_From_Secondary_Market_Transactions)