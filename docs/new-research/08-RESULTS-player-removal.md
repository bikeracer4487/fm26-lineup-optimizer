# **Optimizing Squad Composition: A Stochastic Multi-Objective Framework for Player Divestment and Roster Management**

## **Executive Summary**

The optimization of a professional football squad represents a complex resource allocation problem characterized by high dimensionality, conflicting objectives, and significant uncertainty. Modern sporting directorates no longer rely exclusively on intuition; instead, they employ algorithmic decision-support systems to manage the lifecycle of player assets. This report details the theoretical and practical architecture of a **Player Removal Decision Model**, designed to function as an autonomous "Intelligent Sporting Director."

The "Player Removal Problem" is formally defined here as a variation of the **Multidimensional Knapsack Problem (MKP)** combined with **Job Shop Scheduling** constraints. The objective is to maximize the aggregate **Contribution Score (Utility)** of the squad while strictly adhering to financial constraints (Wage Budget, Amortization), regulatory constraints (Registration Rules, Home Grown Quotas), and temporal constraints (Player Aging Curves, Contract Horizons).

This framework moves beyond rudimentary sorting based on Current Ability (CA). Instead, it integrates biological performance data 1, financial efficiency ratios 2, and hidden attribute heuristics 3 to categorize players not merely as athletes, but as depreciating or appreciating assets. The resulting model identifies surplus requirements with high precision, balancing immediate competitive needs against long-term fiscal health and developmental pathways.

## ---

**1\. Theoretical Framework: The Operations Research of Squad Management**

To engineer a robust api\_player\_removal.py module, we must first ground the problem in operations research principles. The decision to remove a player is never isolated; it triggers a cascade of effects on squad depth, registration compliance, and financial liquidity.

### **1.1 The Multidimensional Knapsack Formulation**

The classic Knapsack Problem asks how to maximize the value of items in a container given a weight limit. In squad management, the "container" is the Roster (limited to 25 players in most competitions 4), and the "weight" is multidimensional, consisting of:

1. **Wage Weight:** The salary cap or internal budget.6  
2. **Registration Slots:** The limit on Non-EU or Non-Home-Grown players.7  
3. **Positional Slots:** The requirement to have specific coverage (e.g., 2 GK, 4 CB).

We define the objective function as maximizing $Z$:

$$Z \= \\sum\_{i=1}^{n} (Utility\_i \\times x\_i)$$Subject to:$$\\sum\_{i=1}^{n} (Wage\_i \\times x\_i) \\le Budget\_{wage} \\\\ \\sum\_{i=1}^{n} (NonEU\_i \\times x\_i) \\le Limit\_{foreign} \\\\ Depth\_{min} \\le \\sum\_{i \\in Position} x\_i \\le Depth\_{max}$$  
Where $x\_i$ is a binary variable (1 if kept, 0 if removed). The removal model's task is to identify the subset of $x\_i$ that should be set to 0 to maximize $Z$ or satisfy violated constraints.9

### **1.2 The Asset Lifecycle and Job Shop Scheduling**

Unlike static items in a knapsack, football players are dynamic assets. Their utility changes over time (Aging Curves 12) and they require "processing time" (Training/Match Minutes) to develop.13

* **Inventory Holding Costs:** Keeping a player incurs wages.  
* **Depreciation:** Older players lose physical attributes.1  
* **Opportunity Cost:** A surplus senior player blocks the development pathway (Job Shop Schedule) of a high-potential youth player.15

Therefore, the removal logic must prioritize removing assets where the *Inventory Holding Cost* exceeds the *Future Utility Value*, or where the asset creates a bottleneck in the development schedule of a superior asset.

## ---

**2\. The Contribution Score: A Multi-Factor Utility Function**

The cornerstone of the removal model is the **Contribution Score (CS)**. Current implementations relying solely on Current Ability (CA) are flawed because CA is a weighted sum that often overvalues "luxury" attributes while undervaluing reliability and tactical fit.

### **2.1 Deconstructing Current Ability (CA) vs. Effective Utility**

Research into the Football Manager engine reveals that CA (0-200) is distributed based on positional weightings. For example, 'Tackling' consumes significant CA for a Centre Back but zero CA for a Striker.17 However, raw CA fails to capture *effectiveness* in a specific tactical role. A "Ball Winning Midfielder" with high CA derived from 'Passing' and 'Vision' is inefficient if the user's tactic requires 'Aggression' and 'Work Rate'.

The False Positive Problem:  
A player may have a CA of 150 (Star Player) but possess a low rating in critical role-specific attributes. The removal model must calculate Effective Ability ($CA\_{eff}$) by masking attributes against the specific weights of the played role.19

### **2.2 The Hidden Attribute Multipliers**

Perhaps the most critical oversight in basic models is the neglect of hidden attributes. Empirical testing demonstrates that attributes such as **Consistency**, **Important Matches**, and **Pressure** act as global modifiers on performance.3

* **Consistency:** A rating of 10/20 implies the player performs at their full attributes only 50% of the time (conceptually). Research indicates high consistency correlates with a 9% improvement in team performance.22  
* **Important Matches:** Determines performance variance in finals and derbies. A low rating (\<10) makes a player a liability regardless of CA.3  
* **Injury Proneness:** A high injury proneness score implies lower availability. A player available for only 60% of matches effectively costs 40% more per minute played.23

Algorithmic Implication:  
The Contribution Score must penalize players with low hidden attributes. We introduce a Reliability Coefficient ($R\_{coef}$).

$$R\_{coef} \= f(Consistency, ImportantMatches, \\frac{1}{InjuryProneness})$$

