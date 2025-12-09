# **The Architecture of Effectiveness: A Comprehensive Analysis of Positional Familiarity and Skill Ratings in Football Manager 2026**

## **1\. Introduction**

The release of *Football Manager 2026* (FM26) represents the single most significant architectural shift in the history of the franchise, primarily precipitated by the migration from Sports Interactive’s proprietary legacy code to the Unity engine.1 This transition is not merely cosmetic; it fundamentally redefines the physics of the match engine, the logic of player decision-making, and the spatial relationships that govern effectiveness on the pitch. Within this new ecosystem, the long-standing mechanics of positional familiarity—the hidden 1-20 rating scale determining a player's aptitude for a specific zone—have evolved from static attribute modifiers into dynamic, phase-dependent variables.

The inquiry at hand seeks to deconstruct the relationship between a player's skill rating at a position and their resultant effectiveness. Historically, this relationship was viewed through a linear lens: a lower rating equated to a fixed statistical penalty, often summarized as a reduction in the *Decisions* attribute. However, the introduction of separate **In-Possession** and **Out-of-Possession** formations in FM26 introduces a layer of complexity that renders previous models insufficient.4 A player’s effectiveness is no longer a constant state but a fluctuating value, dependent on the phase of play and the specific coordinates they occupy during the transition between attacking and defensive shapes.

This report provides an exhaustive analysis of these mechanics. It examines the granular impact of the 0-20 rating scale at key intervals (0, 5, 10, 15, 20), quantifies the "penalty" mechanism applied by the match engine, and explores the mitigating factors such as the *Versatility* hidden attribute and *Current Ability* (CA) weighting. Furthermore, it posits that in the era of FM26, positional familiarity must be re-evaluated not just as a measure of comfort, but as a critical component of structural integrity, particularly during the defensive transition where the new "Out-of-Possession" roles expose players to unfamiliar zones with potentially catastrophic results.

To understand the present, one must understand the architectural leap. The move to Unity allows for "authentic player animations" and a reworked UI that emphasizes tactical fluidity.1 This implies that positional unfamiliarity in FM26 is likely represented not just by bad dice rolls (statistical failure) but by visible hesitations and positioning errors in the 3D match environment, making the "Awkward" or "Unconvincing" ratings more punitive than in any prior iteration.

## ---

**2\. The Quantitative Framework of Position Ratings**

At the core of the *Football Manager* database lies a numerical architecture that governs every interaction on the pitch. While the user interface presents positional familiarity through approachable terminology—"Natural," "Accomplished," "Unconvincing"—the underlying system operates on a precise integer scale ranging from 1 to 20, with 0 representing a null value or complete ignorance of a position. Understanding this raw data structure is prerequisite to manipulating player effectiveness.

### **2.1 The Hidden 1-20 Scale and UI Mapping**

The game’s database maps the 1-20 scale to specific threshold labels visible to the user. This mapping is consistent across the database but has nuanced implications for the match engine’s calculations. The scale is not strictly linear in terms of impact; it operates on a tiered system where specific thresholds trigger the removal of penalties.

#### **Table 1: Detailed Positional Rating Scale Mapping**

| Rating (1-20) | UI Label | Color Indicator | Engine State | Tactical Implication |
| :---- | :---- | :---- | :---- | :---- |
| **18-20** | **Natural** | Bright Green | **Optimal** | The player operates with 100% efficiency. No attribute penalties are applied. The player gains maximum tactical familiarity speed. |
| **15-17** | **Accomplished** | Green | **Near-Optimal** | Functionally indistinguishable from "Natural" in match performance. Minor reduction in tactical learning speed. |
| **12-14** | **Competent** | Yellow / Light Green | **Restricted** | The "Penalty Mechanism" begins to apply, specifically to mental reaction speeds. |
| **9-11** | **Unconvincing** | Orange | **Impaired** | Significant damping of the *Decisions* attribute. The player requires more time to execute actions. |
| **5-8** | **Awkward** | Red | **Compromised** | Severe penalties to *Decisions*, *Positioning*, and *Concentration*. The player is a structural liability. |
| **1-4** | **Makeshift** | Dark Red / Grey | **Ineffectual** | The engine treats the player as having no positional instincts. Effectiveness relies solely on raw physical attributes. |
| **0** | **None** | No Dot | **Null** | Complete absence of positional data. |

