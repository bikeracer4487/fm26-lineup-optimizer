

# **Positional Architecture in Football Manager 2026: An Exhaustive Analysis of Retraining Protocols, Tactical Periodization, and Asset Optimization**

## **1\. Executive Summary**

The release of Football Manager 2026 (FM26) marks a watershed moment in the simulation of football management, primarily driven by the decoupling of tactical phases into distinct **In Possession (IP)** and **Out of Possession (OOP)** systems.1 This architectural shift compels a radical re-evaluation of player development paradigms, particularly concerning positional retraining. The user's query—regarding the viability of converting a natural Striker into a Defensive Midfielder—serves as the focal point for a broader investigation into the mechanics of versatility, the economics of Current Ability (CA), and the strategic manipulation of the new dual-role frameworks.

This report establishes that while the introduction of bridging roles such as the **Tracking Centre Forward** diminishes the absolute necessity of drastic positional conversions for defensive structure 2, the retraining of forwards into defensive midfielders remains a potent strategy for optimizing "CA efficiency," particularly for players with high physical and mental attributes but declining offensive technical output. However, this process is currently complicated by interface limitations regarding OOP training, necessitating specific workarounds.3 By synthesizing data on attribute weighting, hidden versatility metrics, and the new role ecosystem, this document provides a definitive operational framework for high-level squad engineering.

## **2\. The Tactical Paradigm Shift: In Possession vs. Out of Possession Dynamics**

To evaluate the strategic merit of retraining a player, one must first deconstruct the environment in which they operate. FM26 moves beyond the singular formation model, requiring managers to construct two distinct spatial arrangements: a base structure for ball progression (IP) and a defensive block (OOP).1

### **2.1 The Dual-Formation Mechanic and Spatial Geometry**

In previous iterations, a player's position was static, with their "Role" determining their movement deviation. FM26 formalizes this deviation into two separate coordinate sets. A manager might deploy a **4-3-3** in possession that morphs into a **4-1-4-1** or **4-4-2** out of possession.1

This mechanic introduces the concept of **Positional Distance**. The match engine evaluates the spatial disparity between a player's IP and OOP coordinates. If a manager attempts to instruct a player to operate as a central Striker (IP) and a central Defender (OOP), the system triggers a warning regarding the drastic difference in positioning.5 This warning is not merely cosmetic; it indicates a potential penalty in transition efficiency. The player cannot physically traverse the distance quickly enough to maintain defensive integrity during a turnover (negative transition).

Therefore, retraining is no longer solely about attribute suitability; it is about **Transition Management**. Retraining a Striker to play Defensive Midfield (OOP) reduces the "Transition Distance" compared to asking them to defend as a Centre-Back. The game engine now calculates defensive vulnerability based on these transition vectors, making positional familiarity in the OOP slot critical for minimizing the time it takes for the team to settle into its defensive block.6

### **2.2 The Visualiser: A Diagnostic Tool for Retraining**

FM26 introduces the **Visualiser** tool, which provides a dynamic representation of player movement across different thirds of the pitch.5 This tool is essential for evaluating retraining candidates. By observing the "ghost" movements of a specific role—such as the **Pressing Defensive Midfielder**—managers can see that this role often pushes high into the central strata to engage ball carriers.1

**Insight:** The Visualiser reveals that the operational zone of a **Pressing Defensive Midfielder** often overlaps significantly with the defensive operational zone of a **Deep-Lying Forward**. This overlap suggests that the *tactical distance* between these two positions is shorter than the *nominal distance* on the formation screen. Consequently, a Striker retraining as a DM is mechanically sound because the spatial behaviors are congruent, provided the player has the requisite mobility.1

## **3\. The Mechanics of Positional Acquisition and Training**

The process of training a player for a new position is governed by a complex interplay of hidden attributes, explicit training modules, and the accumulation of match experience.

### **3.1 The Hidden Variable: Versatility**

The success of any positional conversion relies heavily on the **Versatility** attribute. This hidden metric, ranging from 1 to 20, determines the rate of positional acquisition and the player's performance stability when operating in non-natural roles.7