If $R\_{coef} \< 0.7$, the player is flagged as "High Risk," significantly lowering their retention value.25

### **2.3 Statistical Performance Integration (Moneyball Metrics)**

While attributes predict potential performance, actual statistics validate it. The model integrates "Moneyball" metrics to protect players who outperform their attributes (e.g., high xG per 90, high possession-adjusted interceptions).26

* **Over-performance Protection:** If a player’s average rating \> 7.20 over 20 games, they receive a "Form Shield," protecting them from removal even if their CA suggests they are surplus.19

### **2.4 Positional Importance Weighting**

Not all positions hold equal value. The "Spine" of the team (GK, CB, CM, ST) generally requires higher stability and quality than wide positions or luxury roles.

* **Scarcity Value:** A Left-Footed Centre Back or a Goalkeeper is harder to replace than a Box-to-Box Midfielder. The model applies a scalar multiplier ($W\_{pos}$) to the CS based on the scarcity of that profile in the database.29

### ---

**Deliverable A: Contribution Score Algorithm**

Python

import numpy as np

def calculate\_contribution\_score(player, squad, tactic\_config):  
    """  
    Calculates the 0-100 Contribution Score (Utility) for a player.  
      
    Args:  
        player: Player object containing attributes, stats, hidden stats.  
        squad: The Squad object for context (averages).  
        tactic\_config: Dictionary of attribute weights for the player's role.  
          
    Returns:  
        float: Final Contribution Score.  
    """  
      
    \# \--- 1\. Effective Ability (45%) \---  
    \# Instead of raw CA, we calculate weighted sum of relevant attributes.  
    \# Ref:  \- Positional weighting logic.  
    relevant\_sum \= 0  
    total\_weight \= 0  
    for attr, weight in tactic\_config\['role\_weights'\].items():  
        relevant\_sum \+= player.attributes.get(attr, 0) \* weight  
        total\_weight \+= weight  
          
    effective\_rating \= (relevant\_sum / total\_weight) \* 5.0 \# Scale to 0-100 approx  
      
    \# \--- 2\. Reliability Coefficient (20%) \---  
    \# Penalize for hidden attributes that cause variance.  
    \# Ref: \[22, 30\] \- Consistency/Pressure/Important Matches.  
      
    \# Normalize 1-20 to 0-1  
    consistency\_norm \= player.hidden.consistency / 20.0  
    pressure\_norm \= player.hidden.pressure / 20.0  
    imp\_match\_norm \= player.hidden.important\_matches / 20.0  
    injury\_penalty \= max(0, (player.hidden.injury\_proneness \- 10) / 20.0)  
      
    \# Weighted reliability mix  
    reliability\_score \= (  
        (consistency\_norm \* 0.4) \+   
        (imp\_match\_norm \* 0.3) \+   
        (pressure\_norm \* 0.3)  
    ) \* 100  
      
    reliability\_score \*= (1.0 \- injury\_penalty) \# Reduce score if injury prone  
      
    \# \--- 3\. Statistical Performance (25%) \---  
    \# Ref:  \- Form and Moneyball metrics.  
    stats\_score \= 50.0 \# Default neutral  
    if player.stats.minutes\_played \> 450:  
        \# Normalize Avg Rating (6.0 to 8.0 range maps to 0-100)  
        stats\_score \= np.clip((player.stats.avg\_rating \- 6.0) \* 50, 0, 100)  
          
    \# \--- 4\. Positional Scarcity & Importance (10%) \---  
    \# Ref: \[12, 29\]  
    pos\_multiplier \= 1.0  
    if player.position in:  
        pos\_multiplier \= 1.1 \# Spine premium  
    if player.is\_left\_footed and player.position in:  
        pos\_multiplier \+= 0.05 \# Left-footed premium  
          
    \# \--- Synthesis \---  
    \# Weights define the club's philosophy (e.g., Performance vs. Potential)  
    w\_ability \= 0.45  
    w\_reliability \= 0.20  
    w\_stats \= 0.25  
    w\_scarcity \= 0.10  
      
    final\_score \= (  
        (effective\_rating \* w\_ability) \+  
        (reliability\_score \* w\_reliability) \+  
        (stats\_score \* w\_stats) \+  
        (50 \* w\_scarcity) \# Baseline scarcity contribution  
    ) \* pos\_multiplier  
      
    return min(100.0, final\_score)

**Component Weights Justification:**

| Component | Weight | Rationale |
| :---- | :---- | :---- |
| **Effective Ability** | **45%** | Provides the baseline competence. We use weighted role attributes rather than raw CA to ensure tactical fit.18 |
| **Reliability** | **20%** | Adjusts for the "Hidden Attribute" variance. A player with high ability but low consistency is functionally a lower-tier player.22 |
| **Performance (Stats)** | **25%** | "Moneyball" integration. Validates if the attributes translate to output. Prevents removing over-performing players.26 |
| **Scarcity** | **10%** | Harder-to-replace profiles (e.g., Goalscorers, Left-footed Defenders) get a retention bonus.29 |

## ---

**3\. Future Value Assessment: Modeling Depreciation**

The removal decision is inherently a forecast. We are effectively predicting whether the asset ($P$) will appreciate ($V\_{t+1} \> V\_t$) or depreciate ($V\_{t+1} \< V\_t$).

### **3.1 The Biological Reality of Aging Curves**

Data from the Catapult VECTOR7 system and extensive match analysis provide definitive aging curves for professional footballers.1 The "peak" is not a singular point but a plateau, followed by a decline that varies significantly by position and attribute type.

