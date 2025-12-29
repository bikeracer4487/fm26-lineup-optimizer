# Football Manager 26 Companion App: Hungarian Algorithm Lineup Optimizer Specification

This specification provides complete, implementation-ready formulas for a 5-match horizon Starting XI recommender. Every formula is deterministic, bounded, and designed to integrate cleanly with the Hungarian assignment algorithm.

---

## Deliverable A: Multiplier family choice and formulas

**Decision: Smooth sigmoid-style multipliers using scaled logistic functions**

The sigmoid family is chosen over piecewise linear for three critical reasons: (1) **jitter resistance**—smooth gradients prevent oscillation when player states hover near thresholds, (2) **bounded output**—asymptotic behavior naturally constrains multipliers without explicit clamping, and (3) **differentiable sensitivity**—enables future gradient-based tuning and sensitivity analysis. Piecewise linear functions require hysteresis bands to prevent chattering, adding complexity without benefit for this use case.

### Core sigmoid building block

All multipliers use this parameterized sigmoid:

```
σ(x; k, x₀) = 1 / (1 + exp(-k × (x - x₀)))
```

Mapped to output range [L, H]:
```
multiplier(x) = L + (H - L) × σ(x; k, x₀)
```

### Φ(C, Ω) — Condition multiplier

Condition C ranges 0–100. Players below **70** suffer significant performance drops; above **90** is optimal.

```
Φ(C, Ω) = Φ_min(Ω) + (1.0 - Φ_min(Ω)) × σ(C; k_Φ(Ω), x₀_Φ(Ω))
```

| Importance Mode Ω | Φ_min | x₀_Φ | k_Φ | Interpretation |
|-------------------|-------|------|-----|----------------|
| High              | 0.60  | 75   | 0.12 | Harsh penalty below 75, demands peak condition |
| Medium            | 0.70  | 70   | 0.10 | Standard curve, tolerates slight fatigue |
| Low               | 0.80  | 65   | 0.08 | Lenient, rests stars in lesser matches |
| Sharpness         | 0.75  | 68   | 0.09 | Balanced, prioritizes match fitness building |

**Example outputs for Φ (Medium mode):**
| C | σ value | Φ(C, Medium) |
|---|---------|--------------|
| 72 | 0.550 | 0.865 |
| 82 | 0.769 | 0.931 |
| 90 | 0.881 | 0.964 |
| 97 | 0.937 | 0.981 |

### Ψ(Sh_pct, Ω) — Sharpness multiplier

Sharpness Sh_pct = Sh_store/100, ranging 0–100 as a percentage. Low sharpness degrades performance; Sharpness mode heavily weights this factor.

```
Ψ(Sh_pct, Ω) = Ψ_min(Ω) + (Ψ_max(Ω) - Ψ_min(Ω)) × σ(Sh_pct; k_Ψ(Ω), x₀_Ψ(Ω))
```

| Importance Mode Ω | Ψ_min | Ψ_max | x₀_Ψ | k_Ψ |
|-------------------|-------|-------|------|-----|
| High              | 0.85  | 1.00  | 50   | 0.08 |
| Medium            | 0.88  | 1.00  | 45   | 0.06 |
| Low               | 0.92  | 1.00  | 40   | 0.05 |
| Sharpness         | 0.70  | 1.05  | 55   | 0.10 |

The Sharpness mode uniquely allows Ψ_max > 1.0 to **bonus** high-sharpness players, encouraging rotation of rusty squad members into the lineup.

**Example outputs for Ψ (Medium mode):**
| Sh_pct | σ value | Ψ(Sh_pct, Medium) |
|--------|---------|-------------------|
| 10 | 0.110 | 0.893 |
| 40 | 0.426 | 0.931 |
| 70 | 0.817 | 0.978 |
| 95 | 0.967 | 0.996 |

### Θ(Fam, Ω) — Familiarity multiplier

Familiarity Fam ranges 1–20. Below **10** indicates unfamiliarity with the tactical system.

```
Θ(Fam, Ω) = Θ_min(Ω) + (1.0 - Θ_min(Ω)) × σ(Fam; k_Θ(Ω), x₀_Θ(Ω))
```

| Importance Mode Ω | Θ_min | x₀_Θ | k_Θ |
|-------------------|-------|------|-----|
| High              | 0.70  | 12   | 0.50 |
| Medium            | 0.80  | 10   | 0.40 |
| Low               | 0.88  | 8    | 0.30 |
| Sharpness         | 0.82  | 10   | 0.35 |

**Example outputs for Θ (Medium mode):**
| Fam | σ value | Θ(Fam, Medium) |
|-----|---------|----------------|
| 6 | 0.168 | 0.834 |
| 10 | 0.500 | 0.900 |
| 14 | 0.832 | 0.966 |
| 18 | 0.964 | 0.993 |

### Λ(F_internal, T_internal, Ω) — Fatigue multiplier

Fatigue uses the **internal scale** for computation (range -500 to 1000). The personal threshold T_internal (typically ~400) defines the player's fatigue tolerance.

The key insight: fatigue impact should be relative to the player's threshold. We define **excess fatigue** as:
```
Δ = F_internal - T_internal
```