* **High Versatility (15-20):** Players can achieve "Accomplished" status in a completely new position within 3-6 months of intensive training and match exposure. These players act as "tactical clay," allowing managers to mold them to fit complex hybrid systems (e.g., an Inverted Wing-Back who defends as a Centre-Back).8  
* **Low Versatility (1-5):** These players may never progress beyond "Awkward" or "Unconvincing," regardless of training duration. Furthermore, forcing them to play out of position can lead to significant drops in average rating and morale.9

**Scouting Indicator:** Without the in-game editor, managers must rely on Coach Reports and Scout Reports. A report stating "Can play in a couple of positions" or referencing the player as a "utility man" is a strong proxy for high Versatility.10 For the specific case of converting a Striker to a DM, finding a candidate with high Versatility is non-negotiable. A low-versatility Striker will simply fail to adapt to the defensive positioning requirements, becoming a liability in the engine.

### **3.2 The "OOP Training" Interface Limitation**

A critical operational challenge in the current FM26 build is the inability to easily train an Out of Possession role that differs from the In Possession role. Managers have reported that the training UI often restricts focus to the primary IP position, making it difficult to explicitly drill the OOP familiarity.3

**The Feedback Loop of Failure:** If a player is assigned a Winger role (IP) and a Full-Back role (OOP), but the training module only focuses on the Winger role, the player never gains the "Defensive Positioning" attributes required for the Full-Back slot. The match engine then penalizes the player for low familiarity in the OOP phase, leading to poor performance, which in turn slows down development.3

**Strategic Workaround:** To retrain a Striker to a Defensive Midfielder effectively, one cannot rely on the tactical screen assignments alone. The manager **must** manually set the **Individual Training Focus** to the target position (e.g., DM \- Ball Winning Midfielder).9 This overrides the UI limitation by forcing the player to adopt the training regimen of the target role, irrespective of where they are placed in the match tactic. This ensures the player gains the necessary "Positioning" and "Marking" attribute growth required for the conversion.12

### **3.3 Training Focus Breakdown and Attribute Gains**

Understanding exactly what attributes are improved by specific training focuses is vital for assessing the viability of a conversion. In FM26, the specific attribute gains for relevant focuses are as follows 12:

**Table 1: Positional Training Focus and Attribute Correlation**

| Training Focus | Attributes Targeted | Strategic Relevance for ST \-\> DM Conversion |
| :---- | :---- | :---- |
| **Defensive Positioning** | Marking, Positioning, Decisions | **Critical.** The primary deficiency of most Strikers. |
| **Endurance** | Stamina, Work Rate | **High.** DMs cover more ground; Strikers often have bursts of speed but lower base stamina. |
| **Strength** | Strength, Jumping Reach | **High.** Essential for aerial dominance in midfield battles. |
| **Ball Control** | First Touch, Dribbling, Technique | **Moderate.** Useful for Retaining Possession (Regista roles). |
| **Quickness** | Pace, Acceleration | **Universal.** High value in all positions; likely already high in Strikers. |
| **Agility & Balance** | Agility, Balance | **Moderate.** Helps in turning under pressure in the midfield engine room. |

Data aggregated from.12

It is crucial to note that **Match Practice** remains the single most effective method for positional learning. No amount of training ground work substitutes for the "familiarity ticks" gained during competitive minutes.13

## **4\. The Economics of Potential: CA Cost and Attribute Weighting**

The decision to retrain a player is ultimately an economic one involving the player's **Current Ability (CA)** and **Potential Ability (PA)** budget. FM26 utilizes a sophisticated weighting system where attributes "cost" different amounts of CA points depending on the player's natural position.15

### **4.1 The Mechanism of Attribute Weighting**

Every position has a "DNA" of weighted attributes. The match engine calculates a player's CA based on how high their attributes are in relation to these weights.

* **Striker DNA:** Heavily weighted towards **Finishing, Off the Ball, Acceleration, Pace**. A Striker with 20 Finishing consumes a massive amount of CA.17  
* **Defensive Midfielder DNA:** Heavily weighted towards **Positioning, Tackling, Marking, Anticipation**. Finishing has a negligible weight.16

### **4.2 The "Dual-National" Penalty**

When a player learns a new position to "Natural" or "Accomplished" status, the game recalculates their CA usage based on the *union* of the attribute weights for all their positions.

The "Tax" of Conversion:  
If a Natural Striker (High Finishing, Low Tackling) trains to become a Natural Defensive Midfielder (Low Finishing, High Tackling), they enter a state of inefficiency.