* **Physical Peak:** 23-27 years. Speed/Explosiveness declines rapidly after 29\.1  
* **Endurance Peak:** 24-28 years. Stable until 32\.1  
* **Cognitive Peak:** 28-32 years. Attributes like Anticipation and Positioning often peak later and decline slower.29

**Position-Specific Implications:**

* **Wingers/Fullbacks:** Highly dependent on "Explosiveness." Their depreciation accelerates rapidly past age 29\. They are "High Beta" assets.12  
* **Centre Backs/GKs:** Dependent on "Cognitive" and "Strength." They retain value into their early 30s. They are "Low Beta" assets.12

### **3.2 The False Prospect Logic**

Potential Ability (PA) is a theoretical ceiling. The model must assess the *probability* of reaching that ceiling.

* **Determination & Professionalism:** High values (\>15) increase the development rate coefficient.22  
* **Game Time:** Players \< 21 need training; Players \> 18 need minutes.15  
* **The "Stalled" Flag:** If (PA \- CA) \> 20 but CA\_Growth\_Last\_12m \< 2, the player is a "False Prospect." The removal model targets these players for sale while they still hold "speculative value" to the AI transfer market.16

### ---

**Deliverable B: Future Value Model**

Python

def assess\_future\_value(player):  
    """  
    Determines the asset trajectory: Appreciating, Stable, or Depreciating.  
    Returns: Dictionary containing trajectory analysis.  
    """  
      
    \# 1\. Define Position-Specific Age Curves  
    \# Derived from \[1, 12, 29, 33\]  
    age\_curves \= {  
        "GK": {"peak\_start": 29, "peak\_end": 34, "decline": 35},  
        "DC": {"peak\_start": 27, "peak\_end": 31, "decline": 32},  
        "DL": {"peak\_start": 25, "peak\_end": 29, "decline": 30}, \# High physical load  
        "DR": {"peak\_start": 25, "peak\_end": 29, "decline": 30},  
        "DM": {"peak\_start": 26, "peak\_end": 30, "decline": 32},  
        "MC": {"peak\_start": 26, "peak\_end": 30, "decline": 32},  
        "AM": {"peak\_start": 24, "peak\_end": 28, "decline": 30}, \# Explosive reliance  
        "ST": {"peak\_start": 25, "peak\_end": 29, "decline": 31}  
    }  
      
    curve \= age\_curves.get(player.main\_position, {"peak\_start": 26, "peak\_end": 29, "decline": 30})  
      
    \# 2\. Determine Phase  
    if player.age \< curve\["peak\_start"\]:  
        phase \= "rising"  
        \# Check for stalled development   
        if player.recent\_progress\_rate \< 0.5:  
            value\_trend \= "stagnating"  
        else:  
            value\_trend \= "increasing"  
              
    elif curve\["peak\_start"\] \<= player.age \<= curve\["peak\_end"\]:  
        phase \= "peak"  
        value\_trend \= "stable"  
          
    else:  
        phase \= "declining"  
        value\_trend \= "decreasing"  
          
    \# 3\. Calculate Headroom (PA \- CA)  
    pa\_headroom \= max(0, player.pa \- player.ca)  
      
    \# 4\. Action Timing Recommendation  
    action\_timing \= "keep"  
      
    \# SELL LOGIC:  
    \# 1\. Physical positions at end of peak (e.g., Winger at 29\) \[14\]  
    if player.position in and player.age \== curve\["peak\_end"\]:  
        action\_timing \= "sell\_peak\_value"  
          
    \# 2\. Hard Decline  
    elif phase \== "declining":  
        action\_timing \= "sell\_immediate"  
          
    \# 3\. Contract Horizon   
    \# Value plummets with \< 1 year remaining  
    if player.contract\_expiry\_months \< 18 and value\_trend\!= "increasing":  
        action\_timing \= "sell\_contract\_risk"

    return {  
        "current\_phase": phase,  
        "value\_trend": value\_trend,  
        "pa\_headroom": pa\_headroom,  
        "years\_to\_peak": max(0, curve\["peak\_start"\] \- player.age),  
        "years\_until\_decline": max(0, curve\["decline"\] \- player.age),  
        "recommended\_action\_timing": action\_timing  
    }

## ---

**4\. Financial Analysis: Wage Efficiency and Amortization**

Squad management is bounded by the Wage Budget and Transfer Budget. The removal model must act as a financial auditor, identifying "toxic assets"—players whose cost exceeds their contribution.

### **4.1 Wage Structure Efficiency (30-30-30-10 Rule)**

A financially healthy squad typically follows a distribution model to prevent wage inflation.2

* **Key Players (Top 4):** 30% of Budget.  
* **First Team (Next 7):** 30% of Budget.  
* **Rotation (Next 11):** 30% of Budget.  
* **Youth/Backup:** 10% of Budget.

The model calculates a Target\_Wage for each player based on their roster tier.

$$Ratio\_{wage} \= \\frac{Actual\\\_Wage}{Target\\\_Wage}$$

* If Ratio \> 1.25 (25% overpaid), the player is financially inefficient.  
* If Ratio \> 1.50, the player is a "Wage Dump" candidate—prioritize removal even for zero transfer fee.34

### **4.2 Amortization and Book Value**

To avoid failing Financial Fair Play (FFP) or internal board expectations, the model calculates the **Book Value** of the player.35

$$Book Value \= \\frac{Transfer Fee}{Contract Length} \\times Years Remaining$$

