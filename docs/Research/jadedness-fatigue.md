<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

## Jadedness/Fatigue in Football Manager 2026

Jadedness (now referred to as **fatigue** in FM26) is a hidden long-term fitness attribute that represents how "burnt out" a player is from accumulated match and training loads. While it has been renamed, the underlying mechanics remain consistent with previous editions of Football Manager.[^1][^2]

### How Fatigue Works

Fatigue operates as a hidden numerical value that accumulates over time through matches and training. Unlike condition (the visible heart icon showing match-to-match fitness) and match sharpness, fatigue builds up gradually and requires more intentional management to reduce.[^3][^1]

**Fatigue increases when:**

- Players participate in matches
- Players engage in training, especially with higher workload intensity[^1]
- Tactical instructions demand high physical output (gegenpressing, high tempo, etc.)[^4][^5]

**Fatigue decreases when:**

- Players are rested from training
- Players are not selected for matches
- Players are sent on extended leave/vacation[^3][^1]

Young developing players and older players past their physical peak become jaded more easily than players in their prime years.[^1]

### The Fatigue Scale and Negative Values

Based on extensive community testing, fatigue operates on a scale that **ranges from negative values to approximately 600-1000**. The in-game editor specifies a range of 0-1000, but the actual game mechanics allow for negative values.[^6][^7][^8]

**Negative fatigue values** represent players who are **under-conditioned** or lacking match fitness, not necessarily well-rested. When players return from extended breaks, injuries, or the off-season without training, they can have negative fatigue values. In testing, researchers set player fatigue to -500 as a baseline to observe fatigue gain mechanics.[^7][^8][^6]

The fatigue system essentially works like this:

- **Negative values (-500 to 0)**: Under-conditioned, lacking match sharpness
- **0 to ~350**: Fresh/Low fatigue - optimal performance range
- **400-500**: Critical threshold where "becoming fatigued" warning appears[^6]
- **500-600+**: High fatigue, significantly impaired performance

This explains why you might see negative values in the in-game editor despite the stated 0-1000 range - the game uses an extended scale to track both under-conditioning and over-training.[^8][^6]

### Impact on Performance and Abilities

Fatigue significantly affects player performance in multiple ways:

**Performance Degradation:**
When fatigue reaches the 400-500 threshold, testing shows win rates decrease substantially. Teams with 400 fatigue won 38% of matches, but this dropped to 33% when fatigue reached 500. Performance continues declining as fatigue increases beyond this point.[^6]

**Injury Risk:**
Light injuries increased from 107 per 1,000 matches at 400 fatigue to 130 per 1,000 at 500 fatigue - a statistically significant increase. Both light injuries (that can be played through) and heavy injuries (requiring immediate substitution) increase as fatigue rises past 400.[^6]

**Condition Recovery:**
Fatigued players experience slower condition (OPC) recovery between matches. Their condition drops more quickly during matches and takes longer to restore afterward. This creates a compounding effect where fatigued players become even more vulnerable.[^1]

**Attribute Performance:**
While fatigue doesn't directly lower visible attributes, it reduces how effectively players can utilize their skills. A jaded player with high technical attributes will underperform compared to their fresh state.[^2][^1]

### The 400 Fatigue Threshold

**400 fatigue is the critical threshold** where multiple warning systems activate:[^6]

1. Your sports scientist's feedback changes from "Low" to "Becoming Fatigued"[^6]
2. A rest icon appears next to the player's name
3. Your assistant manager sends warnings about resting the player[^6]

Testing demonstrates that somewhere between 400-500 is where fatigue begins having detrimental effects on both performance and injury risk. The 400 mark is particularly useful because it provides a clear visual indicator through the sports scientist feedback.[^6]

### Vacation Impact and Recovery

Sending players on vacation is the **most effective method** for reducing fatigue, but it must be combined with proper training schedules.[^9][^7]

**Vacation Recovery Rates:**

When using rest sessions in the training schedule AND sending players on vacation for 3 days:

- Fatigue recovered by **152.4 points** - the largest recovery of all tested methods[^7]

When using overall training sessions with vacation:

- Fatigue recovered by approximately 69 points[^7]

**For comparison, other recovery methods over 3 days:**