1. **Finishing:** Remains expensive because they are still a Striker.  
2. **Tackling:** Becomes expensive because they are now a Defensive Midfielder.

Consequently, to improve this player's Tackling to a respectable level (e.g., 14), the CA cost is significantly higher than it would be for a pure Striker. Simultaneously, their 18 Finishing continues to eat up CA space despite being largely irrelevant for their DM duties.16 This creates a "CA Squeeze," where the player has less room for overall growth compared to a specialist.

**Mitigation:** This "tax" is why many successful conversions stop at "Accomplished" rather than pushing for "Natural." Furthermore, converting a player who already possesses the *universal* attributes (Physicals) is more efficient than trying to teach physicals to a technical player. Research indicates that **Physical Attributes (Pace, Acceleration)** yield the highest point-return per season in the match engine, regardless of position.20 Therefore, a fast Striker converted to DM is economically superior to a slow DM converted to anything else, because the "expensive" physical stats are being utilized in both roles.

### **4.3 The Versatility of "Physicals"**

The "Physical Meta" in FM26 remains dominant. A player with elite Pace, Acceleration, and Strength can perform adequately in almost any central role solely due to their ability to cover ground and win duels.20 This supports the thesis that converting athletic Strikers to defensive roles is viable; their athleticism (which costs the most CA) is transferable, whereas a technical playmaker's passing ability acts as a force multiplier only if they have the time on the ball to use it.

## **5\. Strategic Deep Dive: The Striker to Defensive Midfielder Conversion**

Addressing the user's specific query, we analyze the conversion of a Striker to a Defensive Midfielder. This move, often inspired by real-world examples like Joelinton (Newcastle) or Alan Smith (Man Utd), is highly effective in FM26 under specific conditions.

### **5.1 The "Pressing Forward" Profile**

The ideal candidate for this conversion is not the "Poacher" or "Advanced Forward" but the **Pressing Forward**.

* **Key Attributes:** Aggression, Work Rate, Teamwork, Stamina, Strength.21  
* **Overlap:** These attributes are *identical* to the core requirements of a **Ball Winning Midfielder** or **Pressing Defensive Midfielder**.22

A Pressing Forward is effectively a defensive player deployed high up the pitch. By moving them to the DM strata, the manager leverages their natural aggression in a zone where ball recovery is more valuable. Their "Finishing" attribute becomes a sunken cost, but their "Work Rate" becomes a primary asset.

### **5.2 Benefits of the Conversion**

1. **Late Runs from Deep:** A converted Striker typically retains high **Off the Ball** movement (15+). In FM26, a DM with elite Off the Ball movement (e.g., playing as a Segundo Volante or Roaming Playmaker) will identify space for late runs into the box that a natural DM (with Off the Ball 8\) would miss. This adds a layer of verticality to the attack that is difficult for opposition AIs to track.23  
2. **Pressing Intensity:** A converted Striker with 18 Agression and 18 Work Rate will press with an intensity that standard DMs often lack. In a *Gegenpress* system, having a DM who actively hunts the ball (Pressing Defensive Midfielder role) disrupts opposition build-up before it crosses the halfway line.1  
3. **Career Extension:** As Strikers age, their burst acceleration (vital for beating offside traps) fades. However, their mental reading of the game often improves. Moving them to DM allows them to use their **Anticipation** and **Decisions** to intercept play rather than outrun it.13

### **5.3 Risks and Considerations**

* **Defensive Positioning Training:** The player *must* be placed on the **Defensive Positioning** individual focus immediately. Their "Marking" attribute will likely start very low (5-8). It needs to reach at least 10-12 to avoid them being a liability on set pieces and tracking runners.12  
* **Trait Conflict:** Managers must review the player's traits. A Striker with "Likes to beat offside trap" or "hugs line" might behave erratically in a DM role. Traits like "Arrives late in opponents area" or "Plays one-twos" are highly desirable for the converted role.25

## **6\. Comprehensive Analysis of New FM26 Roles and Retraining Needs**

FM26 introduces a suite of new roles designed to bridge the gap between traditional positions. These roles often negate the need for full retraining by allowing players to perform hybrid functions.

### **6.1 The Tracking Centre Forward (OOP)**