* **Constraint:** If Market\_Value \< Book\_Value, selling realizes a loss. The model should prioritize a **Loan** (with wage contribution) to run down the amortization, unless the wage savings outweigh the accounting loss.

### **4.3 Sunk Cost Analysis**

The model explicitly rejects the "Sunk Cost Fallacy." A player bought for £50M who performs like a £10M player is treated as a £10M player. However, the *cost of release* (paying out the contract) is included in the "Release" calculation.

* *Algorithm:* Release\_Cost \= Weekly\_Wage \* Weeks\_Remaining.  
* If Release\_Cost \> Projected\_Value\_Recovery, recommend keeping in reserves or loaning.34

### ---

**Deliverable C: Financial Analysis Formula**

Python

def analyze\_financial\_impact(player, squad\_budget):  
    """  
    Audits the player's financial efficiency against the squad structure.  
    """  
      
    \# 1\. Determine Appropriate Wage Tier based on Contribution Rank  
    \# Ref:  \- The 30-30-30-10 Rule  
    tier\_definitions \= {  
        "Key": {"slots": 4, "budget\_share": 0.30},  
        "FirstTeam": {"slots": 7, "budget\_share": 0.30},  
        "Rotation": {"slots": 11, "budget\_share": 0.30},  
        "Backup": {"slots": 5, "budget\_share": 0.10}  
    }  
      
    \# Find player's rank in the squad (sorted by Contribution Score)  
    rank \= player.contribution\_rank  
      
    if rank \<= 4:  
        tier \= "Key"  
    elif rank \<= 11:  
        tier \= "FirstTeam"  
    elif rank \<= 22:  
        tier \= "Rotation"  
    else:  
        tier \= "Backup"  
          
    target\_tier\_budget \= squad\_budget.total\_allowance \* tier\_definitions\[tier\]\["budget\_share"\]  
    target\_wage\_cap \= target\_tier\_budget / tier\_definitions\[tier\]\["slots"\]  
      
    \# 2\. Calculate Ratios  
    wage\_efficiency \= player.contribution\_score / (player.weekly\_wage / 1000) \# Points per £1k  
    wage\_vs\_cap\_ratio \= player.weekly\_wage / target\_wage\_cap  
      
    \# 3\. Recommendation Logic  
    rec \= "Hold"  
    if wage\_vs\_cap\_ratio \> 1.5:  
        rec \= "Urgent Wage Dump" \# Paid 50% more than tier allows   
    elif wage\_vs\_cap\_ratio \> 1.2:  
        rec \= "Sell for Efficiency"  
    elif wage\_vs\_cap\_ratio \< 0.8:  
        rec \= "High Value Asset"  
          
    \# 4\. Amortization Check \[36\]  
    book\_value \= (player.transfer\_fee / player.original\_contract\_length) \* player.years\_remaining  
      
    return {  
        "estimated\_value": player.market\_value,  
        "book\_value": book\_value,  
        "weekly\_wages": player.weekly\_wage,  
        "wage\_efficiency": wage\_efficiency,  
        "wage\_vs\_tier\_cap\_ratio": wage\_vs\_cap\_ratio,  
        "target\_wage\_for\_status": target\_wage\_cap,  
        "recommendation": rec  
    }

## ---

**5\. Squad Balance and Constraint Satisfaction**

The **Knapsack Constraint** requires that we do not violate the structural integrity of the squad while optimizing utility.

### **5.1 Positional Depth Matrices**

We define a minimum depth requirement:

* **Starters:** 1 per position (High CA).  
* **Backups:** 1 per position (Medium CA, or Polyvalent Cover).  
* Emergency: 1 Youth/Reserve per position.  
  The model builds a "Depth Matrix" counting players capable of playing a position at \>75% competency (Accomplished/Natural). Removing a player is blocked if it drops any position below depth threshold 2.37

### **5.2 Registration Quotas (Home Grown)**

In leagues like the Premier League or Champions League, "Home Grown" (HG) status is a hard constraint.

* **Rule:** 8 HG Players total (4 Club Trained).  
* **Impact:** A surplus player who is HGC (Home Grown Club) effectively has infinite value if they are the 4th HGC player. Removing them forces an empty squad slot.  
* **Constraint Check:** IF (Player.IsHGC) AND (Total\_HGC \<= 4\) THEN Action \= KEEP (Registration Critical).4

### ---

**Deliverable D: Squad Balance Check**

Python

def check\_squad\_balance\_impact(player, squad):  
    """  
    Simulates removal to check for constraint violations (Knapsack).  
    """  
      
    balance\_impact \= {  
        "positions\_affected": player.positions,  
        "depth\_warnings":,  
        "registration\_impact": "None",  
        "blocking\_issue": False,  
        "blocking\_reason": None  
    }  
      
    \# 1\. Positional Depth Check \[37\]  
    for pos in player.positions:  
        \# Count players remaining at this position excluding current player  
        current\_depth \= len(\[p for p in squad.players if pos in p.positions and p\!= player\])  
          
        if current\_depth \< 2:  
            balance\_impact\["blocking\_issue"\] \= True  
            balance\_impact\["blocking\_reason"\] \= f"Critical Lack of Depth at {pos}"  
            balance\_impact\["depth\_warnings"\].append(f"{pos}: Drops to {current\_depth} (Critical)")  
        elif current\_depth \== 2:  
             balance\_impact\["depth\_warnings"\].append(f"{pos}: Drops to {current\_depth} (Thin)")

    \# 2\. Registration Check (Premier League/UCL Rules)   
    if player.home\_grown\_club:  
        hgc\_count \= len(\[p for p in squad.players if p.home\_grown\_club and p\!= player\])  
        if hgc\_count \< 4:  
             balance\_impact\["registration\_impact"\] \= "Critical: Drops below 4 HGC (UEFA Rule)"  
             \# Note: Not strictly blocking (can leave slot empty), but highly discouraged.  
             balance\_impact\["depth\_warnings"\].append("HGC Quota Failure")

    \# 3\. Leadership/Social Check \[38\]  
    if player.is\_team\_leader:  
        balance\_impact\["depth\_warnings"\].append("Leadership Void Risk")

    return balance\_impact