- Rest sessions + manual rest (no vacation): 137 points[^7]
- Rest sessions only: 101 points[^7]
- Recovery sessions: 48-51 points[^7]
- Overall training + manual rest: 57 points[^7]

The optimal "super rest" strategy combines:

1. Emptying the training schedule (filling it with rest sessions)
2. Manually resting the player
3. Sending them on vacation[^10][^7]

**Important note:** There's a known bug where players on vacation are still treated as training, preventing full recovery. This explains why some players need multiple vacations - they don't receive the expected rest benefits. Using the manual rest option may be more reliable than vacation in some cases.[^3]

### When to Send Players on Vacation

You should consider sending players on vacation when:

- Fatigue reaches **400 or higher** (when "becoming fatigued" appears)[^6]
- Players show the "jaded and could do with a rest" notification
- Players have sustained high match loads without adequate rest periods

**Typical vacation duration:** 1-3 weeks depending on severity[^11][^12][^9][^3]

However, many experienced managers recommend **preventative measures** rather than reactive vacations:

- Send first-team starters on 1-week vacations twice per season during low-priority matches[^3]
- If a player returns from summer vacation fully fit, immediately send them on a 3-week vacation to prevent season-long issues[^3]


### Other Methods to Lower Fatigue

Beyond vacation, several strategies reduce fatigue accumulation:

**Training Management:**

- Use **rest sessions** rather than recovery sessions - rest sessions recover approximately twice as much fatigue (101 vs 48-51 points over 3 days)[^7]
- Lower training intensity settings, especially during congested fixture periods[^13]
- Implement "super rest" by right-clicking players and manually resting them for 1-3 days between matches[^10][^3]
- Schedule 3 rest sessions on non-match days when there's no travel[^3]

**Tactical Adjustments:**

- Reduce tactical intensity (avoid gegenpressing/very high tempo tactics if squad fitness is poor)[^5][^4][^13]
- Switch to a lower-intensity backup tactic when winning comfortably (after 70th minute)[^13]
- Play counter-attacking or possession-based styles that require less constant pressing[^11]

**Squad Rotation:**

- Maintain 2 quality players per position to enable rotation[^14][^3]
- Rest high-fatigue players completely rather than using them as substitutes
- Monitor Natural Fitness attribute - players with low Natural Fitness become jaded more easily[^15][^1]

**Match Management:**

- Substitute heavily-used players early when winning[^14]
- Use substitute appearances for fringe players to maintain their sharpness without building fatigue


### Impact on Training

Fatigue creates a negative feedback loop with training:

**Higher fatigue means:**

- Training needs to be reduced in intensity to prevent further accumulation[^13][^3]
- Players recover condition more slowly, requiring more rest days[^1]
- Training quality may decrease due to workload concerns[^16]

**Strategic training during high fatigue periods:**

- Lower overall training intensity by one level across all categories[^13]
- Increase rest sessions in the schedule
- Prioritize recovery over development during congested fixture periods[^16]
- Use "no pitch or gym work" intensity setting for heavily fatigued players[^17]

The key insight is that **fatigue doesn't directly prevent training**, but it forces you to reduce training loads significantly, which can impact player development. This is particularly problematic for young players whose development requires consistent training.[^18][^16]

**Testing also reveals** that fatigue levels don't affect match sharpness loss rates. Players lose match sharpness at the same rate regardless of fatigue, though Natural Fitness does affect this. This means you must balance both fatigue management and match sharpness maintenance simultaneously.[^19]

The fatigue system in FM26 rewards proactive rotation, intelligent training management, and strategic use of rest periods. Players who monitor the 400 fatigue threshold and implement preventative rest will maintain better performance and reduce injury risk compared to reactive management that waits until players are severely jaded.[^14][^3][^6]
<span style="display:none">[^100][^101][^102][^103][^104][^105][^106][^107][^108][^109][^110][^111][^112][^113][^114][^115][^116][^117][^20][^21][^22][^23][^24][^25][^26][^27][^28][^29][^30][^31][^32][^33][^34][^35][^36][^37][^38][^39][^40][^41][^42][^43][^44][^45][^46][^47][^48][^49][^50][^51][^52][^53][^54][^55][^56][^57][^58][^59][^60][^61][^62][^63][^64][^65][^66][^67][^68][^69][^70][^71][^72][^73][^74][^75][^76][^77][^78][^79][^80][^81][^82][^83][^84][^85][^86][^87][^88][^89][^90][^91][^92][^93][^94][^95][^96][^97][^98][^99]</span>