When Δ < 0, the player is below their threshold (fresh). When Δ > 0, they're exceeding tolerance.

```
Λ(F_internal, T_internal, Ω) = Λ_min(Ω) + (1.0 - Λ_min(Ω)) × σ(-Δ; k_Λ(Ω), x₀_Λ(Ω))
```

Note the negation: higher Δ (more tired) → lower multiplier.

| Importance Mode Ω | Λ_min | x₀_Λ | k_Λ | Notes |
|-------------------|-------|------|-----|-------|
| High              | 0.50  | 100  | 0.008 | Steep drop when exceeding threshold |
| Medium            | 0.60  | 150  | 0.006 | Moderate tolerance for mild excess |
| Low               | 0.70  | 200  | 0.005 | Very tolerant, allows fatigued play |
| Sharpness         | 0.55  | 120  | 0.007 | Balanced approach |

**Example outputs for Λ (Medium mode, T_internal = 400):**
| F_internal | Δ = F - T | σ(-Δ) | Λ(F, T, Medium) |
|------------|-----------|-------|-----------------|
| 200 (T-200) | -200 | 0.890 | 0.956 |
| 350 (T-50) | -50 | 0.622 | 0.849 |
| 450 (T+50) | +50 | 0.378 | 0.751 |
| 650 (T+250) | +250 | 0.110 | 0.644 |

---

## Deliverable B: Fatigue internal scale and UI mapping

The internal fatigue scale F_internal ∈ [-500, 1000] must be mapped to a user-friendly UI value for display and band classification.

### Mapping function

The mapping is **threshold-relative**, centering the UI at the player's personal threshold:

```
FatigueUI(F_internal, T_internal) = 50 + (F_internal - T_internal) × 0.10
```

This produces:
- **F_internal = T_internal - 500** → FatigueUI = 0 (very fresh)
- **F_internal = T_internal** → FatigueUI = 50 (at threshold)
- **F_internal = T_internal + 500** → FatigueUI = 100 (extreme fatigue)
- **F_internal = T_internal + 700** → FatigueUI = 120 (danger zone)

The UI is clamped to [0, 130] for display purposes.

### Band boundaries

| UI Range | Band Color | Status Label | Description |
|----------|------------|--------------|-------------|
| 0–40 | Green | Fresh | Well below threshold, optimal performance |
| 41–65 | Yellow | Moderate | Near threshold, manageable fatigue |
| 66–85 | Orange | Tired | Exceeding threshold, reduced performance |
| 86–100 | Red | Exhausted | Significantly over threshold, rest needed |
| 101+ | Dark Red | Critical | Injury risk, mandatory rest |

**Warning threshold: UI ≥ 80** (triggers caution icon)
**Danger threshold: UI ≥ 100** (triggers rest recommendation)

### Example mappings (T_internal = 400)

| F_internal | Δ = F - T | FatigueUI | Band |
|------------|-----------|-----------|------|
| 200 (T-200) | -200 | 30 | Green |
| 350 (T-50) | -50 | 45 | Yellow |
| 450 (T+50) | +50 | 55 | Yellow |
| 650 (T+250) | +250 | 75 | Orange |

### How Λ references fatigue

**Λ uses the internal scale directly**, not the UI value. This ensures:
1. Full numeric precision for optimization
2. Independence from display scaling changes
3. Threshold-relative computation within the multiplier formula

The UI mapping is purely for display and band classification—never for scoring.

---

## Deliverable C: Sign conventions and cost matrix correctness

### Convention: Hungarian minimizes Cost; we maximize Utility via transform

The standard Hungarian algorithm **minimizes total cost**. Since we want to maximize lineup quality (utility), we apply the subtraction transform:

```
Cost[p][s] = MAX_UTILITY - Utility[p][s]
```

Where MAX_UTILITY is a constant safely above any achievable utility (recommended: **250**).

### Utility formula for player p in slot s

```
Utility(p, s) = B(p, s) × Φ(C_p, Ω) × Ψ(Sh_p, Ω) × Θ(Fam_p, Ω) × Λ(F_p, T_p, Ω)
               + StabilityBonus(p, s)
               - ShadowCost(p, s)
```

**Base rating B(p, s)**: Harmonic mean of in-position (IP) and out-of-position (OOP) role ratings:
```
B(p, s) = 2 × IP × OOP / (IP + OOP)
```
For pure IP play where OOP = IP: B = IP. Range: 0–200.

### Cost matrix formula

```
Cost[p][s] = MAX_UTILITY - Utility(p, s)
```

For REST slots and forbidden assignments, see Deliverables D and E.

### Sign and magnitude guidance

| Component | Sign Convention | Typical Magnitude | Rationale |
|-----------|-----------------|-------------------|-----------|
| Base utility B | Positive (higher is better) | 80–180 | Elite players ~160+, squad players ~100–130 |
| Multipliers Φ, Ψ, Θ, Λ | Positive, range ~0.5–1.05 | Product ~0.4–1.0 | Multiplicative penalties/bonuses |
| StabilityBonus | **Positive** (added to utility) | +3 to +8 | Incentivizes keeping previous assignment |
| ShadowCost | **Positive** (subtracted from utility) | 0 to +15 | Opportunity cost of using polyvalent player |
| REST cost | Expressed as utility foregone | See Deliverable D | Player-specific |