This role is the most significant argument *against* retraining a Striker to DM for defensive purposes.

* **Function:** The **Tracking Centre Forward** drops deep into the midfield strata when the team loses possession, effectively becoming an extra midfielder.2  
* **Strategic Value:** If the goal is simply to have a Striker contribute to the defensive block, assigning this role is superior to retraining. It requires the player to have **Work Rate** and **Stamina**, but it does not require them to learn the DM position or gain attributes like Tackling to the same degree as a full conversion. This preserves their CA efficiency for attacking duties.22

### **6.2 The Advanced Centre-Back (IP)**

* **Function:** This player acts as a standard defender OOP but steps up into the Defensive Midfield strata during build-up (IP).26  
* **Retraining implication:** This allows managers to use a Ball-Playing Defender as a pivot without retraining them as a DM. It is the functional inverse of the Striker-to-DM switch.

### **6.3 The "Wide" Ecosystem**

FM26 introduces granular wide roles like the **Wide Outlet Winger** and **Tracking Winger**.22

* **Tracking Winger:** Acts as a defensive winger/wide midfielder OOP.  
* **Wide Outlet Winger:** Stays high and wide, effectively disengaging from defensive duties to be a counter-attack threat.  
* **Implication:** A manager can now utilize a "lazy" winger (Low Work Rate) effectively by assigning the **Wide Outlet** role, which codifies their lack of tracking back into a tactical instruction rather than a flaw. This reduces the need to force-train defensive attributes on players who are ill-suited for them.

**Table 2: New FM26 Roles Facilitating Positional Fluidity**

| New Role | Phase | Function | Strategic Alternative to Retraining |
| :---- | :---- | :---- | :---- |
| **Tracking Centre Forward** | OOP | Drops into midfield to defend central space. | Negates need to retrain ST as DM for defensive numbers. |
| **Advanced Centre-Back** | IP | Steps into DM strata to distribute. | Allows CBs to act as DMs without full conversion. |
| **Pressing Defensive Midfielder** | OOP | Aggressively hunts ball carriers high up pitch. | Ideal entry role for converted Pressing Forwards. |
| **Wide Outlet Winger** | IP/OOP | Stays high; pure counter-attack outlet. | Allows usage of low-work-rate wingers without defensive liability. |
| **Channel Midfielder** | IP | Operates in half-spaces; connects wide/central. | Bridge between Mezzala and Winger; suits mobile CMs. |

Data aggregated from.2

## **7\. Training Methodologies & Micro-Management**

To execute a positional retraining strategy effectively, managers must engage with the details of the training module.

### **7.1 Individual Focus and Rehabilitation**

The 12 research snippet provides a granular breakdown of training focuses, which includes crucial data on rehabilitation. This is relevant for retraining because injuries can derail the learning process.

* **Quickness Rehab:** Focuses on restoring Pace/Acceleration.  
* **Agility Rehab:** Focuses on Agility/Balance.  
* **General Rehab:** A balanced approach.  
* **Strategic Note:** When a player undergoing retraining gets injured, switching their focus to "Tactical" or "Mental" rehab (if available via specific role training) can help maintain their mental attribute growth even while physically incapacitated, though FM26 focuses heavily on physical rehab.12

### **7.2 Set Pieces as Attribute Boosters**

Training a player on set pieces acts as a "hack" to boost specific technical attributes that might be lagging in a new position.

* **Free Kick Taking:** Boosts **Technique** and **Free Kick Taking**.12  
* **Corner Taking:** Boosts **Technique** and **Corners**.12  
* **Technique** is a "gateway" attribute that acts as a modifier for almost all technical interactions. A Striker converting to a Playmaker DM needs high Technique. Assigning them "Free Kick" training is a low-intensity way to boost this specific stat without the fatigue cost of a heavier physical schedule.12

### **7.3 Goalkeeping Training for Outfielders?**

While rare, the breakdown shows that **GK Distribution (Short)** trains **First Touch, Passing, and Vision**.12 While managers cannot typically assign GK training to outfielders, this highlights the interconnectedness of the engine. For Goalkeepers being retrained (e.g., Sweeper Keeper to Ball Playing Keeper), focusing on **GK Distribution** is the primary method to improve their ability to act as the "11th outfield player" in build-up.

## **8\. Empirical Evidence & Historical Precedent**

