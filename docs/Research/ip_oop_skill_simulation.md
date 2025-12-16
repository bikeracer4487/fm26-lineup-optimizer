# How FM26 Calculates Player Effectiveness in the IP/OOP System

Football Manager 2026's revolutionary dual-formation system fundamentally changes how player effectiveness is evaluated. **Star ratings in the Combined view use a simple average of In Possession and Out of Possession ratings**, while the match engine applies separate positional penalties during each phase of play. Testing confirms that low positional familiarity in OOP positions can reduce winning rate by 6% and goal difference by 13 points—a substantial competitive disadvantage.

The IP/OOP system represents FM's most significant tactical overhaul ever, replacing the traditional Defend/Support/Attack duty modifiers with explicit dual formations. Sports Interactive's official documentation and community testing reveal a system where position familiarity and attribute suitability are calculated independently for each possession phase.

## The match engine evaluates IP and OOP positions separately

Sports Interactive Senior Product Owner Jack Joyce confirmed the core mechanic in community discussions: **"A player's suitability for any Out of Possession role depends on two things: their positional familiarity (how comfortable they are in that area of the pitch) and their key attributes for the role in question."** Both IP and OOP roles receive independent five-star ratings built directly into player reports.

When a player occupies different positions across phases—such as Wide Midfielder (M/L) when in possession but Wing-Back (WB/L) when defending—the match engine does not blend these evaluations into a single calculation. Instead, it applies the appropriate positional familiarity modifier during each respective phase. A player who is "natural" at M(L) but only "competent" at WB(L) will perform optimally during attacking phases but suffer approximately **15% effectiveness reduction** during defensive responsibilities.

The positional penalty scale, validated through extensive FM-Arena testing, follows this pattern:

- **Natural**: 100% effectiveness (no penalty)
- **Accomplished**: ~90% effectiveness
- **Competent**: ~85% effectiveness  
- **Unconvincing**: ~80% effectiveness
- **Awkward**: ~65% effectiveness
- **Ineffectual**: ~60% effectiveness

These penalties apply independently to whichever position the player occupies at any given moment during the match.

## Star ratings use averaging, but the "Both" view reveals the full picture

The Combined view in FM26's tactics screen displays an **averaged star rating** between IP and OOP suitability. According to Passion4FM's analysis: "The star ratings of players' abilities within the Combined view for the position and role will be the average of their star ratings for their ability to play in a position or role for in or out of possession formation."

This means a player rated 5 stars for their IP role but only 2 stars for their OOP role would display approximately **3.5 stars** in the Combined view—potentially obscuring significant phase-specific weaknesses. The "Both" view provides separate ratings side-by-side, offering managers accurate assessment of dual-phase suitability.

The green/yellow/orange/red position familiarity indicators follow the same logic: the IP view shows familiarity only for the attacking formation position, the OOP view shows familiarity only for the defensive position, and the Combined view displays an intermediate result based on averaging.

## Defensive OOP positions punish unfamiliarity more severely than attacking ones

Jack Joyce provided crucial clarification on contextual penalties: **"If they're only playing as a striker OOP, they don't have to be natural to be considered good there. Obviously having a natural player there is always best, but your midfielder won't be hampered too much either."** He continued: "The star ratings factor in the position as context, so not being natural at ST OOP is less of a problem than not being natural at CB OOP."

This reveals an asymmetric weighting system. Playing a midfielder as a forward during out-of-possession phases (where they might press high or provide an outlet) carries minimal penalties because the position's defensive responsibilities are limited. Conversely, using that same midfielder as a makeshift centre-back OOP would severely impact defensive phase performance because positional understanding matters critically when protecting your goal.

The practical implication: inverted formations where attackers track back into deep defensive positions create significantly more risk than formations where defenders push into midfield or attacking positions during buildup.

## Community testing quantifies the performance impact

FM-Arena user Harvestgreen22 conducted controlled testing using FM26's preset formations. The experiment used a 4-2-4 IP / 4-4-2 OOP setup where wingers needed to transition into wide midfield positions during defensive phases. By reducing the affected players' Wide Midfielder position proficiency from 20 to 5, the test measured:

- **13-point drop in goal difference** across the testing sample
- **6% decrease in winning rate**

This empirical result demonstrates that position proficiency for OOP positions materially affects match outcomes. The testing also established an approximate equivalence: **1 point of position proficiency ≈ 1 point of Pace** in performance impact, suggesting positional familiarity carries weight comparable to elite physical attributes.