### Numeric sanity check

**Typical starter utility calculation:**
- Base rating B = 140 (good first-team player)
- Condition Φ = 0.95 (C = 88)
- Sharpness Ψ = 0.97 (Sh = 65%)
- Familiarity Θ = 0.96 (Fam = 15)
- Fatigue Λ = 0.90 (moderately tired)
- **Utility before adjustments**: 140 × 0.95 × 0.97 × 0.96 × 0.90 = **111.5**
- Stability bonus: +5 (was in this slot last match)
- Shadow cost: -3 (could play elsewhere too)
- **Final utility: 113.5**
- **Cost: 250 - 113.5 = 136.5**

**Meaningful stability bonus**: Should be **3–8 points** in rating terms. This represents requiring ~3–5% improvement to justify a change. If a swap only saves 2 points but costs 5 in stability, the algorithm keeps the current assignment.

**Shadow cost range**: Typically **0–15 points**. Zero for specialists who only fit one slot. Higher for versatile players whose assignment to one slot "shadows out" other slots. A midfielder who could play 3 positions well might have shadow cost ~10.

---

## Deliverable D: REST slots that behave correctly

### Design philosophy

REST slots are **dummy positions** added to the cost matrix so the Hungarian algorithm can choose not to field a player. The REST "utility" represents the value of preserving player state versus the opportunity cost of not playing them.

### REST slot structure

For a squad of N players and 11 starting positions, add **(N - 11)** REST slots to make the matrix square. Each REST slot is independent—a player assigned to REST_1 vs REST_2 is semantically identical.

### REST utility formula

```
Utility_REST(p, Ω) = α(Ω) × AvgPositionalUtility(p)
                   + β(Ω) × FatigueRelief(p)
                   + γ(Ω) × SharpnessNeed(p)
                   + δ(Ω) × ConditionBonus(p)
```

Where:
- **AvgPositionalUtility(p)** = average of player's utility across their viable positions (sets baseline)
- **FatigueRelief(p)** = max(0, (F_p - T_p) / 50) capped at 20 (bonus for resting tired players)
- **SharpnessNeed(p)** = max(0, (70 - Sh_pct) / 5) capped at 10 (penalty if player needs minutes)
- **ConditionBonus(p)** = max(0, (85 - C_p) / 3) capped at 15 (bonus for resting low-condition players)

### Parameter table by importance mode

| Mode Ω | α | β | γ | δ | Effect |
|--------|---|---|---|---|--------|
| High | 0.35 | 2.0 | -3.0 | 1.5 | REST is unattractive; only extremely fatigued players rest |
| Medium | 0.45 | 2.5 | -2.0 | 2.0 | Balanced; moderate rotation acceptable |
| Low | 0.60 | 3.0 | -1.0 | 2.5 | REST is attractive; heavy rotation encouraged |
| Sharpness | 0.40 | 2.0 | -4.0 | 1.8 | Heavily penalizes resting low-sharpness players |

The **α coefficient** is the baseline REST attractiveness. At α = 0.35 (High importance), REST utility starts at only 35% of playing utility—stars will almost always start. At α = 0.60 (Low importance), REST starts at 60%, making rotation far more likely.

### Forced REST conditions

Some players **must** be assigned to REST. Set their utility for all playing slots to **-∞** (implemented as -1e9):

```
if (player.injured || player.banned) {
    for each slot s in playing_slots:
        Utility[p][s] = -INFINITY  // Forces REST assignment
    Utility[p][REST] = 0           // REST is the only viable option
}
```

### Failure-mode protections

**Problem 1: REST wins for everyone (all players rest)**
- Protection: α ≤ 0.6 ensures REST utility is always below playing utility for healthy players
- Sanity check: If > 3 healthy players assigned REST in High mode, flag configuration error

**Problem 2: REST wins for no one (never rotates)**
- Protection: FatigueRelief and ConditionBonus create strong REST incentives for exhausted players
- A player at F = T + 400 with C = 65 gets: +8 fatigue relief, +7 condition bonus ≈ +15 points toward REST

**Problem 3: Low-sharpness players trapped in REST**
- Protection: Negative γ coefficient penalizes REST for rusty players
- In Sharpness mode with γ = -4.0, a player at Sh = 30% gets: -4 × (70-30)/5 = -32 penalty to REST utility

### Worked example

Player: Squad midfielder, AvgPositionalUtility = 95, F = 550 (threshold 400), C = 72, Sh = 45%

**Medium mode REST utility:**
- Base: 0.45 × 95 = 42.75
- FatigueRelief: 2.5 × min(20, (550-400)/50) = 2.5 × 3 = 7.5
- SharpnessNeed: -2.0 × min(10, (70-45)/5) = -2.0 × 5 = -10
- ConditionBonus: 2.0 × min(15, (85-72)/3) = 2.0 × 4.3 = 8.6
- **Total REST utility: 48.85**

If this player's best starting utility is 85, they'll likely start (85 > 48.85). But a star with utility 130 but at F = 700, C = 65 might have REST utility ~65 vs playing utility ~75 after multiplier penalties—much closer, potentially triggering rotation.

