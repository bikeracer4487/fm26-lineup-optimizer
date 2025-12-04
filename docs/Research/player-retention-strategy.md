# **Advanced Asset Management Protocols in Football Manager 2026: A Data-Driven Analysis of Psychometrics, Development Curves, and Divestment Strategy**

## **1\. Executive Abstract: The Shift to Algorithmic Management**

The strategic landscape of *Football Manager 2026* (FM26) represents a definitive break from the linear progression models of previous simulation iterations. With the introduction of "Dynamic Development" mechanics 1, the refinement of training unit interactions 2, and the increased volatility of squad dynamics 3, the optimal methodology for roster construction has shifted from talent accumulation to precision asset management. The traditional approach—hoarding high Potential Ability (PA) "wonderkids" and waiting for inevitable appreciation—is now a suboptimal strategy fraught with inefficiency.

In this new ecosystem, a player’s visible attributes (e.g., Finishing, Tackling) are merely lagging indicators of past performance. The true determinants of future value—the "leading indicators"—are the hidden attributes: Professionalism, Ambition, Pressure, Consistency, and Temperament. This report operates under the premise of full data visibility, utilizing the omniscient perspective (via in-game editor or third-party tools) to deconstruct the exact mechanics of player growth and decline.4

The objective of this analysis is to establish a rigorous, quantifiable framework for the retention and divestment of player assets. We reject emotional attachment to "Club Legends" or "Fan Favorites" in favor of a cold, actuarial assessment of "Realizable Potential." By analyzing the interaction between the "DAP" triad (Determination, Ambition, Professionalism) and the new age-specific development curves 6, we derive precise heuristics for asset liquidation. Furthermore, we explore the contagion effects of squad dynamics, where the retention of "toxic" assets can mathematically depress the developmental velocity of the entire roster.8

## ---

**2\. The Psychometric Architecture of Value**

In FM26, the engine that converts Potential Ability (PA) into Current Ability (CA) is fueled almost exclusively by hidden personality attributes. While visible attributes dictate the outcome of a specific match event (e.g., a pass or a shot), hidden attributes dictate the trajectory of a career.

### **2.1 The "DAP" Trinity: The Engine of Growth**

Research consistently identifies the triad of Determination, Ambition, and Professionalism (DAP) as the fundamental drivers of attribute acquisition.6 However, their weights are unequal, and their interactions are complex.

#### **2.1.1 Professionalism: The Sustainability Metric**

Professionalism is the single most critical variable in the FM26 development algorithm. It dictates the frequency and intensity of training performance, the likelihood of complaining about workload, and the resistance to natural decline in later years.11

The mechanism of Professionalism is tied directly to the "Training Rating" system. In FM26, attribute growth is calculated weekly based on training performance.

* **High Professionalism (15-20):** These players consistently achieve training ratings \> 8.0. This triggers the maximum allocation of CA points allowed by the player's PA ceiling. Over a 5-year period, a player with Professionalism 18 will accumulate approximately 20-25% more CA points than a player with Professionalism 10, assuming identical game time and facilities.12  
* **Low Professionalism (\<10):** These players suffer from high variance in training performance. They are prone to "Slack" or "Casual" personality descriptors.13 Even with elite facilities, their internal governor limits their intake of coaching benefits. They represent a "leaking bucket" where potential is lost to inefficiency.

**Strategic Implication:** Professionalism acts as a reliability index for development. A 16-year-old with PA 180 and Professionalism 8 is statistically unlikely to ever reach their potential. They are "False Assets"—valued highly by the market for their PA, but structurally incapable of reaching it.14

#### **2.1.2 Ambition: The Double-Edged Sword**

Ambition governs a player's desire to play at the highest level and maximize their career standing.

* **The Accelerator:** High Ambition (16-20) acts as a turbocharger for early development. Ambitious players are unsatisfied with their current ability and will push harder to improve, particularly when they feel they are "below" their perceived station. This attribute is essential for maximizing growth in the critical 16-21 age window.11  
* **The Retention Risk:** The correlation between Ambition and Loyalty is often inverse. Highly ambitious players are exponentially more likely to demand wage increases, request transfers to higher-reputation clubs, and become unhappy if denied a move. They view the club as a stepping stone.14