<div align="center">⁂</div>

[^1]: https://www.guidetofm.com/squad/fitness/

[^2]: https://www.youtube.com/watch?v=J3PVrowqqu4

[^3]: https://www.reddit.com/r/footballmanagergames/comments/1cjnb46/jaded_and_could_do_with_a_rest/

[^4]: https://steamcommunity.com/app/2252570/discussions/0/4029095281637786919/

[^5]: https://loadfm.wordpress.com/2023/08/14/tips-to-reduce-player-fatigue-in-football-manager/

[^6]: https://www.youtube.com/watch?v=MProPfmJZ8o

[^7]: https://www.youtube.com/watch?v=ujD4ol7Qviw

[^8]: https://fmmvibe.com/forums/topic/17511-how-to-prevent-a-player-becoming-jaded/

[^9]: https://www.youtube.com/watch?v=6ASXosza1w4

[^10]: https://fm-arena.com/thread/12971-training-and-resting/page-2/

[^11]: https://www.reddit.com/r/footballmanagergames/comments/kw6od9/new_to_football_manager_why_are_my_players_always/

[^12]: https://community.sports-interactive.com/forums/topic/561825-players-getting-jaded-too-quickly-after-the-patch/

[^13]: https://www.youtube.com/watch?v=mgOvUK7Ywlc

[^14]: https://www.reddit.com/r/footballmanagergames/comments/18lcjk0/25000hrs_played_of_fm_here_are_my_best_tips/

[^15]: https://community.sports-interactive.com/forums/topic/580758-what-controls-tiredness-in-game/

[^16]: https://www.fmscout.com/a-fm26-training-guide-and-schedules-by-jonasmorais.html

[^17]: https://www.youtube.com/watch?v=73_xvVPGALs

[^18]: https://www.passion4fm.com/football-manager-youth-development-guide/

[^19]: https://www.youtube.com/watch?v=C6Rv2S7WbVA

[^20]: https://www.reddit.com/r/footballmanagergames/comments/18mv2zq/why_fatigue_matters_opc_you_know_me/

[^21]: https://www.reddit.com/r/footballmanagergames/comments/1nt084c/football_manager_26_couldnt_come_faster_im_tired/

[^22]: https://www.tiktok.com/@joshpeach_/video/7566323970782334230

[^23]: https://www.reddit.com/r/footballmanagergames/comments/1ojwdku/is_tiredness_basically_not_a_thing_this_year/

[^24]: https://community.sports-interactive.com/forums/topic/86824-jadedness/

[^25]: https://www.footballmanagerblog.org/2024/09/football-manager-reduce-player-fatigue-tips.html

[^26]: https://steamcommunity.com/app/3551340/discussions/0/670600486987227504/

[^27]: https://fm-base.co.uk/threads/condition-jadedness.151981/

[^28]: https://www.youtube.com/watch?v=vj0sCrB5xOg

[^29]: https://www.footballmanager.com/the-dugout/first-10-things-do-fm26

[^30]: https://fm-base.co.uk/threads/help-understanding-fatigue.159604/

[^31]: https://www.operationsports.com/football-manager-26s-in-game-editor-is-currently-broken-adding-fuel-to-the-fire/

[^32]: https://www.reddit.com/r/footballmanagergames/comments/1ohvmv7/fm26_does_going_on_a_vacation_and_returning_on/

[^33]: https://www.youtube.com/watch?v=spif8I2Xq48

[^34]: https://www.youtube.com/watch?v=XDkhpzdsGXU

[^35]: https://www.youtube.com/watch?v=YuQmvBWXYWM

[^36]: https://www.reddit.com/r/footballmanagergames/comments/13rmauk/new_to_the_game_rest_vs_recovery/

[^37]: https://community.sports-interactive.com/forums/topic/591122-need-to-micro-manage-every-day-rest-to-avoid-injuries/

[^38]: https://steamcommunity.com/app/3551340/discussions/0/845114412531637903/?ctp=3

[^39]: https://www.facebook.com/groups/fmscout/posts/1735404800681346/

[^40]: https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/1890_pre-game-in-game-editors/in-game-editor/remove-injuries-no-longer-removes-fatigue-match-fitness-of-players-r40569/