---

## Deliverable E: Confirmed lineup and manual constraints integration

### Constraint definitions

**Confirmed slot (slot s has fixed player p):**
- Slot s will definitely be filled by player p
- No other player can occupy s; player p cannot be placed elsewhere
- Implemented by **problem reduction**: remove row p and column s from the matrix

**Manual lock (player p → slot s):**
- User requests player p starts in slot s specifically
- Equivalent to confirmed slot for optimization purposes
- Implemented identically via problem reduction

**Rejection (player p excluded from slot s):**
- Player p cannot be assigned to slot s (but may play elsewhere)
- Implemented by setting Cost[p][s] = FORBIDDEN (1e9)

**Full rejection (player p excluded entirely):**
- Player p cannot start in any position
- Force assignment to REST by setting Cost[p][s] = FORBIDDEN for all playing slots

### Pseudocode for building reduced optimization problem

```python
def build_reduced_problem(players, slots, fixed_assignments, rejections, full_rejections):
    # Step 1: Identify players and slots still in play
    fixed_players = set(fixed_assignments.keys())
    fixed_slots = set(fixed_assignments.values())
    
    remaining_players = [p for p in players if p not in fixed_players]
    remaining_slots = [s for s in slots if s not in fixed_slots]
    
    # Step 2: Filter out fully rejected players from starting consideration
    # They'll be forced to REST
    startable_players = [p for p in remaining_players if p not in full_rejections]
    rest_forced_players = [p for p in remaining_players if p in full_rejections]
    
    # Step 3: Build reduced cost matrix
    n_players = len(startable_players)
    n_slots = len(remaining_slots)
    n_rest = max(0, n_players - n_slots)  # REST slots needed
    
    matrix_size = max(n_players, n_slots + n_rest)
    cost_matrix = np.zeros((matrix_size, matrix_size))
    
    # Fill player-to-slot costs
    for i, player in enumerate(startable_players):
        for j, slot in enumerate(remaining_slots):
            if (player, slot) in rejections:
                cost_matrix[i][j] = FORBIDDEN  # 1e9
            else:
                cost_matrix[i][j] = MAX_UTILITY - compute_utility(player, slot)
        
        # Add REST slot costs
        for r in range(n_rest):
            cost_matrix[i][n_slots + r] = MAX_UTILITY - compute_rest_utility(player)
    
    # Step 4: Solve reduced problem
    row_ind, col_ind = hungarian(cost_matrix)
    
    # Step 5: Check feasibility
    total_forbidden = sum(1 for i, j in zip(row_ind, col_ind) 
                          if cost_matrix[i][j] >= FORBIDDEN)
    if total_forbidden > 0:
        return InfeasibleResult(conflicts=identify_conflicts(row_ind, col_ind, cost_matrix))
    
    # Step 6: Merge with fixed assignments
    full_solution = dict(fixed_assignments)  # Start with fixed
    for i, j in zip(row_ind, col_ind):
        if i < len(startable_players):
            player = startable_players[i]
            if j < len(remaining_slots):
                full_solution[player] = remaining_slots[j]
            else:
                full_solution[player] = 'REST'
    
    # Add forced REST players
    for player in rest_forced_players:
        full_solution[player] = 'REST'
    
    return full_solution
```

### Infeasibility fallback behavior

Infeasibility occurs when the constraint combination makes no valid assignment possible. Detection and handling:

```python
def handle_infeasibility(infeasible_result, original_constraints):
    conflicts = infeasible_result.conflicts
    
    # Priority-ordered constraint relaxation
    relaxation_order = [
        'rejections',        # First: relax specific slot rejections
        'full_rejections',   # Second: allow excluded players back
        'fixed_assignments'  # Last resort: relax user locks
    ]
    
    for constraint_type in relaxation_order:
        if can_relax(constraint_type, conflicts):
            relaxed = relax_least_important(constraint_type, conflicts)
            new_result = build_reduced_problem(..., relaxed_constraints)
            if new_result.is_feasible:
                return FallbackResult(
                    solution=new_result,
                    warning=f"Relaxed {constraint_type}: {relaxed}",
                    original_constraint_violated=relaxed
                )
    
    # Complete failure: cannot satisfy any reasonable constraint set
    return FatalError("No feasible lineup exists with current squad")
```

### Applying INF costs safely

**FORBIDDEN constant**: Use **1e9** (one billion), not actual infinity.

**Safety constraints:**
- Maximum realistic utility ≈ 200
- MAX_UTILITY = 250
- Maximum legitimate cost = 250 (when utility = 0)
- Matrix size ≤ 50 players
- Maximum sum of legitimate costs = 50 × 250 = 12,500
- FORBIDDEN = 1e9 >> 12,500 ✓

**Detection after solving:**
```python
def verify_solution(cost_matrix, row_ind, col_ind):
    FORBIDDEN_THRESHOLD = 1e8  # Anything above this is forbidden
    
    violations = []
    for i, j in zip(row_ind, col_ind):
        if cost_matrix[i][j] > FORBIDDEN_THRESHOLD:
            violations.append((i, j, "Forbidden assignment used"))
    
    return len(violations) == 0, violations
```