The viability of these strategies is supported by community findings and historical data embedded in the FM community's collective knowledge.

* **The "Lahm" Precedent:** Community discussions 23 reference Pep Guardiola's conversion of Philipp Lahm from Full-Back to Defensive Midfielder. In FM, this corresponds to retraining a high-IQ (Anticipation, Decisions) player into a central pivot.  
* **The "Joelinton" Arc:** A classic example of a Striker (Newcastle United) failing to score but succeeding as a Ball Winning Midfielder due to high physicals. In FM26, this is replicated by taking a "Target Forward" or "Pressing Forward" and moving them to the midfield strata.29  
* **Target Man to Centre-Back:** Another common conversion mentioned is moving a tall, slow Target Man to Centre-Back. Their **Jumping Reach** and **Strength** are elite for both roles, and their lack of Pace is less exposed in a low defensive block.23  
* **Winger to Full-Back:** A frequent strategy involving converting pacey wingers to Wing-Backs. This utilizes their Dribbling and Crossing in deep areas, effectively creating an overload. The new **Inside Wing-Back** role facilitates this by asking the player to drive inside (like a winger) rather than just overlapping.29

## **9\. Strategic Synthesis & Recommendations**

Based on the exhaustive analysis of FM26's mechanics, the following recommendations are presented for the user:

### **9.1 When to Retrain ST to DM**

**YES, IF:**

* The Striker has **Work Rate \> 15**, **Stamina \> 15**, and **Aggression \> 14**.  
* The Striker is "Pace-reliant" but losing speed (Age 29+), or is a "Physical Monster" with poor finishing (Finishing \< 10).  
* The intended role is **Pressing Defensive Midfielder** or **Ball Winning Midfielder** (utilizing physicals) or **Regista** (utilizing technique/vision).  
* The player has high **Versatility** (indicated by Coach Report).

**NO, IF:**

* The Striker is a "Poacher" profile (Low Work Rate, Low Stamina, High Finishing). The CA tax on their finishing makes them inefficient, and they lack the engine to play midfield.  
* The player has Low Versatility. They will never learn the defensive positioning required to avoid being a liability.

### **9.2 Execution Protocol**

1. **Immediate Action:** Set Individual Training to **Defensive Midfielder (Defend)**. Do not rely on the "Out of Possession" tactic slot due to current UI bugs.3  
2. **Focus Selection:** Add an additional focus on **Defensive Positioning** to power-level Marking and Positioning.12  
3. **Mentoring:** Place the player in a mentoring group with an experienced Defensive Midfielder (preferably one with high "Professionalism") to encourage defensive trait adoption.  
4. **Tactical Integration:** Use the **Tracking Centre Forward** role in the interim to acclimatize the player to dropping deep before fully committing to the DM position.2

### **9.3 The "Golden Rule" of FM26 Retraining**

"Role Function over Position Name."  
In FM26, the distinction between positions is blurring. If a role (like Tracking CF or Advanced CB) exists that mimics the desired behavior, use the role instead of retraining the position. Retraining should be reserved for when the player's attributes are fundamentally misaligned with their current position (e.g., a Striker who can't shoot but can tackle), rather than just for tactical shape.  
By adhering to this rigorous analytical framework, managers can exploit the flexibility of the FM26 engine, turning positional ambiguity into a distinct competitive advantage.

#### **Works cited**