**Strategic Implication:** High Ambition is desirable for "Cash Cow" assets (players developed specifically to be sold for profit) but dangerous for "Franchise" assets (players intended to form the spine of the team for a decade).

#### **2.1.3 Determination: The On-Pitch Catalyst**

While Determination is the only visible attribute of the DAP trinity, its function is often misunderstood. It acts as a multiplier for match performance, particularly in adverse conditions (e.g., when losing). However, high Determination *without* high Professionalism creates the "Erratic Worker" archetype—a player who runs tirelessly on match day but slacks off in training during the week.13 This leads to a player who is useful in the short term but stagnates in the long term.

### **2.2 The Stability Indices: Pressure and Consistency**

Beyond growth potential, asset value is defined by operational reliability. FM26’s match engine, which places heavy emphasis on tactical structure and error punishment 17, penalizes volatility severely.

#### **2.2.1 Pressure and "Big Match" Performance**

The hidden attribute "Pressure" (1-20) determines a player's mental composure in critical situations. A secondary hidden trait, "Important Matches," specifically modifies performance in finals, derbies, and promotion deciders.11

* **The "Choke" Factor:** A player with CA 160 but Pressure 8 will effectively perform like a CA 130 player in a Champions League final. The engine applies a negative modifier to their mental attributes (Composure, Decisions, Concentration) during high-stress simulation events.  
* **Retention Rule:** For core squad members (Starters/Squad Players), a Pressure rating \< 10 is grounds for divestment, regardless of technical ability. In FM26, where "Low Block" tactics often lead to tight, low-scoring games decided by single errors, mental fragility is a systemic weakness that cannot be coached out.11

#### **2.2.2 Consistency**

Consistency is a hidden modifier (1-20) that dictates the frequency with which a player utilizes their full attribute set.

* **The Variance Trap:** A player with 20 Consistency plays at their attribute levels near 100% of the time. A player with 10 Consistency relies on a random number generator (RNG) check before each match to determine if they "show up." If they fail the check, their attributes are temporarily suppressed for that match.15  
* **Heuristic:** Players with Consistency \< 12 are "Luxury Assets." They cannot be relied upon for the grind of a 38-game league season and should be divested if a more consistent, lower-PA alternative is available.

### **2.3 The Toxicity Vectors: Controversy, Temperament, and Sportsmanship**

Squad dynamics in FM26 are fragile. Hidden "toxicity" attributes can destabilize a dressing room, causing drops in team cohesion and morale, which in turn stifles the Dynamic Development of the entire squad.1

* **Controversy:** High Controversy (\>14) leads to media circuses, leaks, and unhappiness events. This attribute has zero on-pitch benefit and is purely a liability.11  
* **Temperament:** Low Temperament (\<8) correlates with on-pitch indiscipline (red cards) and negative reactions to team talks. A player with low temperament requires constant micromanagement.11  
* **Sportsmanship:** While generally positive, extremely low Sportsmanship can lead to "Dark Arts" traits (diving, time-wasting). However, extremely high Sportsmanship (18-20) can sometimes lead to a lack of "killer instinct." A balanced rating (10-14) is often optimal for competitive play.15

## ---

**3\. The Developmental Calculus: CA/PA Heuristics**

Current Ability (CA) and Potential Ability (PA) are the fundamental currency of FM26. However, managing them requires nuance. PA is a *theoretical ceiling*, not a guaranteed destination.

### **3.1 The "Gap Theory" of Development**

The gap between CA and PA represents the "Growth Room." The critical metric for analysis is the **Required Growth Velocity (RGV)**.

$$RGV \= \\frac{PA \- CA}{Peak Age (24) \- Current Age}$$

* **Heuristic:** If a player requires \> 15 CA points per year to reach their PA, they are unlikely to maximize their potential unless they have "Model Citizen" or "Model Professional" personalities and are playing 30+ games a season in a high-reputation league.5  
* **The "Rule of 21":** By age 21, the "explosive" phase of physical development (Pace, Acceleration, Strength) typically concludes.18 If a player has not bridged the majority of their physical CA gap by 21, they likely never will.  
  * *Application:* A 21-year-old Winger with Pace 12 and PA 170 is a "Sell." Even if he reaches PA 170, the points will likely go into Technical/Mental attributes, leaving him as a slow winger—a tactical liability in modern systems.