## ---

**6\. Protection Protocols: The "Untouchables"**

To prevent the algorithm from acting too "mechanically" (e.g., selling a club legend or a high-potential youth purely for minor efficiency gains), we implement a protection layer.

### **6.1 Logic for Protection**

1. **High PA Youth:** Players \< 22 with PA \> 150 (Variable based on club stature). We protect the *potential*, not the current ability.32  
2. **Recent Signings:** Players signed \< 180 days ago. Selling immediately incurs financial losses (fees) and hits "hidden adaptability" mechanics.23  
3. **Unique Specialists:** The *only* player with Jumping Reach \> 17 or Free Kicks \> 17\.

### **6.2 Loan vs. Keep Logic (Youth)**

The model must decide the fate of protected youth.

* **Age 15-18:** **KEEP.** Train at club. "Club Grown" status accumulation (requires 3 years between 15-21).41  
* **Age 18+:** **LOAN.** If not playing \> 20 matches/season in first team. Development stalls without match engine exposure.15

### ---

**Deliverable E: Protection Rules**

Python

def apply\_protection\_rules(player, squad, config):  
    """  
    Determines if a player is immune to removal.  
    """  
      
    \# 1\. Youth Potential Protection \[32, 43\]  
    if player.age \<= 21:  
        if player.pa \>= config.youth\_pa\_threshold: \# Default 150  
            \# Exception: Low Professionalism (The "Ravel Morrison" Rule)  
            if player.hidden.professionalism \< 10 and player.development\_stalled:  
                return {"is\_protected": False, "reason": "High PA but Low Pro/Stalled"}  
            return {"is\_protected": True, "reason": "High Potential Asset", "type": "Youth"}

    \# 2\. Key Contributor Protection  
    if player.contribution\_rank \<= config.protected\_count: \# Default Top 15  
        return {"is\_protected": True, "reason": "Key Player", "type": "Performance"}

    \# 3\. Recent Signing Protection \[40\]  
    if player.days\_at\_club \< config.recent\_signing\_period: \# 180 days  
        return {"is\_protected": True, "reason": "Recent Signing", "type": "Financial"}

    \# 4\. HGC Quota Lock \[7\]  
    \# If removing him breaks the HGC rule and no youth can step up  
    balance \= check\_squad\_balance\_impact(player, squad)  
    if "HGC Quota Failure" in balance\["depth\_warnings"\]:  
        return {"is\_protected": True, "reason": "Registration Critical (HGC)", "type": "Regulatory"}

    return {"is\_protected": False, "reason": None, "type": None}

## ---

**7\. Action Selection Logic: The Decision Matrix**

The final output is the recommendation. This aggregates all previous scores.

### **Deliverable F: Removal Decision Algorithm**

Python

def recommend\_player\_removal(players, squad, config):  
    recommendations \=  
      
    for player in players:  
        \# 1\. Protection Pass  
        protection \= apply\_protection\_rules(player, squad, config)  
        if protection\["is\_protected"\]:  
            continue  
              
        \# 2\. Analyze Factors  
        score \= calculate\_contribution\_score(player, squad, config.tactic)  
        future \= assess\_future\_value(player)  
        finance \= analyze\_financial\_impact(player, squad.budget)  
        balance \= check\_squad\_balance\_impact(player, squad)  
          
        \# 3\. Hard Stop on Critical Balance Issues  
        if balance\["blocking\_issue"\]:  
            continue

        action \= None  
        reason \=  
        priority \= 0  
          
        \# \--- LOGIC GATES \---  
          
        \# Gate 1: The "Deadwood" (Low Ability, No Potential)  
        \# \[44\]: Bottom tier contribution  
        if score \< config.min\_contribution\_threshold and future\["value\_trend"\]\!= "increasing":  
            if player.market\_value \> 0:  
                action \= "Sell"  
                reason.append("Surplus to requirements")  
            else:  
                action \= "Release"  
                reason.append("Freeing wage bill / No market value")  
            priority \= 1 \# Highest priority  
              
        \# Gate 2: The "Financial Burden" (Wage Ratio)  
        \# : Wage structure strictness  
        elif finance\["wage\_vs\_tier\_cap\_ratio"\] \> 1.4:  
            action \= "Sell"  
            reason.append(f"Wage Efficiency Critical ({finance\['wage\_vs\_tier\_cap\_ratio'\]:.1f}x)")  
            priority \= 2  
              
        \# Gate 3: The "Peak Sell" (Moneyball \- Sell before decline)  
        \# \[14\]: Physical decline  
        elif future\["recommended\_action\_timing"\] \== "sell\_peak\_value":  
            action \= "Sell"  
            reason.append("Asset Maximization (Peak Age/Decline Imminent)")  
            priority \= 3  
              
        \# Gate 4: The "Development Loan"  
        \# \[15\]: 18+ needs minutes  
        elif player.age \< 22 and player.pa \> 130 and score \< config.first\_team\_threshold:  
            action \= "Loan"  
            reason.append("Development (Needs First Team Minutes)")  
            priority \= 4  
              
        \# Construct Recommendation  
        if action:  
            rec \= {  
                "player": player,  
                "action": action,  
                "priority": priority,  
                "confidence": "High" if priority \< 3 else "Medium",  
                "reason": "; ".join(reason),  
                "estimated\_fee": player.market\_value if action \== "Sell" else 0,  
                "wage\_savings": player.weekly\_wage \* 52,  
                "considerations": balance\["depth\_warnings"\] \+ \[future\["value\_trend"\]\]  
            }  
            recommendations.append(rec)  
              
    \# Sort by priority (1 is highest)  
    return sorted(recommendations, key=lambda x: x\["priority"\])