Source Data Synthesis: 5

It is critical to note that while the user sees "Natural" for both a 19 and a 20, the engine distinguishes between them primarily in the realm of development and attribute weighting, though the match engine performance output is identical.5

### **2.2 Distinguishing Role Suitability from Position Familiarity**

A persistent misunderstanding among managers is the conflation of **Position Familiarity** (the 1-20 scale) with **Role Suitability** (the Star Rating). These are two independent variables that interact but do not control one another.

* **Position Familiarity** measures the player’s knowledge of *where* to stand and *how* to orient themselves on the pitch. It is a hard constraint. If a player is rated 0 at Center Back, they do not know the defensive line triggers, regardless of their attributes.  
* **Role Suitability** is a heuristic calculation performed by the Assistant Manager or Coaching Staff. It aggregates the attributes relevant to a specific set of instructions (e.g., Passing and Vision for a Deep Lying Playmaker) and compares them to the squad average or league standard.9

The danger in FM26 lies in the "False Positive." A player may possess world-class attributes for a specific role—for instance, a striker with 20 Passing and 20 Vision—leading the Assistant Manager to rate them as a 5-Star *Enganche* (AMC). However, if that player has a Position Rating of 1 (Makeshift) for the Attacking Midfield zone, they will be unable to utilize those attributes effectively. The Assistant's star rating typically assumes the player is playing in a position they know; it assesses the *tools*, not the *toolbox*. Therefore, a manager must strictly prioritize the Position Rating (the color of the dot) over the Star Rating when assessing immediate effectiveness.12

## ---

**3\. The Mechanics of Ineffectiveness: The "Penalty" System**

The central question of this research is how effectiveness varies at ratings of 0, 5, 10, 15, and 20\. The evidence confirms that FM26 does not apply a blanket reduction to all attributes (i.e., a fast player does not become slow). Instead, the match engine applies a targeted "damping" effect to specific **Mental Attributes**, creating a disconnect between a player's physical capacity and their cognitive execution.

### **3.1 The "Decisions" Hypothesis**

The overwhelming consensus from longitudinal community testing and engine analysis is that the primary victim of positional unfamiliarity is the **Decisions** attribute.8

The *Decisions* attribute serves as the "CPU" of the player. It determines the choice of action: whether to pass or shoot, whether to tackle or jockey, whether to clear or dribble. When a player operates in a zone with a low positional rating (0-10), the engine applies a negative modifier to their effective *Decisions* value.

* **Mechanism:** A player with a visible *Decisions* attribute of 18 playing in a "Red" position (Rating 5\) may function as if they have a *Decisions* attribute of 8 or 9\.  
* **Consequence:** This leads to hesitation. In the Unity engine, which simulates physics and collisions more accurately, this hesitation manifests as the player dwelling on the ball, getting caught in possession, or reacting late to an opponent's run.

In addition to *Decisions*, secondary penalties are applied to **Positioning** (for defensive actions) and **Off the Ball** (for attacking actions).7 These attributes govern the player's spatial coordinates relative to the ball and teammates. A penalty here means the player is physically in the wrong spot, breaking the tactical shape.

### **3.2 Granular Analysis of Effectiveness at Key Intervals**

#### **3.2.1 Rating 0 (The Null State)**

* **Effectiveness:** **\< 40% (Tactical) / 100% (Physical)**  
* **Characteristics:** At a rating of 0, the player has no positional reference points. The engine relies entirely on the player's physical attributes and general aggression.  
* **Scenario:** A Goalkeeper playing as a Striker, or a Striker playing as a Center Back.  
* **Performance:** The player acts as a "rogue element." If they possess extreme physical traits (e.g., 18 Pace, 18 Strength), they may inadvertently perform well by winning duels simply through athletic dominance. However, they will utterly fail to participate in systemic play. They will not press triggers, they will play attackers onside, and they will effectively be a passenger during complex build-up play.8  
* **Unity Engine Implication:** With improved collision and movement physics, a Rating 0 player is likely to cause obstructions, running into teammates or blocking passing lanes due to a complete lack of spatial awareness.