---

## Deliverable F: Minutes allocation consistent with state propagation

### Deterministic minutes model

Minutes allocation requires no match simulation—it's a pre-match **plan** used for state propagation.

### Starter minutes by role and state

```python
def allocate_starter_minutes(player, importance_mode, match_context):
    base_minutes = STARTER_BASE[importance_mode]  # See table below
    
    # Fatigue protection: reduce if significantly over threshold
    fatigue_excess = player.F_internal - player.T_internal
    if fatigue_excess > 200:
        base_minutes = min(base_minutes, 75)
    elif fatigue_excess > 350:
        base_minutes = min(base_minutes, 60)
    
    # Condition protection: early sub if low condition
    if player.condition < 75:
        base_minutes = min(base_minutes, 70)
    elif player.condition < 85:
        base_minutes = min(base_minutes, 80)
    
    return base_minutes
```

| Importance Mode | Base Starter Minutes | Interpretation |
|-----------------|---------------------|----------------|
| High | 90 | Full match expected |
| Medium | 85 | Likely some rotation/subs |
| Low | 75 | Heavy rotation expected |
| Sharpness | 80 | Balanced for fitness building |

### Substitute selection and minutes

Substitutes are selected from REST-assigned players, prioritized by:
1. Sharpness need (lower sharpness → higher priority for minutes)
2. Fatigue availability (lower fatigue → more available)
3. Quality (higher base rating)

```python
def select_substitutes(rest_assigned_players, num_subs=3):
    # Score each REST player for sub priority
    scored = []
    for player in rest_assigned_players:
        if player.injured or player.banned:
            continue  # Cannot sub in
        
        priority_score = (
            (100 - player.sharpness_pct) * 0.4 +  # Need minutes
            (100 - player.condition) * 0.2 +       # Not too tired to help
            player.avg_rating * 0.4                # Quality
        )
        scored.append((player, priority_score))
    
    scored.sort(key=lambda x: -x[1])  # Descending
    return [p for p, _ in scored[:num_subs]]
```

### Substitute minutes allocation

| Sub Position | Entry Time | Minutes Played | Notes |
|--------------|------------|----------------|-------|
| Sub 1 (first sub) | 60' | 30 | Tactical/impact sub |
| Sub 2 (second sub) | 70' | 20 | Fresh legs |
| Sub 3 (third sub) | 80' | 10 | Late protection |

Adjust by importance mode:

| Mode | Sub 1 Minutes | Sub 2 Minutes | Sub 3 Minutes |
|------|---------------|---------------|---------------|
| High | 25 | 15 | 5 |
| Medium | 30 | 20 | 10 |
| Low | 35 | 25 | 15 |
| Sharpness | 35 | 30 | 20 |

### Worked example: 14-player squad

**Squad composition:**
- GK1 (C=92, F=200, Sh=80), GK2 (C=95, F=150, Sh=40)
- DF1 (C=88, F=380, Sh=75), DF2 (C=85, F=420, Sh=70), DF3 (C=78, F=550, Sh=65), DF4 (C=90, F=300, Sh=50)
- MF1 (C=90, F=350, Sh=85), MF2 (C=82, F=480, Sh=60), MF3 (C=95, F=200, Sh=30), MF4 (C=86, F=400, Sh=72)
- FW1 (C=91, F=320, Sh=88), FW2 (C=77, F=600, Sh=55), FW3 (C=89, F=280, Sh=45), FW4 (C=94, F=180, Sh=35)

**Medium importance match, threshold T=400 for all:**

**Starting XI assignment:**
- GK: GK1 (high sharpness, good condition)
- DEF: DF1, DF2, DF4 (DF3 rested due to F=550 > T+150)
- MID: MF1, MF4, MF3 (getting sharpness despite low Sh=30)
- FWD: FW1, FW3 (FW2 rested due to F=600, low condition)

**REST assigned:** GK2, DF3, MF2, FW2, FW4

**Starter minutes (Medium mode, base=85):**
| Player | Base | Fatigue Adj | Condition Adj | Final Minutes |
|--------|------|-------------|---------------|---------------|
| GK1 | 85 | — | — | 85 |
| DF1 | 85 | — | — | 85 |
| DF2 | 85 | -10 (F=420>T) | — | 75 |
| DF4 | 85 | — | — | 85 |
| MF1 | 85 | — | — | 85 |
| MF4 | 85 | — | — | 85 |
| MF3 | 85 | — | — | 85 |
| FW1 | 85 | — | — | 85 |
| FW3 | 85 | — | — | 85 |