### **3.2 The Efficiency of CA: The "Attribute Tax"**

In FM26, not all attributes "cost" the same amount of CA. The game engine weights attributes differently based on position, but certain physical attributes are universally expensive.10

* **The "Pace Tax":** Speed attributes (Pace, Acceleration) consume a disproportionate amount of the CA budget. A player with 18 Pace/Acceleration will have a significantly lower ceiling for Technical or Mental attributes than a player with 12 Pace/Acceleration, assuming identical CA.  
* **The "Two-Footed" Tax:** Training a player's weak foot consumes a massive amount of CA points. A player moving from "Reasonable" to "Strong" on their weak foot can consume 10-15 CA points.  
  * *Strategic Implication:* Unless a player is an Inside Forward or Advanced Playmaker who strictly needs dual-footedness, **do not train the weak foot.** It is an inefficient use of the limited PA budget. It is better to have those 15 CA points allocated to "Passing" or "Vision".19

### **3.3 Dynamic Potential and the "Form Factor"**

FM26 introduces Dynamic Development where form and game time influence growth more than fixed PA in some contexts.1

* **The "Form Multiplier":** A player with average PA (e.g., 140\) who plays 40 games a season with an average rating of 7.5 will develop faster and potentially exceed soft caps compared to a high PA (170) player rotting in the reserves or on loan at a club with poor facilities.  
* **Strategy:** Do not hoard high-PA players in the U18s/U21s indefinitely. If a high-PA prospect cannot break into the first team or find a high-quality loan by age 20, their "Realizable Potential" drops below a lower-PA player who is getting minutes.2

## ---

**4\. Divestment Protocols: When to Sell**

To optimize the squad, managers must strip away emotional attachment and apply rigorous quantitative thresholds. The following thresholds assume the manager aims for an elite-level squad (Champions League contender).

### **4.1 The "Hard Sell" Thresholds (Immediate Liquidation)**

If a player meets **any** of the following criteria, they should be placed on the transfer list or offered to intermediaries immediately.21 These defects are structurally fatal to elite performance or development.

| Attribute Category | Metric | Threshold (Sell Zone) | Rationale & Mechanism |
| :---- | :---- | :---- | :---- |
| **Developmental** | Professionalism | **\< 10** (Age \> 18\) | Statistical improbability of reaching PA. High risk of training stagnation. Player will essentially "stop" developing regardless of game time.12 |
| **Developmental** | Ambition | **\< 6** | "Unambitious" personality. Player lacks the drive to improve attributes. Growth halts early (age 20-21). |
| **Mental Stability** | Pressure | **\< 8** | Will consistently underperform in decisive fixtures. Liability in knockout rounds. Effective attributes drop by \~15% in finals.11 |
| **Mental Stability** | Consistency | **\< 9** | Performance variance is too high. Player effectively plays at \-20 CA in 40% of matches. |
| **Physical** | Injury Proneness | **\> 14** | Asset availability \< 60%. Disrupts tactical familiarity and prevents the formation of "partnerships" (e.g., CB pairings).15 |
| **Behavioral** | Controversy | **\> 16** | Destabilizes team dynamics; generates negative media events which lower squad morale.11 |

### **4.2 The "Peak Value" Divestment Windows**

Understanding *when* to sell is as important as *who* to sell. FM26's transfer market is influenced by player form, reputation, and contract status.

#### **4.2.1 The "False Wonderkid" Arbitrage (Age 19-21)**

* **Profile:** Age 20, PA 170 (Elite), CA 110, Professionalism 9\.  
* **Analysis:** The UI might show 5-star potential, and the transfer value might be £50m+. However, with Professionalism 9, the player lacks the work ethic to bridge the 60-point CA gap.  
* **Strategy:** **Divest immediately.** The AI evaluates the high PA and pays a premium. You are selling "hype." By age 23, when the player is still CA 115, their value will crash. Use the £50m to buy three players with PA 150 but Professionalism 18\.23