#### **3.2.2 Rating 5 (Awkward / Red Zone)**

* **Effectiveness:** **50-60%**  
* **Characteristics:** The player understands the basic concept of the zone but lacks nuance. The "Decisions" penalty is severe.  
* **Scenario:** A Winger (AMR) forced to play Central Midfield (MC).  
* **Performance:** The player will default to the behaviors of their *natural* position. The Winger at MC will drift wide, vacating the central channel. When pressed, the "Decisions" penalty will cause panic; instead of recycling possession, they may attempt a high-risk dribble or a long ball that results in a turnover.  
* **Strategic Risk:** In FM26’s dual-formation system, having a player drop into a "Red Zone" during the defensive phase is a critical vulnerability. The opposition will identify this player as the weak link in the pressing chain and exploit the space they inevitably leave vacant.15

#### **3.2.3 Rating 10 (Unconvincing / Orange Zone)**

* **Effectiveness:** **70-80%**  
* **Characteristics:** The "Unconvincing" tier represents the threshold of usability. The penalties are moderate but present.  
* **Scenario:** A Center Back (DC) playing as a Defensive Midfielder (DM).  
* **Performance:** The player is serviceable for low-complexity roles. If instructed to simply "win the ball and pass it short," they can function. However, the "Decisions" penalty manifests as **inconsistency**. Over 90 minutes, a Rating 10 player is statistically likely to make 2-3 significant errors—misplaced passes or missed interceptions—that a Natural player would not.  
* **Mitigation:** High *Versatility* (Hidden Attribute) can boost the effective performance of a Rating 10 player closer to that of a Competent one.16

#### **3.2.4 Rating 12-14 (Competent / Yellow Zone)**

* **Effectiveness:** **85-95%**  
* **Characteristics:** The player is functionally sound. The attribute penalties are negligible.  
* **Scenario:** A utility player rotating into the starting XI.  
* **Performance:** At this level, the player does not suffer from significant decision-making lag. The primary drawback is a lack of "micro-optimization." They may not make the *perfect* run that a Natural player would, but they will not make a catastrophic error.  
* **Strategic Value:** In FM26, players with "Competent" ratings in multiple positions are arguably more valuable than specialists, as they facilitate fluid tactical shifts between In-Possession and Out-of-Possession shapes.18

#### **3.2.5 Rating 15-20 (Accomplished to Natural / Green Zone)**