[^41]: https://www.youtube.com/watch?v=EQbc-tFPufc

[^42]: https://www.youtube.com/watch?v=l9dQfzL5zbA

[^43]: https://www.reddit.com/r/footballmanagergames/comments/1oocs4b/fm26_is_now_sitting_at_mostly_negative_on_steam/

[^44]: https://www.youtube.com/watch?v=XiR35kH468w

[^45]: https://fm-arena.com/thread/15933-i-tested-the-attributes-of-fm26-and-some-other-things/page-2/

[^46]: https://www.footballmanagerblog.org/2024/09/football-manager-physical-attributes-guide.html

[^47]: https://www.youtube.com/watch?v=8-ZReM0EyvE

[^48]: https://www.reddit.com/r/footballmanagergames/comments/1ovek8q/i_feel_like_i_am_going_crazy_regarding_seeing/

[^49]: https://community.sports-interactive.com/forums/topic/574563-managing-fatigue/

[^50]: https://sortitoutsi.net/content/75078/fm26-important-attributes-for-every-role

[^51]: https://steamcommunity.com/app/3551340/discussions/0/845114412531637903/

[^52]: https://www.youtube.com/watch?v=noymFV9NRMs

[^53]: https://community.sports-interactive.com/forums/topic/595586-fm26-fm26-player-attribute-color-editor/

[^54]: https://www.footballmanager.com/guides/dispelling-10-common-football-manager-misconceptions

[^55]: https://www.facebook.com/afcwimbledon/posts/heres-a-glance-at-some-of-our-player-attributes-on-football-manager-26-let-us-kn/1397472175721891/

[^56]: https://www.facebook.com/groups/fmscout/posts/1810611246494034/

[^57]: https://www.youtube.com/watch?v=mvDP9YClucU

[^58]: https://simplifaster.com/articles/athlete-fatigue-management-advantages/

[^59]: https://uefaacademy.com/wp-content/uploads/sites/2/2019/06/20140401_RGP_Sam-Marcora_The-Effects-of-Mental-Fatigue-on-Football-Players_Final-Report.pdf

[^60]: https://skybrary.aero/sites/default/files/bookshelf/3164.pdf

[^61]: https://www.reddit.com/r/footballmanagergames/comments/1evvs52/why_are_international_tournaments_so_broken/

[^62]: https://www.reddit.com/r/footballmanagergames/comments/12pimlq/im_new_to_the_game_and_have_a_very_dumb_question/

[^63]: https://community.sports-interactive.com/forums/topic/468555-can’t-reach-100-fitness/

[^64]: https://www.facebook.com/groups/fmscout/posts/1571220410433120/

[^65]: https://www.reddit.com/r/footballmanagergames/comments/1c3rbcc/struggling_to_understand_fatigue/

[^66]: https://community.sports-interactive.com/forums/topic/204403-im-tired-of-horrific-finishing/

[^67]: https://community.sports-interactive.com/bugtracker/previous-versions/football-manager-2023-bugs-tracker/757_medical-and-development-centre-training-and-finances/issue-with-fatigue-recovery-of-players-r15065/

[^68]: https://footballgamingzone.com/ea-sports-fc/how-to-earn-quick-easy-sp-in-ea-fc-26-over-3000-sp-in-30-minutes/

[^69]: https://www.fmscout.com/a-fm26-hardest-saves.html

[^70]: https://fmmvibe.com/forums/topic/26023-slightly-tired-player/

[^71]: https://community.sports-interactive.com/forums/topic/566605-when-to-rest-a-player-immediately-after-the-match/

[^72]: https://fm-arena.com/thread/7119-training-schedule-fm24-most-important-attributes/page-2/

[^73]: https://journal.aspetar.com/en/archive/volume-11-targeted-topic-sports-science-in-football/a-periodised-recovery-strategy-framework-for-the-elite-football-player

[^74]: https://www.reddit.com/r/footballmanagergames/comments/1jkymwt/so_apparently_i_picked_up_bad_habits_over_a/

[^75]: https://www.reddit.com/r/footballmanagergames/comments/179tctx/when_to_rest_players/

[^76]: https://www.youtube.com/shorts/9kfbukaY6HQ

[^77]: https://community.sports-interactive.com/forums/topic/369341-maintaining-match-sharpness/