#### **4.2.2 The "Wage Ceiling" Break (Age 23-25)**

* **Profile:** High Ambition (18), CA 150 (Star Player), Wage demands \> 15% of turnover.  
* **Analysis:** Highly ambitious players often demand wages that break the club's financial structure. Their loyalty is low, meaning they will not accept "hometown discounts."  
* **Strategy:** Sell 18 months before the contract expires if renewal demands exceed the "Value Over Replacement Player" (VORP) calculation. Use the funds to sign two younger players with similar PA but lower wage demands.13

#### **4.2.3 The "Post-Peak" Decline (Age 29-31)**

* **Profile:** High physical dependence (Wingers/Strikers), Natural Fitness \< 12\.  
* **Analysis:** In FM26, physical attributes degrade rapidly post-30 for players with average Natural Fitness. A winger who relies on Pace 17 will become useless when that drops to Pace 13 at age 31\.  
* **Strategy:** Sell at age 29\. The AI often overvalues recent form. Selling a 29-year-old superstar to a Saudi or elite European club often yields maximum return just before the attribute decline curve accelerates.23

### **4.3 Operational Tactics: Intermediaries and Market Manipulation**

FM26 introduces advanced tools for divestment, most notably **Intermediaries**.21

* **The "Pre-Market" Test:** Before transfer listing a player (which alerts the squad and can cause unhappiness), use the "Hire Intermediary" function to gauge market interest. This provides a "Shadow Price"—a realistic valuation of what clubs will pay.  
* **The "Ultimatum" Strategy:** If an intermediary generates an offer that is \>150% of the player's calibrated value (based on CA/Age), accept immediately. This often occurs with Saudi Pro League clubs or desperate Premier League teams fighting relegation.  
* **Timing:** The optimal time to engage intermediaries is roughly 3 weeks before the transfer window opens. This allows them to build interest and generate a "bidding war" narrative before the window officially opens.21

## ---

**5\. Retention Protocols: The Logic of Keeping**

Divestment is only half the equation. Retention strategy is defined by identifying the players who provide stability and facilitate the development of others.

### **5.1 The "Spine" Retention Strategy**

Different positions require different hidden attribute profiles. A "Universal" retention strategy fails because the psychological demands of a Goalkeeper differ from those of a Striker.

| Role | Critical Hidden Traits | Retention Thresholds | Rationale |
| :---- | :---- | :---- | :---- |
| **Goalkeeper / CB** | Consistency, Concentration, Pressure | Cons \> 13, Pres \> 12 | Errors in the defensive spine result in goals. High consistency is non-negotiable. |
| **Playmaker (CM/AM)** | Vision, Flair, Ambition | Amb \> 14, Pro \> 14 | Creative players need the drive ("Ambition") to unlock defenses. Slightly lower consistency is tolerable for "X-Factor" moments. |
| **Striker (ST)** | Pressure, Ambition | Pres \> 14, Amb \> 15 | Strikers must handle the pressure of being the goalscorer. Low pressure leads to missed penalties and 1v1s. |

### **5.2 The "Mentor" Class: Retention of Declining Assets**

One of the most counter-intuitive strategies in FM26 is retaining players who are physically declining and no longer starters. These players are kept solely for their "Genetic Material"—their personality traits.13

* **The "Personality Donor":** A player aged 32+ with CA 110 but "Model Citizen," "Model Professional," or "Iron Will" personality.  
  * **Strategic Action:** Extend their contract on reduced wages. Change their squad status to "Emergency Backup."  
  * **Usage:** Place them in a Mentoring Group with your 3-4 highest potential prospects. They act as a "viral vector" for positive traits, transferring their Professionalism and Determination to the youth players.  
  * **Value:** The value of a mentor is not their match performance, but the accumulated CA growth they stimulate in the wonderkids. A single Model Citizen mentor can be worth effectively £100m in developed talent over 3 years.9

## ---

**6\. Squad Dynamics and Toxicity Management**

In FM26, the squad is an ecosystem. The "Dynamics" module simulates the spread of personality traits through the squad hierarchy. This biological metaphor—contagion—is the most accurate way to model retention strategy.

### **6.1 The "Contagion" of Leadership**