1. In Possession, Out of Possession: FM26's New Tactical Evolution | Football Manager 26, accessed November 20, 2025, [https://www.footballmanager.com/fm26/features/possession-out-possession-fm26s-new-tactical-evolution](https://www.footballmanager.com/fm26/features/possession-out-possession-fm26s-new-tactical-evolution)  
2. \[FM26\] Out Of Possession Player Roles Guide \- Tactics, Training & Strategies Discussion \- Sports Interactive Community, accessed November 20, 2025, [https://community.sports-interactive.com/forums/topic/594846-fm26-out-of-possession-player-roles-guide/](https://community.sports-interactive.com/forums/topic/594846-fm26-out-of-possession-player-roles-guide/)  
3. OOP Training makes zero sense in FM26. Am I missing something? \- Reddit, accessed November 20, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1ot7leb/oop\_training\_makes\_zero\_sense\_in\_fm26\_am\_i/](https://www.reddit.com/r/footballmanagergames/comments/1ot7leb/oop_training_makes_zero_sense_in_fm26_am_i/)  
4. There is currently no option to train a players out of possession position the way you can with In Possession \- Sports Interactive Community, accessed November 20, 2025, [https://community.sports-interactive.com/bugtracker/1644\_football-manager-26-bugs-tracker/all-other-issues/there-is-currently-no-option-to-train-a-players-out-of-possession-position-the-way-you-can-with-in-possession-r33094/](https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/all-other-issues/there-is-currently-no-option-to-train-a-players-out-of-possession-position-the-way-you-can-with-in-possession-r33094/)  
5. Beginners Guide to FM26 Tactics Creation: In- & Out Of Possession Tactics, New Player Roles & Visualizer • Passion4FM.com, accessed November 20, 2025, [https://www.passion4fm.com/fm26-tactics-creation-beginners-guide/](https://www.passion4fm.com/fm26-tactics-creation-beginners-guide/)  
6. A huge pitfall in the new out of posession tactical feature, accessed November 20, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1ny09nk/a\_huge\_pitfall\_in\_the\_new\_out\_of\_posession/](https://www.reddit.com/r/footballmanagergames/comments/1ny09nk/a_huge_pitfall_in_the_new_out_of_posession/)  
7. ELI5: Hidden attributes : r/footballmanagergames \- Reddit, accessed November 20, 2025, [https://www.reddit.com/r/footballmanagergames/comments/3a9yb4/eli5\_hidden\_attributes/](https://www.reddit.com/r/footballmanagergames/comments/3a9yb4/eli5_hidden_attributes/)  
8. How long it takes to train a player at completely unknown position? \- Reddit, accessed November 20, 2025, [https://www.reddit.com/r/footballmanagergames/comments/s8me93/how\_long\_it\_takes\_to\_train\_a\_player\_at\_completely/](https://www.reddit.com/r/footballmanagergames/comments/s8me93/how_long_it_takes_to_train_a_player_at_completely/)  
9. How to play a player in a new position : r/footballmanagergames \- Reddit, accessed November 20, 2025, [https://www.reddit.com/r/footballmanagergames/comments/t3ckgx/how\_to\_play\_a\_player\_in\_a\_new\_position/](https://www.reddit.com/r/footballmanagergames/comments/t3ckgx/how_to_play_a_player_in_a_new_position/)  
10. Football Manager Guide to Hidden Attributes • Passion4FM.com, accessed November 20, 2025, [https://www.passion4fm.com/football-manager-guide-to-hidden-attributes/](https://www.passion4fm.com/football-manager-guide-to-hidden-attributes/)  
11. OOP Position Training does NOT work\! \- Sports Interactive Community, accessed November 20, 2025, [https://community.sports-interactive.com/bugtracker/1644\_football-manager-26-bugs-tracker/1887\_newgen-development-training/oop-position-training-does-not-work-r41140/](https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/1887_newgen-development-training/oop-position-training-does-not-work-r41140/)  
12. What does each Individual Training Focus do in Football Manager 26? \- Reddit, accessed November 20, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1os168n/what\_does\_each\_individual\_training\_focus\_do\_in/](https://www.reddit.com/r/footballmanagergames/comments/1os168n/what_does_each_individual_training_focus_do_in/)  
13. Transform Your Team's Game: The Ultimate Guide to Player Retraining in Football Manager, accessed November 20, 2025, [https://www.footballmanagerblog.org/2023/05/player-retraining-football-manager.html](https://www.footballmanagerblog.org/2023/05/player-retraining-football-manager.html)  
14. The Complete Guide to Youth Intakes, Training and Development based on extensive testing : r/footballmanagergames \- Reddit, accessed November 20, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1mdcrps/the\_complete\_guide\_to\_youth\_intakes\_training\_and/](https://www.reddit.com/r/footballmanagergames/comments/1mdcrps/the_complete_guide_to_youth_intakes_training_and/)  
15. Positional Familiarity is Wack \- Football Manager General Discussion \- Sports Interactive Community, accessed November 20, 2025, [https://community.sports-interactive.com/forums/topic/427836-positional-familiarity-is-wack/](https://community.sports-interactive.com/forums/topic/427836-positional-familiarity-is-wack/)  
16. Does new position take up CA? \- Football Manager General Discussion, accessed November 20, 2025, [https://community.sports-interactive.com/forums/topic/284546-does-new-position-take-up-ca/](https://community.sports-interactive.com/forums/topic/284546-does-new-position-take-up-ca/)  
17. (Table) How each Attribute contributes to players' Current Ability for each Position \- Reddit, accessed November 20, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1ebzb6j/table\_how\_each\_attribute\_contributes\_to\_players/](https://www.reddit.com/r/footballmanagergames/comments/1ebzb6j/table_how_each_attribute_contributes_to_players/)  
18. Effect of new position training on PA/CA : r/footballmanagergames \- Reddit, accessed November 20, 2025, [https://www.reddit.com/r/footballmanagergames/comments/zll6ms/effect\_of\_new\_position\_training\_on\_paca/](https://www.reddit.com/r/footballmanagergames/comments/zll6ms/effect_of_new_position_training_on_paca/)  
19. What does Attributes Weights mean? What does this table mean? : r/footballmanagergames, accessed November 20, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1hxiu4f/what\_does\_attributes\_weights\_mean\_what\_does\_this/](https://www.reddit.com/r/footballmanagergames/comments/1hxiu4f/what_does_attributes_weights_mean_what_does_this/)  
20. FM26 Review: Strikers can't hit the goal, Defenders score Hattricks \- Reddit, accessed November 20, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1o8tq22/fm26\_review\_strikers\_cant\_hit\_the\_goal\_defenders/](https://www.reddit.com/r/footballmanagergames/comments/1o8tq22/fm26_review_strikers_cant_hit_the_goal_defenders/)  
21. Best stats for pressing? : r/footballmanagergames \- Reddit, accessed November 20, 2025, [https://www.reddit.com/r/footballmanagergames/comments/sffh7j/best\_stats\_for\_pressing/](https://www.reddit.com/r/footballmanagergames/comments/sffh7j/best_stats_for_pressing/)  
22. Every Player Position and Role in Football Manager 26, Explained \- FRVR, accessed November 20, 2025, [https://frvr.com/blog/football-manager-26-all-player-positions-and-roles-explained/](https://frvr.com/blog/football-manager-26-all-player-positions-and-roles-explained/)  
23. Has anyone changed a player's position to make him world class? : r/footballmanagergames \- Reddit, accessed November 20, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1cqtbl2/has\_anyone\_changed\_a\_players\_position\_to\_make\_him/](https://www.reddit.com/r/footballmanagergames/comments/1cqtbl2/has_anyone_changed_a_players_position_to_make_him/)  
24. Individual Training General Strategy \- Sports Interactive Community, accessed November 20, 2025, [https://community.sports-interactive.com/forums/topic/584052-individual-training-general-strategy/](https://community.sports-interactive.com/forums/topic/584052-individual-training-general-strategy/)  
25. Traits? \- Football Manager General Discussion \- Sports Interactive Community, accessed November 20, 2025, [https://community.sports-interactive.com/forums/topic/580583-traits/](https://community.sports-interactive.com/forums/topic/580583-traits/)  
26. The best Football Manager 26 players for every new role in FM26 \- FRVR, accessed November 20, 2025, [https://frvr.com/blog/the-best-football-manager-26-players-for-every-new-role-in-fm26/](https://frvr.com/blog/the-best-football-manager-26-players-for-every-new-role-in-fm26/)  
27. Football Manager 26: Each Player Role, Explained \- Operation Sports, accessed November 20, 2025, [https://www.operationsports.com/football-manager-26-each-player-role-explained/](https://www.operationsports.com/football-manager-26-each-player-role-explained/)  
28. Football Manager 26 Player Roles Revealed \- Big Changes & New Roles, accessed November 20, 2025, [https://ingenuityfantasy.com/feature-articles/fm26-all-player-roles/](https://ingenuityfantasy.com/feature-articles/fm26-all-player-roles/)  
29. (Any FM) REAL LIFE players you retrained position into stars \- Sports Interactive Community, accessed November 20, 2025, [https://community.sports-interactive.com/forums/topic/470301-any-fm-real-life-players-you-retrained-position-into-stars/](https://community.sports-interactive.com/forums/topic/470301-any-fm-real-life-players-you-retrained-position-into-stars/)