Additional FM-Arena analysis confirmed that physical attributes (Acceleration, Pace, Agility) remain the dominant performance factors in FM26's match engine, with a 1% increase in Acceleration improving player effectiveness by approximately 2.1%. This means that exceptional physical attributes can partially compensate for positional unfamiliarity—a natural athlete playing out of position may still outperform a positionally familiar but slow player.

## Attributes interact with positional competency through separate role evaluations

FM26 calculates attribute suitability independently for each phase. In Possession roles emphasize creative and technical attributes (Vision, Passing, First Touch, Technique, Decisions), while Out of Possession roles weight defensive and pressing attributes (Tackling, Positioning, Work Rate, Stamina, Aggression) more heavily.

A player with excellent creative attributes but poor defensive ones would show a high star rating for their IP role but a lower rating for their OOP role. The match engine then applies the relevant attribute weightings during each phase—your creative playmaker will excel at ball progression but may struggle when tracking runners during defensive transitions.

FM-Arena's comprehensive attribute testing revealed that role suitability ratings and position familiarity ratings serve different functions: **"The role rating and the position rating are different things and should not be mixed. The role rating is a quite irrelevant thing and can be safely ignored."** Position familiarity has greater impact on actual match performance than role star ratings suggest, making the green/yellow/red position circles more predictive than the star count.

## Training can improve OOP familiarity, but with limitations

Sports Interactive confirmed that players can train to improve positional familiarity for OOP positions, gradually shifting from yellow (Competent) toward green (Natural) through focused development. Joyce noted: "You can train them to play that role OOP and they'll gain familiarity."

However, community members have identified a bug or design limitation: **"There is currently no option to train a player's out of possession position the way you can with In Possession."** When setting Position/Role training, only IP roles appear available; OOP training offers only generalized positional groups rather than specific roles. This means direct targeting of OOP positional improvement may require also training the equivalent IP position.

The hidden "Versatility" attribute, detailed by Sortitoutsi, affects how quickly players adapt to unfamiliar positions. High versatility players will gain positional familiarity faster through training and match experience in new positions.

## Practical implications for tactical design

The research suggests several evidence-based approaches to FM26 tactical construction:

**Minimize position distance between phases.** Passion4FM warns: "The further a player must travel between the 'In Possession' phase and 'Out of Possession' phase, the more unbalanced your structure will become." A wing-back transitioning to winger represents less risk than a striker dropping to centre-back.

**Prioritize defensive OOP familiarity.** Given the asymmetric penalty system, ensure any player with defensive OOP responsibilities (centre-backs, defensive midfielders, wing-backs) has strong positional familiarity. Attacking OOP positions like pressing forwards or wide outlets can tolerate lower familiarity ratings.

**Use the "Both" view for recruitment.** Rather than relying on Combined ratings that average out phase-specific weaknesses, evaluate IP and OOP star ratings separately to identify players who excel in both contexts versus those hiding significant gaps.

**Consider identical IP/OOP formations.** Prominent tactic tester Steelwood hypothesized: "Systems that play the same formation both in and out of possession will be most effective because position proficiency matters less." This approach eliminates positional transition penalties entirely, though it sacrifices tactical flexibility.

## What remains unknown about FM26's calculations

Despite extensive official documentation and community testing, several mechanics lack confirmation:

Sports Interactive has not revealed exact mathematical formulas for how IP and OOP performance combine into overall match ratings. Whether the engine weights possession phases equally (50/50) or adjusts based on actual possession percentage remains unconfirmed. The precise attribute weightings per role, transition timing between phases, and how star ratings translate to specific match performance modifiers are undocumented.

Major content creators like Zealand and WorkTheSpace have not yet published dedicated analysis comparing matched versus mismatched IP/OOP positional setups. The FM-Arena tactic testing server is still being configured for FM26's new UI, limiting large-scale automated testing. As the community's understanding deepens through continued testing, more precise guidance on optimal IP/OOP configurations will likely emerge.

## Conclusion

FM26's IP/OOP system represents a genuine mechanical evolution rather than cosmetic change. The match engine calculates player effectiveness separately for each possession phase, applying independent positional familiarity penalties and attribute weightings. Star ratings average across phases in the Combined view but can be viewed separately for accurate assessment. Defensive OOP positions punish unfamiliarity more severely than attacking ones, and community testing demonstrates measurable competitive disadvantage when players lack proficiency in their OOP positions. While exact formulas remain proprietary, the fundamental principle is clear: building effective FM26 tactics requires considering player suitability for both phases independently rather than relying on averaged representations.