## ---

**8\. User Interface and Visualization**

### **Deliverable G: UI Output Format (JSON)**

JSON

{  
  "removal\_candidates":  
    },  
    {  
      "player\_id": 90155,  
      "player\_name": "Billy Kid",  
      "action": "Loan",  
      "priority": 4,  
      "reason": "Development Stalled: Needs \>20 starts/season. Blocked by 3 senior players.",  
      "loan\_requirements": {  
        "min\_playing\_time": "Regular Starter",  
        "min\_facilities": "Average"  
      }  
    }  
  \],  
  "squad\_health\_summary": {  
    "total\_wages": "£120M",  
    "wage\_efficiency\_rating": "B-",  
    "average\_age": 26.4,  
    "home\_grown\_count": 9  
  }  
}

### **Deliverable H: Decision Tree Visualization**

                    ┌─────────────────────────┐  
                    │  Start Player Analysis  │  
                    └────────────┬────────────┘  
                                 │  
                    ┌────────────▼────────────┐  
                    │     Is Protected?       │  
                    │(Youth/Key/Recent/HGC)   │  
                    └──────┬───────────┬──────┘  
                           │           │  
                       No  │           │ Yes  
             ┌─────────────▼──┐     ┌──▼──────────────────┐  
             │  Balance Check │     │ KEEP (Protected)    │  
             │ (Depth \< 2?)   │     │ Action: Status Quo  │  
             └──────┬──────┬──┘     └─────────────────────┘  
                    │      │  
                No  │      │ Yes (Blocking Issue)  
         ┌──────────▼──────▼───┐  
         │ KEEP (Critical Depth)│  
         └──────────────────────┘  
                    │  
         ┌──────────▼──────────────┐  
         │   Contribution Check    │  
         │  (Score \< Threshold?)   │  
         └───────┬──────────┬──────┘  
                 │          │  
             Yes │          │ No (Good Player)  
     ┌───────────▼┐      ┌──▼──────────────────────────┐  
     │  Deadwood  │      │    Financial/Age Audit      │  
     │  Analysis  │      └──────┬──────────────┬───────┘  
     └─────┬──────┘             │              │  
           │               Wage Ratio      Value Trend  
           │                 \> 1.4?        Declining?  
           │                    │              │  
           │              ┌─────▼────┐    ┌────▼─────┐  
           │              │   SELL   │    │   SELL   │  
           │              │(Wage Dump)│   │(Peak Age)│  
           │              └──────────┘    └──────────┘  
           │  
     ┌─────▼──────────────────┐  
     │ Value \> 0?             │  
     ├───────────┬────────────┤  
     │ Yes       │ No         │  
  ┌──▼───┐    ┌──▼────────┐   │  
  │ SELL │    │ RELEASE   │   │  
  └──────┘    └───────────┘   │  
                              │  
                    ┌─────────▼─────────┐  
                    │   Youth Check     │  
                    │ (Age \< 22 & High) │  
                    └────┬───────────┬──┘  
                         │           │  
                     Yes │           │ No  
                  ┌──────▼───┐    ┌──▼───┐  
                  │   LOAN   │    │ KEEP │  
                  └──────────┘    └──────┘

## **Validation & Conclusion**

This framework addresses the complex multi-objective nature of football squad management. By utilizing an **Effective Ability** contribution score, we eliminate false positives caused by raw CA. By strictly enforcing **Wage Efficiency Tiers**, we ensure long-term financial viability. Finally, by integrating **Biological Aging Curves** and **Registration Constraints**, the model avoids the common AI pitfalls of selling players too late or stripping the squad of necessary legal quotas.

The result is a decision-support system that mimics the behavior of an elite-level Sporting Director: ruthless with efficiency, protective of assets, and strategic in forecasting.

#### **Works cited**