**Substitute selection (from REST):**
Priority scoring:
- GK2: (100-40)×0.4 + (100-95)×0.2 + 70×0.4 = 24 + 1 + 28 = 53 (GK, can't outfield sub)
- DF3: (100-65)×0.4 + (100-78)×0.2 + 85×0.4 = 14 + 4.4 + 34 = 52.4
- MF2: (100-60)×0.4 + (100-82)×0.2 + 90×0.4 = 16 + 3.6 + 36 = 55.6
- FW2: (100-55)×0.4 + (100-77)×0.2 + 88×0.4 = 18 + 4.6 + 35.2 = 57.8
- FW4: (100-35)×0.4 + (100-94)×0.2 + 82×0.4 = 26 + 1.2 + 32.8 = 60

**Selected subs:** FW4 (60), FW2 (57.8), MF2 (55.6)

**Final minutes allocation:**
| Player | Role | Minutes |
|--------|------|---------|
| GK1 | Starter | 85 |
| DF1, DF4, MF1, MF4, MF3, FW1, FW3 | Starter | 85 each |
| DF2 | Starter (fatigued) | 75 |
| FW4 | Sub 1 | 30 |
| FW2 | Sub 2 | 20 |
| MF2 | Sub 3 | 10 |
| GK2, DF3 | Unused | 0 |

---

## Deliverable G: State propagation equations

### Core update equations

State propagation predicts player state after a match and recovery period, enabling multi-match horizon optimization.

**Input:** Current state, planned minutes, days to next match
**Output:** Predicted state for next match

### Condition update

```
C_new = clamp(C_old - ConditionDrop(minutes) + ConditionRecovery(days, NF), 40, 100)

ConditionDrop(m) = m × 0.25 × (1.1 - Stamina/200)
ConditionRecovery(d, NF) = d × (3 + NF/10)
```

**Parameters:**
- Base condition drop: **0.25 per minute** played
- Stamina modifier: Players with Stamina=20 drop at 1.0×, Stamina=10 at 1.05×
- Base recovery: **3 points per day** rest
- Natural Fitness (NF) bonus: NF/10 additional points per day (NF=15 → +1.5/day)
- **Bounds:** Condition clamped to [40, 100]

**Fallback if Stamina/NF unavailable:** Use Stamina=12, NF=12 (average values)

### Sharpness update

```
Sh_new = clamp(Sh_old × DecayFactor(days) + SharpnessGain(minutes, NF), 1000, 10000)

DecayFactor(d) = exp(-0.02 × d)
SharpnessGain(m, NF) = m × (3 + NF/15) × (1 + WorkRate/40)
```

**Parameters:**
- Decay rate: **2% per day** without match (half-life ≈ 35 days)
- Base gain: **3 Sh_store per minute** played
- Natural Fitness bonus: NF/15 additional per minute
- Work Rate bonus: Up to +50% gain for high work rate players
- **Bounds:** Sh_store clamped to [1000, 10000] (Sh_pct: 10–100%)

**Fallback if WorkRate unavailable:** Use WorkRate=12

### Fatigue (internal scale) update

```
F_new = clamp(F_old + FatigueAccrual(minutes) - FatigueRecovery(days, NF), -500, 1000)

FatigueAccrual(m) = m × 4 × (1.2 - Stamina/100)
FatigueRecovery(d, NF) = d × (40 + NF × 2)
```

**Parameters:**
- Base accrual: **4 F_internal per minute** played
- Stamina modifier: High stamina reduces accrual (Stamina=20 → ×1.0, Stamina=10 → ×1.1)
- Base recovery: **40 F_internal per day**
- Natural Fitness bonus: **2 × NF** additional per day (NF=15 → +30/day = 70 total/day)
- **Bounds:** F_internal clamped to [-500, 1000]

### Default parameter values

| Parameter | Default Value | Source |
|-----------|---------------|--------|
| Stamina | 12 | Average attribute |
| Natural Fitness (NF) | 12 | Average attribute |
| Work Rate | 12 | Average attribute |
| Condition floor | 40 | Prevent unrealistic collapse |
| Condition ceiling | 100 | Maximum |
| Sharpness floor (Sh_store) | 1000 | 10% minimum |
| Sharpness ceiling (Sh_store) | 10000 | 100% maximum |
| Fatigue floor | -500 | Very fresh |
| Fatigue ceiling | 1000 | Extreme exhaustion |

### Two-match propagation example

**Player:** MF1, Stamina=14, NF=15, WorkRate=13
**Initial state:** C=90, Sh_store=8500 (85%), F_internal=350, T_internal=400

**Match 1:** Medium importance, plays 85 minutes, 4 days to Match 2

**Post-Match 1 calculation:**

*Condition:*
- Drop: 85 × 0.25 × (1.1 - 14/200) = 85 × 0.25 × 1.03 = 21.9
- Recovery: 4 × (3 + 15/10) = 4 × 4.5 = 18
- C_new = clamp(90 - 21.9 + 18, 40, 100) = **86.1**

*Sharpness:*
- Decay: exp(-0.02 × 4) = 0.923
- Gain: 85 × (3 + 15/15) × (1 + 13/40) = 85 × 4 × 1.325 = 450.5
- Sh_new = clamp(8500 × 0.923 + 450.5, 1000, 10000) = **8296** (83%)

*Fatigue:*
- Accrual: 85 × 4 × (1.2 - 14/100) = 85 × 4 × 1.06 = 360.4
- Recovery: 4 × (40 + 15 × 2) = 4 × 70 = 280
- F_new = clamp(350 + 360.4 - 280, -500, 1000) = **430.4**

**Pre-Match 2 state:** C=86.1, Sh_store=8296 (83%), F_internal=430.4

**Match 2:** High importance, plays 90 minutes, 3 days to Match 3

**Post-Match 2 calculation:**

*Condition:*
- Drop: 90 × 0.25 × 1.03 = 23.2
- Recovery: 3 × 4.5 = 13.5
- C_new = clamp(86.1 - 23.2 + 13.5, 40, 100) = **76.4**

*Sharpness:*
- Decay: exp(-0.02 × 3) = 0.942
- Gain: 90 × 4 × 1.325 = 477
- Sh_new = clamp(8296 × 0.942 + 477, 1000, 10000) = **8292** (83%)

*Fatigue:*
- Accrual: 90 × 4 × 1.06 = 381.6
- Recovery: 3 × 70 = 210
- F_new = clamp(430.4 + 381.6 - 210, -500, 1000) = **602**

**Pre-Match 3 state:** C=76.4, Sh_store=8292, F_internal=602

**Observation:** After two demanding matches with 3-4 day gaps, the player has dropped from comfortable (F=350, C=90) to concerning (F=602, C=76.4). The system should now factor in potential rest for Match 3.

---

## Deliverable H: Explainability system

### Factor breakdown structure

Every assignment decision produces a complete breakdown:

```javascript
{
  player: "Marcus Rashford",
  slot: "ST-L",
  decision: "START",
  utility: 127.4,
  breakdown: {
    baseRating: { value: 155, description: "Role rating for ST-L (IP: 160, OOP: 150)" },
    conditionMult: { value: 0.94, input: 88, description: "Φ(88) = 0.94" },
    sharpnessMult: { value: 0.98, input: 75, description: "Ψ(75%) = 0.98" },
    familiarityMult: { value: 0.97, input: 16, description: "Θ(16) = 0.97" },
    fatigueMult: { value: 0.88, input: { F: 480, T: 400 }, description: "Λ(+80 over threshold) = 0.88" },
    adjustedRating: 124.9,
    stabilityBonus: { value: 5, reason: "Played ST-L in previous match" },
    shadowCost: { value: -2.5, reason: "Could also play LW, AM-L" },
    finalUtility: 127.4
  },
  primaryReason: "STABILITY",
  explanation: "Retained in ST-L position from previous match; moderate fatigue but manageable for High importance fixture."
}
```

### Reason templates with trigger logic

**Category 1: REST reasons**

| Template ID | Template Text | Trigger Condition |
|-------------|---------------|-------------------|
| REST_FATIGUE | "{name} is rested due to excessive fatigue ({fatigue_ui} fatigue, {pct_over}% over personal threshold)" | F_internal > T_internal + 250 AND assigned to REST |
| REST_CONDITION | "{name} is rested due to low condition ({condition}%) which would impair match performance" | C < 75 AND assigned to REST |
| REST_ROTATION | "{name} is rested for squad rotation in this {importance} importance match" | importance ∈ {Low, Sharpness} AND assigned to REST AND F_internal < T_internal + 100 |
| REST_UPCOMING | "{name} is preserved for upcoming {next_match} match in {days} days" | Next match importance > current AND assigned to REST |

**Category 2: Forced REST reasons**

| Template ID | Template Text | Trigger Condition |
|-------------|---------------|-------------------|
| REST_INJURED | "{name} is unavailable due to injury ({injury_type}, {days_remaining} days remaining)" | player.injured == true |
| REST_BANNED | "{name} is serving a {ban_type} suspension ({matches_remaining} match(es) remaining)" | player.banned == true |
| REST_EXCLUDED | "{name} was manually excluded from selection for this match" | player in full_rejections |

**Category 3: Stability-driven choices**

| Template ID | Template Text | Trigger Condition |
|-------------|---------------|-------------------|
| STAB_RETAINED | "{name} retained in {slot} from previous match; stability bonus of {bonus} points outweighed marginal alternatives" | StabilityBonus applied AND best alternative within 8 points |
| STAB_PARTNERSHIP | "{name} continues alongside {partner} to maintain defensive/midfield partnership cohesion" | Both players retained from previous match in adjacent positions |
| STAB_DESPITE_FATIGUE | "{name} retained despite elevated fatigue ({fatigue_ui}) due to limited quality alternatives at {slot}" | StabilityBonus applied AND F > T + 100 AND next best player >15 points worse |
| STAB_FORM | "{name}'s recent form and familiarity with {slot} role justifies continued selection over fresher alternatives" | Sharpness > 70 AND Familiarity > 14 AND StabilityBonus applied |

**Category 4: Shadow cost preservation choices**

| Template ID | Template Text | Trigger Condition |
|-------------|---------------|-------------------|
| SHADOW_SPECIALIST | "{name} assigned to {slot} as their specialist position, preserving {other_player}'s versatility for {other_slots}" | Player has only 1 viable slot AND other polyvalent player could play this slot |
| SHADOW_OPTIMAL_FIT | "{name} is the optimal fit for {slot}; alternative {alternative} preserved for {alternative_slot} where they're stronger" | ShadowCost applied to alternative AND alternative's rating higher in alternative_slot |
| SHADOW_COVERAGE | "{name} deployed at {slot} to maintain coverage depth at {other_positions} through {polyvalent_players}" | Assignment preserves ability to cover multiple positions with remaining squad |

**Category 5: Performance-driven choices**

| Template ID | Template Text | Trigger Condition |
|-------------|---------------|-------------------|
| PERF_BEST_AVAILABLE | "{name} selected as highest-rated option for {slot} (utility: {utility} vs next best: {next_utility})" | Utility > next alternative by >10 points AND no stability/shadow effects dominant |
| PERF_CONDITION | "{name} selected over {alternative} due to superior physical condition ({condition}% vs {alt_condition}%)" | Condition difference > 10 AND rating difference < 5 |
| PERF_SHARPNESS | "{name}'s match sharpness ({sharpness}%) gives them the edge over rustier {alternative} ({alt_sharpness}%)" | Sharpness mode AND sharpness difference > 15 |
| PERF_TACTICAL | "{name}'s role familiarity ({familiarity}/20) critical for {importance} importance tactical requirements" | Familiarity difference > 4 AND High importance |

### Primary reason classification

Each decision has a **primary reason** determined by which factor contributed most:

```python
def classify_primary_reason(breakdown, decision_type):
    if decision_type == 'REST':
        if player.injured: return 'FORCED_INJURY'
        if player.banned: return 'FORCED_BAN'
        if breakdown.fatigueMult.input.F > breakdown.fatigueMult.input.T + 250:
            return 'FATIGUE'
        if breakdown.conditionMult.input < 75:
            return 'CONDITION'
        return 'ROTATION'
    
    # For START decisions
    factors = {
        'STABILITY': breakdown.stabilityBonus.value,
        'SHADOW': abs(breakdown.shadowCost.value),
        'CONDITION': (1 - breakdown.conditionMult.value) * 50,
        'SHARPNESS': (1 - breakdown.sharpnessMult.value) * 50,
        'FATIGUE': (1 - breakdown.fatigueMult.value) * 50,
        'BASE_QUALITY': breakdown.baseRating.value / 10
    }
    
    return max(factors, key=factors.get)
```

### Example explanation outputs

**Example 1: Star player rested**
```
{
  player: "Kevin De Bruyne",
  slot: "REST",
  decision: "REST",
  utility_rest: 68.5,
  utility_best_slot: 75.2,
  primaryReason: "FATIGUE",
  explanation: "Kevin De Bruyne is rested due to excessive fatigue (92 fatigue, 38% over personal threshold). Despite being the highest-rated option for AM-C, accumulated fatigue from 3 matches in 8 days necessitates recovery ahead of Champions League fixture in 4 days.",
  templates_used: ["REST_FATIGUE", "REST_UPCOMING"]
}
```

**Example 2: Stability retention**
```
{
  player: "Rodri",
  slot: "DM-C",
  decision: "START",
  utility: 142.3,
  next_best_player: { name: "Kalvin Phillips", utility: 138.1 },
  primaryReason: "STABILITY",
  explanation: "Rodri retained in DM-C from previous match; stability bonus of 6 points outweighed marginal alternatives. Kalvin Phillips (138.1) is slightly fresher but partnership continuity with Gundogan prioritized.",
  templates_used: ["STAB_RETAINED", "STAB_PARTNERSHIP"]
}
```

**Example 3: Shadow cost preservation**
```
{
  player: "John Stones",
  slot: "CB-R",
  decision: "START",
  utility: 118.7,
  primaryReason: "SHADOW",
  explanation: "John Stones assigned to CB-R as their specialist position, preserving Kyle Walker's versatility for RB/RWB coverage. Walker's CB rating (112) is lower than his RB rating (145), making Stones the optimal CB assignment.",
  templates_used: ["SHADOW_SPECIALIST", "SHADOW_OPTIMAL_FIT"]
}
```

### Implementation notes

1. **Template selection is deterministic**: Given identical inputs, the same templates are always selected
2. **Multiple templates can combine**: Complex decisions reference 2-3 templates for complete explanation
3. **Numeric context is always provided**: Explanations include specific values (utility scores, percentages, point differences) for transparency
4. **Comparison to alternatives**: Where relevant, explanations reference the next-best option and why it wasn't chosen
5. **Future-awareness**: For REST decisions, explanations can reference upcoming fixture importance when that drives the decision

---

## Summary: Implementation checklist

| Deliverable | Key Implementation Files | Critical Constants |
|-------------|--------------------------|-------------------|
| A: Multipliers | `multipliers.ts` | Φ, Ψ, Θ, Λ with mode-specific params |
| B: Fatigue UI | `fatigueMapping.ts` | Scale factor 0.10, center at 50 |
| C: Cost matrix | `costMatrix.ts` | MAX_UTILITY=250, FORBIDDEN=1e9 |
| D: REST slots | `restUtility.ts` | α, β, γ, δ coefficients by mode |
| E: Constraints | `constraintHandler.ts` | Problem reduction logic |
| F: Minutes | `minutesAllocation.ts` | Base minutes by mode, sub priorities |
| G: Propagation | `statePropagation.ts` | Decay rates, gain rates, clamp bounds |
| H: Explainability | `explanationGenerator.ts` | 12+ templates with triggers |

This specification removes all ambiguity—each formula is exact, each parameter has a default value, and each edge case has defined behavior. Implementation can proceed directly from this document.