The most dangerous player in your squad is not the one with low ability, but the one with low Professionalism who holds a "Team Leader" position in the hierarchy.8

* **The Infection Mechanism:** Team Leaders exert a passive "gravity" on the personality of the entire squad. If a Team Leader has a "Casual" (Low Pro) or "Slack" (Low Det) personality, they will drag the average attributes of the squad down towards their level. This creates a "glass ceiling" for development; even driven youngsters will stagnate as they assimilate the leader's poor habits.  
* **The "Purge" Protocol:** You must aggressively divest from any Team Leader or Highly Influential player with toxic hidden attributes.  
  * *Action:* Sell them, even if they are your best player. If they cannot be sold, release them. The on-pitch loss is outweighed by the removal of their negative drag on the squad's development curve.  
  * *Replacement:* Appoint a Captain with "Model Professional" or "Resolute" personality immediately to reset the cultural baseline.3

### **6.2 Engineering the "Model Citizen" Squad**

The ultimate goal of retention strategy is to cultivate a squad composed entirely of "Resolute," "Perfectionist," and "Model Citizen" personalities.

* **Recruitment Filter:** When scouting, prioritize players with "Driven," "Resolute," or "Professional" descriptions. Avoid "Balanced" or "Light-Hearted" unless their visible Determination is high (suggesting the hidden attributes are decent).  
* **The "Squad Personality" Bonus:** Over time, as the aggregate personality of the squad improves, the "Squad Personality" descriptor will change (e.g., to "Highly Professional"). This grants a passive bonus to the development rate of all players and improves the personality quality of annual youth intakes.8

## ---

**7\. Development Protocols: The 18-21-24 Checkpoints**

To systematize the "Keep vs. Sell" decision, we implement a checkpoint system based on age and developmental velocity.5

### **7.1 Checkpoint 1: Age 18 (The Academy Graduate)**

* **Assessment:** Has the player improved by at least 10 CA points since intake (Age 15/16)?  
* **Action:**  
  * **Keep:** Professionalism \> 12, Determination \> 10\. Showing "green arrows" in training progress. Move to **First Team Training Units** to expose them to better coaches and mentors, even if they play for the U18s.2  
  * **Release:** Professionalism \< 8\. Stagnant attributes. "Slack" personality. These players are "roster cloggers" and should be released to free up training slots.

### **7.2 Checkpoint 2: Age 21 (The Loan Verification)**

* **Assessment:** Has the player performed at a senior level (loan or squad rotation)?  
* **Metric:** Average Rating \> 7.00 in a playable league.  
* **CA/PA Check:** Is CA within 30 points of PA? OR Is CA \> 130 (Premier League level)?  
* **Action:**  
  * **Keep:** Player is labeled "Breakthrough Prospect." Professionalism \> 14\.  
  * **Sell:** Player failed on loan (Rating \< 6.8). CA gap \> 50 points. This is the "False Wonderkid" checkpoint. Sell while the PA still looks high to the AI.

### **7.3 Checkpoint 3: Age 24 (The Final Verdict)**

* **Assessment:** Is the player a "Starter" or "Important Player"?  
* **Action:**  
  * **Keep:** Player has reached PA cap (or close to it). Consistent performer.  
  * **Sell:** Player is "Squad Player" but has high wages. Player has high Ambition but stalled CA.  
* **Rationale:** At 24, players lose the "Young Player" tag. Their transfer value stabilizes or dips if they aren't starters. This is the last chance to sell on "potential" before the market treats them as a "finished product".28

## ---

**8\. Detailed Appendices and Reference Tables**

### **Appendix A: Personality Decoding Guide (Estimating Hidden Stats)**

Even without the editor, Media Handling and Personality descriptions map to hidden numbers. This table helps "eyeball" the hidden stats.11