1. The Aging Curve: How Age Affects Physical Performance in Elite Football \- PMC, accessed December 29, 2025, [https://pmc.ncbi.nlm.nih.gov/articles/PMC12551122/](https://pmc.ncbi.nlm.nih.gov/articles/PMC12551122/)  
2. How to use a wage cap in Football Manager \- FMInside.net, accessed December 29, 2025, [https://fminside.net/guides/financial-guides/54-how-to-use-a-wage-cap-in-football-manager](https://fminside.net/guides/financial-guides/54-how-to-use-a-wage-cap-in-football-manager)  
3. FM26: Hidden Attributes Explained \- General Discussion \- Sortitoutsi, accessed December 29, 2025, [https://sortitoutsi.net/content/74854/fm26-hidden-attributes-explained](https://sortitoutsi.net/content/74854/fm26-hidden-attributes-explained)  
4. 2025/26 Premier League squad lists, accessed December 29, 2025, [https://www.premierleague.com/en/news/4407896/202526-premier-league-squad-lists](https://www.premierleague.com/en/news/4407896/202526-premier-league-squad-lists)  
5. Premier League squad lists \- what you need to know, accessed December 29, 2025, [https://www.premierleague.com/en/news/4097471/premier-league-squad-lists-explained](https://www.premierleague.com/en/news/4097471/premier-league-squad-lists-explained)  
6. Player Wages | Football Manager 2022 Guide \- Guide to FM, accessed December 29, 2025, [https://www.guidetofm.com/squad/wages/](https://www.guidetofm.com/squad/wages/)  
7. Champions League league phase squads, player registration deadlines: All you need to know \- UEFA.com, accessed December 29, 2025, [https://www.uefa.com/uefachampionsleague/news/029c-1e6a3464bdcd-ac4d3eea76b7-1000--champions-league-league-phase-squads-player-registration-/](https://www.uefa.com/uefachampionsleague/news/029c-1e6a3464bdcd-ac4d3eea76b7-1000--champions-league-league-phase-squads-player-registration-/)  
8. Homegrown Player Rule (UEFA) \- Wikipedia, accessed December 29, 2025, [https://en.wikipedia.org/wiki/Homegrown\_Player\_Rule\_(UEFA)](https://en.wikipedia.org/wiki/Homegrown_Player_Rule_\(UEFA\))  
9. Fantasy Premier League — Lineup Optimization Using Mixed Linear Programming (A.K.A “The Knapsack Problem”) | by Nachi Lieder | Sports Analytics and Data Science | Medium, accessed December 29, 2025, [https://medium.com/sports-analytics-and-data-science/fantasy-premier-league-lineup-optimization-using-mixed-linear-programming-the-knapsack-problem-3c19b3b007a2](https://medium.com/sports-analytics-and-data-science/fantasy-premier-league-lineup-optimization-using-mixed-linear-programming-the-knapsack-problem-3c19b3b007a2)  
10. Optimizing a Daily Fantasy Sports NBA lineup — Knapsack, NumPy, and Giannis, accessed December 29, 2025, [https://bigishdata.com/2019/07/28/optimizing-a-daily-fantasy-sports-nba-lineup-knapsack-numpy-and-giannis/](https://bigishdata.com/2019/07/28/optimizing-a-daily-fantasy-sports-nba-lineup-knapsack-numpy-and-giannis/)  
11. Grab Your Knapsack\! Let's Construct an NBA Roster \- Dataiku Community, accessed December 29, 2025, [https://community.dataiku.com/discussion/20217/grab-your-knapsack-let-s-construct-an-nba-roster](https://community.dataiku.com/discussion/20217/grab-your-knapsack-let-s-construct-an-nba-roster)  
12. When Do Football Players Peak?, accessed December 29, 2025, [https://macro-football.com/other/aging/](https://macro-football.com/other/aging/)  
13. Which algorithm combines knapsack optimization with the efficiency of job scheduling (to create a points optimizing fantasy basketball lineup) \- Stack Overflow, accessed December 29, 2025, [https://stackoverflow.com/questions/74494117/which-algorithm-combines-knapsack-optimization-with-the-efficiency-of-job-schedu](https://stackoverflow.com/questions/74494117/which-algorithm-combines-knapsack-optimization-with-the-efficiency-of-job-schedu)  
14. It's a SI's big lie that the way the game handles the decline in physical attributes for mid-30s players is better. : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/19cj9jq/its\_a\_sis\_big\_lie\_that\_the\_way\_the\_game\_handles/](https://www.reddit.com/r/footballmanagergames/comments/19cj9jq/its_a_sis_big_lie_that_the_way_the_game_handles/)  
15. Is It Better To Keep or Loan The Youth Out? \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/434455-is-it-better-to-keep-or-loan-the-youth-out/](https://community.sports-interactive.com/forums/topic/434455-is-it-better-to-keep-or-loan-the-youth-out/)  
16. The Art of Youth Development – Football Manager \- A FM Old Timer, accessed December 29, 2025, [https://afmoldtimer.home.blog/2023/06/01/the-art-of-youth-development-football-manager/](https://afmoldtimer.home.blog/2023/06/01/the-art-of-youth-development-football-manager/)  
17. Player Ability | Football Manager 2022 Guide, accessed December 29, 2025, [https://www.guidetofm.com/players/ability/](https://www.guidetofm.com/players/ability/)  
18. (Table) How each Attribute contributes to players' Current Ability for each Position \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1ebzb6j/table\_how\_each\_attribute\_contributes\_to\_players/](https://www.reddit.com/r/footballmanagergames/comments/1ebzb6j/table_how_each_attribute_contributes_to_players/)  
19. A Simple Approach to Player Ratings \- Winning With Analytics, accessed December 29, 2025, [https://winningwithanalytics.com/a-simple-approach-to-player-ratings/](https://winningwithanalytics.com/a-simple-approach-to-player-ratings/)  
20. Genie Scout has a Role Rating and a Positional Rating, how shall I use them for selecting players for matches ? Why are wing back positional ratings are relatively poor ? : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/135sorx/genie\_scout\_has\_a\_role\_rating\_and\_a\_positional/](https://www.reddit.com/r/footballmanagergames/comments/135sorx/genie_scout_has_a_role_rating_and_a_positional/)  
21. Which hidden attributes are most important in Football Manager \#FM24 Tips \- YouTube, accessed December 29, 2025, [https://www.youtube.com/watch?v=l45iijWnfws](https://www.youtube.com/watch?v=l45iijWnfws)  
22. \[FM22\] \[Experiment\] Influence of selected hidden attributes and Determination on team performance in domestic league \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/565369-fm22-experiment-influence-of-selected-hidden-attributes-and-determination-on-team-performance-in-domestic-league/](https://community.sports-interactive.com/forums/topic/565369-fm22-experiment-influence-of-selected-hidden-attributes-and-determination-on-team-performance-in-domestic-league/)  
23. How to read Scout Reports in FM (and avoid signing the next Bendtner) \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/6z9acn/how\_to\_read\_scout\_reports\_in\_fm\_and\_avoid\_signing/](https://www.reddit.com/r/footballmanagergames/comments/6z9acn/how_to_read_scout_reports_in_fm_and_avoid_signing/)  
24. Scout Reports | Page 2 of 2 | Football Manager 2022 Guide, accessed December 29, 2025, [https://www.guidetofm.com/squad/scout-reports/2/](https://www.guidetofm.com/squad/scout-reports/2/)  
25. FM22 HIDDEN ATTRIBUTES EXPLAINED \- YouTube, accessed December 29, 2025, [https://www.youtube.com/watch?v=IMjwPZDyNoc](https://www.youtube.com/watch?v=IMjwPZDyNoc)  
26. Player Search Tool \- Moneyball, data recruitment etc \- FM Stag.com, accessed December 29, 2025, [https://fmstag.com/playersearchtool/](https://fmstag.com/playersearchtool/)  
27. Statistics Spreadsheet (For those that love Moneyball) \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/567013-statistics-spreadsheet-for-those-that-love-moneyball/](https://community.sports-interactive.com/forums/topic/567013-statistics-spreadsheet-for-those-that-love-moneyball/)  
28. Leviathan Model 2.0 \- Isolated Impact of Football Players | Macro ..., accessed December 29, 2025, [https://macro-football.com/about/lev2.0/](https://macro-football.com/about/lev2.0/)  
29. Understanding Age Curves in Football Player Development, accessed December 29, 2025, [https://the-footballanalyst.com/understanding-age-curves-in-football-player-development/](https://the-footballanalyst.com/understanding-age-curves-in-football-player-development/)  
30. Consistency and Big Matches going up \- Football Manager General Discussion, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/556081-consistency-and-big-matches-going-up/](https://community.sports-interactive.com/forums/topic/556081-consistency-and-big-matches-going-up/)  
31. Is it better to loan out my youngsters or keep them in my reserve team? \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1e1zbqy/is\_it\_better\_to\_loan\_out\_my\_youngsters\_or\_keep/](https://www.reddit.com/r/footballmanagergames/comments/1e1zbqy/is_it_better_to_loan_out_my_youngsters_or_keep/)  
32. Players near end of contract: let go for free or offer new contracts and sell?, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/436624-players-near-end-of-contract-let-go-for-free-or-offer-new-contracts-and-sell/](https://community.sports-interactive.com/forums/topic/436624-players-near-end-of-contract-let-go-for-free-or-offer-new-contracts-and-sell/)  
33. A quick explanation of amortization and why it's more important to FFP than the actual transfer fee of a player. : r/ACMilan \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/ACMilan/comments/bf64i3/a\_quick\_explanation\_of\_amortization\_and\_why\_its/](https://www.reddit.com/r/ACMilan/comments/bf64i3/a_quick_explanation_of_amortization_and_why_its/)  
34. Does FM spread player costs as amortisation or initial fees in the accounting section of the game? : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/uzron8/does\_fm\_spread\_player\_costs\_as\_amortisation\_or/](https://www.reddit.com/r/footballmanagergames/comments/uzron8/does_fm_spread_player_costs_as_amortisation_or/)  
35. For how big squad depth do you usually go? : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1bv36hs/for\_how\_big\_squad\_depth\_do\_you\_usually\_go/](https://www.reddit.com/r/footballmanagergames/comments/1bv36hs/for_how_big_squad_depth_do_you_usually_go/)  
36. The Art of Squad Building – Football Manager \- A FM Old Timer, accessed December 29, 2025, [https://afmoldtimer.home.blog/2023/04/27/the-art-of-squad-building-football-manager/](https://afmoldtimer.home.blog/2023/04/27/the-art-of-squad-building-football-manager/)  
37. What is the most optimal squad size? : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1dfljrb/what\_is\_the\_most\_optimal\_squad\_size/](https://www.reddit.com/r/footballmanagergames/comments/1dfljrb/what_is_the_most_optimal_squad_size/)  
38. What is "Transfer expenditure" and why is it costing me tens of millions more than I've actually paid?, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/585677-what-is-transfer-expenditure-and-why-is-it-costing-me-tens-of-millions-more-than-ive-actually-paid/](https://community.sports-interactive.com/forums/topic/585677-what-is-transfer-expenditure-and-why-is-it-costing-me-tens-of-millions-more-than-ive-actually-paid/)  
39. Can anyone give me a definitive answer on bringing in youth and making them homegrown? : r/footballmanagergames \- Reddit, accessed December 29, 2025, [https://www.reddit.com/r/footballmanagergames/comments/81ev7d/can\_anyone\_give\_me\_a\_definitive\_answer\_on/](https://www.reddit.com/r/footballmanagergames/comments/81ev7d/can_anyone_give_me_a_definitive_answer_on/)  
40. Homegrown: 0-21 vs 15-21 \- Football Manager General Discussion \- Sports Interactive Community, accessed December 29, 2025, [https://community.sports-interactive.com/forums/topic/214912-homegrown-0-21-vs-15-21/](https://community.sports-interactive.com/forums/topic/214912-homegrown-0-21-vs-15-21/)