[^78]: https://www.reddit.com/r/footballmanagergames/comments/1au40ze/training_fatigue_and_match_congestion/

[^79]: https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0213472

[^80]: https://vibrationresearch.com/resources/m-and-q-values-for-fds/

[^81]: https://www.trainingpeaks.com/learn/articles/applying-the-numbers-part-3-training-stress-balance/

[^82]: https://www.givemesport.com/football-manager-2024-in-game-editor-beginners-guide/

[^83]: https://www.gssiweb.org/sports-science-exchange/article/monitoring-recovery-in-american-football

[^84]: https://community.sports-interactive.com/bugtracker/previous-versions/football-manager-2024-early-access-bugs-tracker/finances-training-medical-and-development-centres/problems-managing-fatigue-r20194/

[^85]: https://pmc.ncbi.nlm.nih.gov/articles/PMC6244616/

[^86]: https://coachathletics.com.au/coaching-education/mental-fatigue

[^87]: https://opensportssciencesjournal.com/VOLUME/10/PAGE/52/

[^88]: https://matthogan.blog/fatigue-threshold-spectrum/

[^89]: https://support.playerdata.com/knowledge/what-are-the-high-intensity-metrics

[^90]: https://www.jtsstrength.com/fatigue-indicators-and-how-to-use-them/

[^91]: https://www.facebook.com/groups/fmscout/posts/1798145044407321/

[^92]: https://www.youtube.com/watch?v=UJyGgdRgD64

[^93]: https://www.neurotrackerx.com/post/top-5-tools-for-measuring-cognitive-fatigue-and-focus

[^94]: https://community.sports-interactive.com/forums/topic/586085-empty-heart-tiredness-during-matches/

[^95]: https://www.frontiersin.org/journals/sports-and-active-living/articles/10.3389/fspor.2025.1603767/full

[^96]: https://www.youtube.com/watch?v=H4Rijj4GzCs

[^97]: https://www.reddit.com/r/footballmanagergames/comments/1fytp5s/some_of_my_players_arent_recovering_fully_between/

[^98]: https://pmc.ncbi.nlm.nih.gov/articles/PMC3711242/

[^99]: https://www.youtube.com/watch?v=E8AODArCyrk

[^100]: https://community.sports-interactive.com/forums/topic/581072-player-fitness-condition-fm-is-unplayable/

[^101]: https://www.reddit.com/r/footballmanager/comments/157n1ng/tips_to_reduce_player_fatigue_in_football_manager/

[^102]: https://community.sports-interactive.com/forums/topic/458910-attribute-range-guide/

[^103]: https://www.footballmanager.com/guides/using-game-editor-fm21

[^104]: https://community.sports-interactive.com/forums/topic/572879-player-fatigue-is-a-joke/

[^105]: https://www.passion4fm.com/football-manager-player-attributes/

[^106]: https://www.reddit.com/r/footballmanagergames/comments/rvxuzz/any_tips_for_dealing_with_jadedness/

[^107]: https://community.sports-interactive.com/forums/topic/582018-condition-vs-fatigue-whats-the-difference/

[^108]: https://pmc.ncbi.nlm.nih.gov/articles/PMC3978642/

[^109]: https://www.sciencedirect.com/science/article/pii/S2666354621000697

[^110]: https://www.fmrte.com/forums/topic/6978-fitness-cheat/

[^111]: https://www.facebook.com/groups/fmscout/posts/1468282357393593/

[^112]: https://community.sports-interactive.com/forums/topic/549403-solving-the-problem-of-player-being-jaded/

[^113]: https://www.nytimes.com/athletic/3579638/2022/09/10/fixture-fatigue-what-experts-say/

[^114]: https://www.facebook.com/groups/fmscout/posts/1606731423548685/

[^115]: https://www.tiktok.com/@joshpeach_/video/7314334161777511712?lang=en

[^116]: https://community.sports-interactive.com/bugtracker/previous-versions/football-manager-2023-bugs-tracker/757_medical-and-development-centre-training-and-finances/players-playing-for-national-teams-whilst-on-holiday-to-be-restedrecover-from-jadedexhausted-state-r11380/

[^117]: https://blogs.usafootball.com/blog/1336/fatigue-does-not-equal-success-in-conditioning