| Personality Description | Est. Professionalism | Est. Determination | Est. Ambition | Est. Pressure | Retention Verdict |
| :---- | :---- | :---- | :---- | :---- | :---- |
| **Model Citizen** | 18-20 | 18-20 | 10-15 | 18-20 | **KEEP (Gold Standard)** |
| **Model Professional** | 18-20 | 10-20 | 1-20 | 1-20 | **KEEP (Perfect Tutor)** |
| **Professional** | 15-17 | 10-20 | 1-20 | 1-20 | **KEEP** |
| **Perfectionist** | 14-20 | 14-20 | 14-20 | 1-20 | **KEEP (Watch Wages)** |
| **Resolute** | 15-17 | 15-17 | 1-20 | 1-20 | **KEEP** |
| **Spirited** | 11-17 | 10-17 | 10-20 | 15-20 | **GOOD (High Pressure)** |
| **Mercenary** | 1-20 | 1-20 | 16-20 | 1-20 | **SELL (Low Loyalty)** |
| **Casual** | 1-4 | 1-20 | 1-20 | 1-20 | **SELL (Toxic)** |
| **Slack** | 1 | 1-9 | 1-20 | 1-20 | **SELL (Toxic)** |

### **Appendix B: Training Unit Optimization Strategies**

FM26's player development is heavily driven by Training Units.2

* **The "Carry" Strategy:** Place your highest potential U18 players (PA \> 160\) into the **First Team** squad but make them available for the U18 matches. Then, assign them to the First Team Training Units.  
  * *Benefit:* They train with your best coaches and your "Model Professionals," gaining superior attribute growth compared to rotting in the U18 training units (which usually have worse coaches and facilities).  
* **The "Unit Leader":** Ensure every unit (Attacking, Defending, Goalkeeping) has at least one veteran with high Professionalism. This veteran passively boosts the "Unit Atmosphere," improving the training rating of everyone in that unit.2

## ---

**9\. Conclusion**

The optimal strategy for player release and retention in *Football Manager 2026* is a rejection of hope in favor of evidence. By utilizing the visibility of hidden attributes, the manager transforms from a gambler to an architect.

The core tenets of this doctrine are:

1. **Professionalism is King:** It is the primary predictor of development and longevity.  
2. **Ambition is Dangerous:** It accelerates growth but destabilizes retention.  
3. **Toxicity is Contagious:** "Bad Apples" must be removed to protect the herd.  
4. **Age is a Rigid Filter:** Divest ruthlessly at the age checkpoints (21, 24\) if development targets are missed.

By adhering to these protocols, the FM26 manager ensures that every asset on the books is appreciating in value, contributing to the culture, or serving a specific tactical purpose. The squad becomes a self-reinforcing engine of success, immune to the volatility that plagues the unprepared.

#### **Works cited**