* **Effectiveness:** **99-100%**  
* **Characteristics:** The penalty mechanism is deactivated.  
* **Scenario:** A starter playing in their primary role.  
* **Performance:** Research indicates that in the Match Engine, there is effectively no difference between a rating of 15 (Accomplished) and 20 (Natural) regarding attribute application.5 The player has full access to their mental, physical, and technical skill set.  
* **The "Natural" Advantage:** The only tangible benefit of 18-20 over 15-17 is the speed at which the player gains **Tactical Familiarity**. A Natural player will maximize their familiarity bar (becoming fully fluid with the team's specific instructions) faster than an Accomplished one.6

## ---

**4\. The FM26 Paradigm Shift: Dual-Phase Tactics and Dynamic Effectiveness**

The introduction of separate **In-Possession** and **Out-of-Possession** formations in FM26 fundamentally alters the calculus of positional effectiveness.4 In previous iterations, a player’s position was static. In FM26, a player acts as a dynamic entity, physically transitioning between zones as possession changes. This creates a new variable: **Transitional Vulnerability**.

### **4.1 The Theory of Dynamic Familiarity**

Consider a tactical setup where the team attacks in a 4-2-4 but defends in a 4-4-2. This requires the attacking wingers (AMR/AML) to drop deep into the midfield strata (MR/ML) when the ball is lost.

* **Phase 1 (In Possession):** The player is an AMR. Rating: **20 (Natural)**. Effectiveness: **100%**.  
* **Phase 2 (Out of Possession):** The player is an MR. Rating: **5 (Awkward)**. Effectiveness: **55%**.

In this scenario, the player’s effectiveness is not a static average. Instead, they oscillate between brilliance and incompetence dozens of times per match.

* **The Danger:** When the transition occurs (the moment the ball is lost), the player must actively decide where to move. Because their rating in the *destination* zone (MR) is low, the *Decisions* and *Positioning* penalties trigger immediately. This results in a lag or error in the transition—the player may fail to drop back promptly, leaving the fullback exposed to a 2v1 overload.15

### **4.2 Positional Familiarity as a Defensive Attribute**

This dynamic shifts the evaluation of attacking players. In FM26, an attacker’s familiarity with their defensive zone is effectively a defensive attribute.

* **Comparative Analysis:**  
  * **Player A:** 10 Tackling, 10 Positioning. **Natural** at MR (Defensive Zone).  
  * **Player B:** 14 Tackling, 14 Positioning. **Awkward** at MR (Defensive Zone).  
* **Outcome:** Player A is the superior defender in a 4-4-2 defensive block. Player A's "Natural" rating ensures they are in the correct position to make a challenge. Player B, despite superior stats, suffers from the "Awkward" penalty to *Positioning*, meaning they will likely be out of position and never get the opportunity to use their 14 Tackling.4

### **4.3 Utilization of the Visualizer**

FM26 introduces a "Visualizer" tool within the tactics creator.4 This tool is essential for auditing positional risk. It displays the movement paths of players as they transition between phases. Managers must use this to identify "Red Zones"—areas where the tactic forces a player into a position where they hold a rating of 0-8.

* **Recommendation:** If the Visualizer shows a key player transitioning into a "Red Zone," the manager has two options:  
  1. **Tactical Adjustment:** Alter the Out-of-Possession shape to keep the player in a zone where they are at least "Competent" (10+).  
  2. **Aggressive Retraining:** Prioritize training the player in the secondary position immediately.

## ---

**5\. The Hidden Variables: Versatility and Attributes**

While the visible Position Rating is the primary driver of effectiveness, hidden attributes and specific visible skills act as modifiers that can dampen or amplify the penalties of playing out of position.

### **5.1 The "Versatility" Attribute**

**Versatility** is a hidden attribute (1-20) that cannot be seen without an editor or extensive scouting reports.16 It is the single most important factor in mitigating the "Penalty" of low positional ratings.

* **High Versatility (15-20):** A player with high versatility adapts quickly to unfamiliar situations. If played in a position where they are rated 5 (Awkward), high versatility acts as a buffer, reducing the severity of the *Decisions* penalty. They essentially perform as if they were rated 10 or 12\.  
* **Low Versatility (1-5):** These players are rigid. Playing them out of position results in maximum penalties. Furthermore, they are more likely to suffer morale drops, complain to the media about being played out of position, and perform poorly in training.22

### **5.2 Attribute Independence Theory: When Skills Override Position**

Despite the penalties, empirical evidence supports the "Attribute Independence Theory." This theory suggests that if a player’s raw attributes are sufficiently high relative to the competition, they can brute-force effectiveness despite positional incompetence.

* **The "Jamie Vardy Experiment":** Community experiments have shown that playing a world-class striker with high Pace, Work Rate, and Aggression at Center Back (Rating 0\) can result in acceptable performance.8  
* **Why?** Even with a penalized *Positioning* attribute, a player with 18 Pace can recover from errors that a slower player cannot. A player with 18 Strength will win duels even if they engage at the wrong time.  
* **Threshold of Competence:** This implies that the "Penalty" is a subtractive modifier, not a hard cap. If a player has 20 in a relevant attribute, and the penalty reduces effectiveness by 30%, they effectively play with a 14—which is still elite in many leagues. Therefore, playing a superstar out of position is often less risky than playing a mediocre specialist.24

## ---

**6\. Structural Implications: Current Ability (CA) and the "Versatility Tax"**

A profound but often overlooked aspect of positional ratings is their relationship with **Current Ability (CA)**. In the FM database, a player’s CA is a finite resource (capped at 200). How this CA is calculated depends heavily on the positions the player is rated in.

### **6.1 The Weighting Mechanism**

Every position in the game has a specific set of "Key Attributes" that are weighted heavily in the CA calculation.

* **Striker:** Attributes like *Finishing*, *Acceleration*, and *Off the Ball* have high CA costs. Defensive attributes like *Tackling* have very low costs.  
* **Center Back:** *Positioning*, *Tackling*, and *Jumping Reach* have high costs. *Finishing* has low cost.

### **6.2 The Versatility Tax**

When a player learns a new position, the game engine recalculates their CA usage based on the weights of *all* their positions.25

* **The Trap:** If you retrain a Striker to become Natural at Center Back, the game suddenly applies the high CA weighting of defensive attributes to that player.  
* **The Consequence:** Since the player’s CA is a fixed number, learning a new position consumes CA points. If the player is already at their CA ceiling, the game *must* lower other attributes to balance the equation.  
* **Result:** A Striker who learns to play Center Back may actually see their *Finishing* or *Pace* drop slightly to "pay" for the new positional rating. This is the "Versatility Tax."

**Table 2: Theoretical Impact of Retraining on CA Distribution**

| Role | Primary Position | Secondary Position Learned | CA Impact | Attribute Consequence |
| :---- | :---- | :---- | :---- | :---- |
| **Striker** | ST (Natural) | **None** | Efficient | Max Points in Finishing/Pace. |
| **Striker** | ST (Natural) | **AMC (Accomplished)** | Moderate | Slight redistribution; attributes overlap significantly. Minimal loss. |
| **Striker** | ST (Natural) | **DC (Natural)** | **Inefficient** | **Heavy Tax.** Defensive attributes now cost CA. To maintain the CA cap, attacking attributes may decrease. |

Source Synthesis: 17

**Strategic Insight:** Managers in FM26 must be judicious with retraining. While dual-phase tactics require versatility, training a player in a position with vastly different attribute requirements (e.g., a Winger learning to play as a wing-back) is "cheaper" than a Winger learning to play as a central defender, due to attribute overlap. Avoid retraining players in positions that require completely opposing skill sets unless absolutely necessary.

## ---

**7\. Training and Development: Navigating the Curve**

To mitigate the risks of the dual-phase system, managers must actively manage the positional development of their squad. Moving a player from a rating of 5 (Awkward) to 15 (Accomplished) is a distinct process governed by specific variables.

### **7.1 The Timeline of Adaptation**

Research indicates that the progression along the 1-20 scale is non-linear and heavily influenced by the *Versatility* attribute and the *Professionalism* hidden attribute.6

* **High Versatility / High Professionalism:** Can move from Rating 5 to Rating 15 in **3-5 months** of intensive training and match exposure.  
* **Average Versatility:** Typically requires **6-9 months**.  
* **Low Versatility:** May take **18+ months** or stall at "Competent" (Rating 12).

### **7.2 The 12-Month Rule**

For long-term squad planning, managers should adhere to the "12-Month Rule." It generally takes a full calendar year of playing a player in a new position for them to achieve "Natural" (18-20) status.6 This implies that if a manager signs a player intending to convert them (e.g., a Winger to an Inverted Wingback), they must accept a transitional season where the player operates at "Competent" or "Accomplished" levels, with the associated minor penalties to tactical familiarity.

### **7.3 Retraining Strategies in FM26**

With the Unity engine and improved training modules, FM26 offers more targeted interventions.

* **Hybrid Training:** Managers should utilize individual training focuses that target the specific attributes required for the secondary position. For example, if an AMC drops to MC out of possession, training their *Positioning* and *Tackling* specifically will yield better performance results than simply setting their "Position Training" to MC, as it directly addresses the attributes most penalized by the positional rating.30  
* **Match Exposure:** Playing matches is significantly more effective than training alone. The fastest way to boost a rating from 10 to 15 is to give the player 20-30 minutes of game time in that position per week.

## ---

**8\. Strategic Synthesis and Case Studies**

### **8.1 Case Study: The "Foden Paradox"**

Consider a player profile similar to Phil Foden:

* **In-Possession:** Natural at AMC / AMR / AML.  
* **Out-of-Possession:** Unfamiliar (Rating 5\) at MR / ML.

**Tactical Scenario:** The manager implements a 4-3-3 that presses in a 4-4-2 shape. Foden (AMR) is required to drop into the MR slot.

* **Analysis:** Whenever the team loses the ball, Foden enters a "Red Zone." His effectiveness drops from 100% to \~60%. He hesitates to track the opposition left-back.  
* **Consequence:** The team suffers a defensive overload on the right flank.  
* **Solution:** The manager *must* prioritize training Foden at MR immediately. Until he reaches "Competent" (10+), the tactical shape is structurally unsound. Alternatively, the manager could adjust the Out-of-Possession shape to a 4-3-3 or 4-1-4-1, keeping Foden higher up the pitch where his familiarity is higher.

### **8.2 The "Universal" Substitute**

In the era of FM26, the value of the "Universal" player—someone with "Competent" (12+) ratings in 4-5 positions—skyrockets.

* **Squad Building:** A bench player who is Natural in one position and Awkward in others is less valuable than a player who is merely Competent in four positions. The latter allows the manager to shift between In-Possession and Out-of-Possession shapes without triggering the "Penalty Mechanism" across the squad.  
* **Recruitment Strategy:** Scouts should be instructed to identify players with high *Versatility* and broad positional familiarity, even if their raw attributes are slightly lower. A player with 14s in attributes and 15s in Position Ratings is more effective in a fluid system than a player with 16s in attributes but 5s in Position Ratings.

## ---

**9\. Conclusion**

In *Football Manager 2026*, a player's skill rating at a position acts as a critical gateway to their performance potential. It is not a simple linear variation where a rating of 10 is "half as good" as 20\. Instead, it is a threshold-based system where ratings below 10 trigger specific, punitive damping of the *Decisions*, *Positioning*, and *Concentration* attributes, rendering the player a liability in complex tactical systems.

The introduction of the Unity engine and dual-phase formations elevates this mechanic from a static stat to a dynamic, moment-to-moment variable. A player’s effectiveness is now the aggregate of their performance in both their attacking and defensive zones. Structural integrity in the defensive transition relies heavily on players having at least "Competent" (12+) familiarity with their Out-of-Possession roles.

Therefore, effectiveness in FM26 is defined not just by the height of a player's attribute peaks, but by the breadth of their positional competence. To master the new match engine, managers must view positional familiarity as a fundamental component of defensive solidity and offensive fluidity, actively managing the "Versatility Tax" and prioritizing the development of multi-zonal competence over pure specialization.

#### **Works cited**

1. Football Manager 26: What's New, What's Changed, and What to Expect \- GamingBolt, accessed December 9, 2025, [https://gamingbolt.com/football-manager-26-whats-new-whats-changed-and-what-to-expect](https://gamingbolt.com/football-manager-26-whats-new-whats-changed-and-what-to-expect)  
2. Football Manager 26 \- 15 Things You Need To Know Before You Buy \- YouTube, accessed December 9, 2025, [https://www.youtube.com/watch?v=MfkilqBAu\_k](https://www.youtube.com/watch?v=MfkilqBAu_k)  
3. Football Manager 26: What's New, What's Changed, and What to Expect \- لوت گیم, accessed December 9, 2025, [https://www.lootgame.ir/football-manager-26-whats-new-whats-changed-and-what-to-expect/](https://www.lootgame.ir/football-manager-26-whats-new-whats-changed-and-what-to-expect/)  
4. In Possession, Out of Possession: FM26's New Tactical Evolution | Football Manager 26, accessed December 9, 2025, [https://www.footballmanager.com/fm26/features/possession-out-possession-fm26s-new-tactical-evolution](https://www.footballmanager.com/fm26/features/possession-out-possession-fm26s-new-tactical-evolution)  
5. What is the difference between each level of positional ability? \- FM Addict, accessed December 9, 2025, [https://www.fmaddict.com/2023/06/the-difference-between-each-level-of-positional-ability.html](https://www.fmaddict.com/2023/06/the-difference-between-each-level-of-positional-ability.html)  
6. Any way to get a player with "Accomplished" at a position to be "Natural"? \- Reddit, accessed December 9, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1gz5k1/any\_way\_to\_get\_a\_player\_with\_accomplished\_at\_a/](https://www.reddit.com/r/footballmanagergames/comments/1gz5k1/any_way_to_get_a_player_with_accomplished_at_a/)  
7. Positions and mental attributes bonus/penalty \- Sports Interactive Community, accessed December 9, 2025, [https://community.sports-interactive.com/forums/topic/251984-positions-and-mental-attributes-bonuspenalty/](https://community.sports-interactive.com/forums/topic/251984-positions-and-mental-attributes-bonuspenalty/)  
8. How does playing out of position affect performance? : r/footballmanagergames \- Reddit, accessed December 9, 2025, [https://www.reddit.com/r/footballmanagergames/comments/4dg9pn/how\_does\_playing\_out\_of\_position\_affect/](https://www.reddit.com/r/footballmanagergames/comments/4dg9pn/how_does_playing_out_of_position_affect/)  
9. Role familiarity, or lack thereof \- Football Manager General Discussion, accessed December 9, 2025, [https://community.sports-interactive.com/forums/topic/553939-role-familiarity-or-lack-thereof/](https://community.sports-interactive.com/forums/topic/553939-role-familiarity-or-lack-thereof/)  
10. \[FM16\] How does position familiarity affect performance? And how quickly do players become familiar with positions? : r/footballmanagergames \- Reddit, accessed December 9, 2025, [https://www.reddit.com/r/footballmanagergames/comments/3v6dkb/fm16\_how\_does\_position\_familiarity\_affect/](https://www.reddit.com/r/footballmanagergames/comments/3v6dkb/fm16_how_does_position_familiarity_affect/)  
11. What attributes are good for each position? : r/footballmanagergames \- Reddit, accessed December 9, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1cmra9c/what\_attributes\_are\_good\_for\_each\_position/](https://www.reddit.com/r/footballmanagergames/comments/1cmra9c/what_attributes_are_good_for_each_position/)  
12. FM26 Coach Reports Explained: Understand CA, PA, Pros, Cons & Player Analysis, accessed December 9, 2025, [https://fmnatics.com/article-coach-reports](https://fmnatics.com/article-coach-reports)  
13. Playing player out of position : r/footballmanagergames \- Reddit, accessed December 9, 2025, [https://www.reddit.com/r/footballmanagergames/comments/o6ncew/playing\_player\_out\_of\_position/](https://www.reddit.com/r/footballmanagergames/comments/o6ncew/playing_player_out_of_position/)  
14. Natural / accomplished \- Football Manager General Discussion \- Sports Interactive Community, accessed December 9, 2025, [https://community.sports-interactive.com/forums/topic/373549-natural-accomplished/](https://community.sports-interactive.com/forums/topic/373549-natural-accomplished/)  
15. A huge pitfall in the new out of posession tactical feature : r/footballmanagergames \- Reddit, accessed December 9, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1ny09nk/a\_huge\_pitfall\_in\_the\_new\_out\_of\_posession/](https://www.reddit.com/r/footballmanagergames/comments/1ny09nk/a_huge_pitfall_in_the_new_out_of_posession/)  
16. Hidden Attributes and Ability \- Football Manager General Discussion, accessed December 9, 2025, [https://community.sports-interactive.com/forums/topic/88281-hidden-attributes-and-ability/](https://community.sports-interactive.com/forums/topic/88281-hidden-attributes-and-ability/)  
17. Positional Familiarity is Wack \- Football Manager General Discussion, accessed December 9, 2025, [https://community.sports-interactive.com/forums/topic/427836-positional-familiarity-is-wack/](https://community.sports-interactive.com/forums/topic/427836-positional-familiarity-is-wack/)  
18. How much does playing a player out of position actually affect their in game performance ? : r/footballmanagergames \- Reddit, accessed December 9, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1ekrfvg/how\_much\_does\_playing\_a\_player\_out\_of\_position/](https://www.reddit.com/r/footballmanagergames/comments/1ekrfvg/how_much_does_playing_a_player_out_of_position/)  
19. Breaking Down Football Manager 2026's New Tactical Evolution \- FM Blog, accessed December 9, 2025, [https://www.footballmanagerblog.org/2025/10/fm26-new-tactical-evolution-breakdown.html](https://www.footballmanagerblog.org/2025/10/fm26-new-tactical-evolution-breakdown.html)  
20. Football Manager 26 Introduces New Tactics System \- Operation Sports, accessed December 9, 2025, [https://www.operationsports.com/football-manager-26-introduces-new-tactics-system/](https://www.operationsports.com/football-manager-26-introduces-new-tactics-system/)  
21. The Ultimate Guide to Hidden Attributes in Football Manager \- FM Blog, accessed December 9, 2025, [https://www.footballmanagerblog.org/2024/09/football-manager-guide-hidden-attributes.html](https://www.footballmanagerblog.org/2024/09/football-manager-guide-hidden-attributes.html)  
22. How important is playing a player in their natural position? \- Reddit, accessed December 9, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1bya9hm/how\_important\_is\_playing\_a\_player\_in\_their/](https://www.reddit.com/r/footballmanagergames/comments/1bya9hm/how_important_is_playing_a_player_in_their/)  
23. Taking player development to the next level: An in-depth guide on player personalities and what they mean, and a detailed statistical analysis on why Determination is overrated in regards to player development. : r/footballmanagergames \- Reddit, accessed December 9, 2025, [https://www.reddit.com/r/footballmanagergames/comments/jr60h8/taking\_player\_development\_to\_the\_next\_level\_an/](https://www.reddit.com/r/footballmanagergames/comments/jr60h8/taking_player_development_to_the_next_level_an/)  
24. Effect of playing out of position : r/footballmanagergames \- Reddit, accessed December 9, 2025, [https://www.reddit.com/r/footballmanagergames/comments/16h4v6b/effect\_of\_playing\_out\_of\_position/](https://www.reddit.com/r/footballmanagergames/comments/16h4v6b/effect_of_playing_out_of_position/)  
25. Attributes dropping when training new position \- Sports Interactive Community, accessed December 9, 2025, [https://community.sports-interactive.com/forums/topic/571974-attributes-dropping-when-training-new-position/](https://community.sports-interactive.com/forums/topic/571974-attributes-dropping-when-training-new-position/)  
26. Versatility impact on CA \- Football Manager General Discussion, accessed December 9, 2025, [https://community.sports-interactive.com/forums/topic/452252-versatility-impact-on-ca/](https://community.sports-interactive.com/forums/topic/452252-versatility-impact-on-ca/)  
27. (Table) How each Attribute contributes to players' Current Ability for ..., accessed December 9, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1ebzb6j/table\_how\_each\_attribute\_contributes\_to\_players/](https://www.reddit.com/r/footballmanagergames/comments/1ebzb6j/table_how_each_attribute_contributes_to_players/)  
28. Why my wonder kid stats keep dropping? : r/footballmanagergames \- Reddit, accessed December 9, 2025, [https://www.reddit.com/r/footballmanagergames/comments/19c9vmu/why\_my\_wonder\_kid\_stats\_keep\_dropping/](https://www.reddit.com/r/footballmanagergames/comments/19c9vmu/why_my_wonder_kid_stats_keep_dropping/)  
29. How long it takes to train a player at completely unknown position? \- Reddit, accessed December 9, 2025, [https://www.reddit.com/r/footballmanagergames/comments/s8me93/how\_long\_it\_takes\_to\_train\_a\_player\_at\_completely/](https://www.reddit.com/r/footballmanagergames/comments/s8me93/how_long_it_takes_to_train_a_player_at_completely/)  
30. What does each Individual Training Focus do in Football Manager 26? \- Reddit, accessed December 9, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1os168n/what\_does\_each\_individual\_training\_focus\_do\_in/](https://www.reddit.com/r/footballmanagergames/comments/1os168n/what_does_each_individual_training_focus_do_in/)