1. FM Mobile 2026 — New Features That Actually Change the Game : r/footballmanagergames, accessed December 4, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1okfw1h/fm\_mobile\_2026\_new\_features\_that\_actually\_change/](https://www.reddit.com/r/footballmanagergames/comments/1okfw1h/fm_mobile_2026_new_features_that_actually_change/)  
2. Football Manager 26: How to Develop Young Players \- Operation Sports, accessed December 4, 2025, [https://www.operationsports.com/football-manager-26-how-to-develop-young-players/](https://www.operationsports.com/football-manager-26-how-to-develop-young-players/)  
3. Team dynamics are the worst in this game : r/footballmanagergames \- Reddit, accessed December 4, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1jo3o6y/team\_dynamics\_are\_the\_worst\_in\_this\_game/](https://www.reddit.com/r/footballmanagergames/comments/1jo3o6y/team_dynamics_are_the_worst_in_this_game/)  
4. Will It Be Possible to Hide Attributes in FM 26 ? : r/footballmanagergames \- Reddit, accessed December 4, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1od5cde/will\_it\_be\_possible\_to\_hide\_attributes\_in\_fm\_26/](https://www.reddit.com/r/footballmanagergames/comments/1od5cde/will_it_be_possible_to_hide_attributes_in_fm_26/)  
5. At what age will a player reach is potential ability? : r/footballmanagergames \- Reddit, accessed December 4, 2025, [https://www.reddit.com/r/footballmanagergames/comments/16zlzjj/at\_what\_age\_will\_a\_player\_reach\_is\_potential/](https://www.reddit.com/r/footballmanagergames/comments/16zlzjj/at_what_age_will_a_player_reach_is_potential/)  
6. Ambition, determination & professionalism and their effect on player development : r/footballmanagergames \- Reddit, accessed December 4, 2025, [https://www.reddit.com/r/footballmanagergames/comments/ufxwmy/ambition\_determination\_professionalism\_and\_their/](https://www.reddit.com/r/footballmanagergames/comments/ufxwmy/ambition_determination_professionalism_and_their/)  
7. Has player development and ageing finally improved? : r/footballmanagergames \- Reddit, accessed December 4, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1p97yc6/has\_player\_development\_and\_ageing\_finally\_improved/](https://www.reddit.com/r/footballmanagergames/comments/1p97yc6/has_player_development_and_ageing_finally_improved/)  
8. "Less Desirable Squad Characteristics" issue \- Sports Interactive Community, accessed December 4, 2025, [https://community.sports-interactive.com/forums/topic/438366-less-desirable-squad-characteristics-issue/](https://community.sports-interactive.com/forums/topic/438366-less-desirable-squad-characteristics-issue/)  
9. Why do players always get bad influences from their mentoring group even when their mentors are very high determination and very good personalities... \- Football Manager General Discussion \- Sports Interactive Community, accessed December 4, 2025, [https://community.sports-interactive.com/forums/topic/590693-why-do-players-always-get-bad-influences-from-their-mentoring-group-even-when-their-mentors-are-very-high-determination-and-very-good-personalities/](https://community.sports-interactive.com/forums/topic/590693-why-do-players-always-get-bad-influences-from-their-mentoring-group-even-when-their-mentors-are-very-high-determination-and-very-good-personalities/)  
10. why are my wonderkid's stats going down? : r/footballmanagergames \- Reddit, accessed December 4, 2025, [https://www.reddit.com/r/footballmanagergames/comments/u736gn/why\_are\_my\_wonderkids\_stats\_going\_down/](https://www.reddit.com/r/footballmanagergames/comments/u736gn/why_are_my_wonderkids_stats_going_down/)  
11. Football Manager 2026: Best Player Personalities and Media Handling Types, accessed December 4, 2025, [https://www.playerauctions.com/guide/other/co-op-games/football-manager-2026-best-player-personalities-and-media-handling-types/](https://www.playerauctions.com/guide/other/co-op-games/football-manager-2026-best-player-personalities-and-media-handling-types/)  
12. At what age do players peak on their CA? : r/footballmanagergames \- Reddit, accessed December 4, 2025, [https://www.reddit.com/r/footballmanagergames/comments/w8n325/at\_what\_age\_do\_players\_peak\_on\_their\_ca/](https://www.reddit.com/r/footballmanagergames/comments/w8n325/at_what_age_do_players_peak_on_their_ca/)  
13. FM Personality Guide \- Tactics, Training & Strategies Discussion \- Sports Interactive forums, accessed December 4, 2025, [https://community.sports-interactive.com/forums/topic/9850-fm-personality-guide/](https://community.sports-interactive.com/forums/topic/9850-fm-personality-guide/)  
14. Football Manager 26 Personality Guide: How to Scout Wonderkids That Actually Develop, accessed December 4, 2025, [https://www.neonlightsmedia.com/blog/football-manager-26-fm26-personality-guide-scouting](https://www.neonlightsmedia.com/blog/football-manager-26-fm26-personality-guide-scouting)  
15. FM26: Hidden Attributes Explained \- Sortitoutsi, accessed December 4, 2025, [https://sortitoutsi.net/content/74854/fm26-hidden-attributes-explained](https://sortitoutsi.net/content/74854/fm26-hidden-attributes-explained)  
16. Staff: Model Citizen vs Model Professional \- Football Manager General Discussion, accessed December 4, 2025, [https://community.sports-interactive.com/forums/topic/549324-staff-model-citizen-vs-model-professional/](https://community.sports-interactive.com/forums/topic/549324-staff-model-citizen-vs-model-professional/)  
17. Football Manager 26 Mobile: New Features Showcase, accessed December 4, 2025, [https://www.footballmanager.com/fm26/features/football-manager-26-mobile-new-features-showcase](https://www.footballmanager.com/fm26/features/football-manager-26-mobile-new-features-showcase)  
18. The Complete Guide to Youth Intakes, Training and Development based on extensive testing : r/footballmanagergames \- Reddit, accessed December 4, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1mdcrps/the\_complete\_guide\_to\_youth\_intakes\_training\_and/](https://www.reddit.com/r/footballmanagergames/comments/1mdcrps/the_complete_guide_to_youth_intakes_training_and/)  
19. Why my wonder kid stats keep dropping? : r/footballmanagergames \- Reddit, accessed December 4, 2025, [https://www.reddit.com/r/footballmanagergames/comments/19c9vmu/why\_my\_wonder\_kid\_stats\_keep\_dropping/](https://www.reddit.com/r/footballmanagergames/comments/19c9vmu/why_my_wonder_kid_stats_keep_dropping/)  
20. How do you develop 18 year old hot prospects into stars? : r/footballmanagergames \- Reddit, accessed December 4, 2025, [https://www.reddit.com/r/footballmanagergames/comments/188uj6d/how\_do\_you\_develop\_18\_year\_old\_hot\_prospects\_into/](https://www.reddit.com/r/footballmanagergames/comments/188uj6d/how_do_you_develop_18_year_old_hot_prospects_into/)  
21. How to Sell Players Quickly in Football Manager 26 \- Operation Sports, accessed December 4, 2025, [https://www.operationsports.com/how-to-sell-players-quickly-in-football-manager-26/](https://www.operationsports.com/how-to-sell-players-quickly-in-football-manager-26/)  
22. I updated the personalities cheat sheet for myself. Thought I might as well share. : r/footballmanagergames \- Reddit, accessed December 4, 2025, [https://www.reddit.com/r/footballmanagergames/comments/14cjwe1/i\_updated\_the\_personalities\_cheat\_sheet\_for/](https://www.reddit.com/r/footballmanagergames/comments/14cjwe1/i_updated_the_personalities_cheat_sheet_for/)  
23. How To Save MILLIONS In FM26 When Selling Wonderkids\! \- YouTube, accessed December 4, 2025, [https://www.youtube.com/shorts/RcHhhgcvqe8](https://www.youtube.com/shorts/RcHhhgcvqe8)  
24. How to sell unwanted players in FM26 : r/footballmanagergames \- Reddit, accessed December 4, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1ox0cax/how\_to\_sell\_unwanted\_players\_in\_fm26/](https://www.reddit.com/r/footballmanagergames/comments/1ox0cax/how_to_sell_unwanted_players_in_fm26/)  
25. Does anyone else think that mentoring in FM24 is absolutely useless? Or in fact quite often has a negative effect on your youth. : r/footballmanagergames \- Reddit, accessed December 4, 2025, [https://www.reddit.com/r/footballmanagergames/comments/1k3g4pv/does\_anyone\_else\_think\_that\_mentoring\_in\_fm24\_is/](https://www.reddit.com/r/footballmanagergames/comments/1k3g4pv/does_anyone_else_think_that_mentoring_in_fm24_is/)  
26. Youth Intake Guide: What I learned over the years (+ Bonus Trick/Tip) \- Reddit, accessed December 4, 2025, [https://www.reddit.com/r/footballmanagergames/comments/ssw2ow/youth\_intake\_guide\_what\_i\_learned\_over\_the\_years/](https://www.reddit.com/r/footballmanagergames/comments/ssw2ow/youth_intake_guide_what_i_learned_over_the_years/)  
27. At what age can you still expect a young player to eventually improve his current ability by at least 0.5 star? \- Sports Interactive Community, accessed December 4, 2025, [https://community.sports-interactive.com/forums/topic/583234-at-what-age-can-you-still-expect-a-young-player-to-eventually-improve-his-current-ability-by-at-least-05-star/](https://community.sports-interactive.com/forums/topic/583234-at-what-age-can-you-still-expect-a-young-player-to-eventually-improve-his-current-ability-by-at-least-05-star/)  
28. What is the best time to sell a "Wonderkid" ? \- Football Manager General Discussion, accessed December 4, 2025, [https://community.sports-interactive.com/forums/topic/554088-what-is-the-best-time-to-sell-a-wonderkid/](https://community.sports-interactive.com/forums/topic/554088-what-is-the-best-time-to-sell-a-wonderkid/)