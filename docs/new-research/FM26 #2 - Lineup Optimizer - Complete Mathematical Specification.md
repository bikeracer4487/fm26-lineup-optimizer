# FM26 Lineup Optimizer: Complete Mathematical Specification

A Football Manager companion app needs algorithms that are **deterministic, bounded, and tunable**. This specification provides production-ready formulas for all multiplier functions, state propagation equations, shadow pricing integration, and stability mechanisms—each with concrete parameters and worked examples.

## The core utility model integrates four multiplicative factors

The player-slot utility function combines base effectiveness with context-sensitive multipliers:

```
U_{i,s} = B_{i,s} × Φ(C_i, Ω) × Ψ(Sh_i, Ω) × Θ(Fam_{i,s}, Ω) × Λ(F_i, T_i, Ω)
```

All multipliers use a **bounded sigmoid** functional form as the recommended smooth implementation, with piecewise linear alternatives provided. The sigmoid form guarantees monotonicity, prevents jitter at boundaries, and provides intuitive parameter interpretation. Every multiplier maps to the range **[α_floor, 1.0]** where α_floor > 0 ensures emergency utility is never zero.

---

## A. Familiarity multiplier Θ penalizes unfamiliar positions while allowing emergency cover

The familiarity multiplier transforms FM's 1-20 position familiarity rating into a utility multiplier. Research confirms FM uses categorical thresholds: Natural (19-20), Accomplished (13-18), Competent (10-12), Unconvincing (6-9), and Awkward (1-5), with performance degradation affecting Positioning and Decisions attributes most significantly.

### Smooth form (recommended)

```
Θ(Fam, Ω) = α + (1 - α) × σ(k × (Fam - T))

where σ(z) = 1 / (1 + e^(-z))
```

**Parameter table by importance level:**

| Importance | α (floor) | T (threshold) | k (steepness) | Behavior |
|------------|-----------|---------------|---------------|----------|
| High | 0.30 | 12 | 0.55 | Strict: demands accomplished familiarity |
| Medium | 0.40 | 10 | 0.45 | Balanced: competent is acceptable |
| Low | 0.50 | 7 | 0.35 | Tolerant: experimentation allowed |
| Sharpness | 0.25 | 14 | 0.70 | Development focus: needs confident players |

### Piecewise linear form (3-segment)

```
Θ_pw(Fam) = {
  α                                           if Fam ≤ F_low
  α + m₁ × (Fam - F_low)                      if F_low < Fam ≤ F_mid
  α + m₁×(F_mid - F_low) + m₂×(Fam - F_mid)   if F_mid < Fam ≤ F_high
  1.0                                         if Fam > F_high
}
```

| Importance | α | F_low | F_mid | F_high | m₁ | m₂ |
|------------|------|-------|-------|--------|------|------|
| High | 0.30 | 4 | 12 | 18 | 0.050 | 0.033 |
| Medium | 0.40 | 3 | 10 | 16 | 0.043 | 0.033 |
| Low | 0.50 | 2 | 8 | 14 | 0.042 | 0.033 |

### Worked examples (High importance, smooth form)

| Fam | Calculation | Result |
|-----|-------------|--------|
| 6 | 0.30 + 0.70 × σ(0.55 × -6) = 0.30 + 0.70 × 0.036 | **0.325** |
| 10 | 0.30 + 0.70 × σ(0.55 × -2) = 0.30 + 0.70 × 0.249 | **0.474** |
| 14 | 0.30 + 0.70 × σ(0.55 × 2) = 0.30 + 0.70 × 0.751 | **0.826** |
| 18 | 0.30 + 0.70 × σ(0.55 × 6) = 0.30 + 0.70 × 0.964 | **0.975** |

At Fam=6 (unconvincing), High importance assigns only **32.5%** multiplier—making this player unviable except in emergencies. At Fam=14 (accomplished), the **82.6%** multiplier makes the player a reasonable choice with modest penalty.

---

## B. Fatigue multiplier Λ degrades sharply in danger zones with player-specific thresholds

The fatigue multiplier uses player-specific thresholds T (typically 80-100) and aligns with FM's UI bands: green (<60% of T), yellow (60-79%), orange (80-99%), red (≥100%). Research from sports science confirms **72-hour recovery** for full physical restoration, with ACWR ratios above 1.5 indicating significantly elevated injury risk.

### Smooth form with player-relative thresholds

```
Λ(F, T, Ω) = α + (1 - α) × (1 - σ(k × (F/T - r)))

where:
  F = current fatigue value (0-100+)
  T = player-specific fatigue threshold
  r = ratio at which penalties begin
```

**Parameter table by importance level:**

| Importance | α (collapse) | r (ratio) | k (steepness) | Behavior |
|------------|--------------|-----------|---------------|----------|
| High | 0.50 | 0.85 | 5.0 | Push-through: tolerates fatigue for key matches |
| Medium | 0.25 | 0.75 | 6.0 | Balanced: normal fatigue sensitivity |
| Low | 0.15 | 0.65 | 8.0 | Protect: aggressive rest for rotation matches |
| Sharpness | 0.20 | 0.70 | 7.0 | Fresh only: building sharpness needs low fatigue |

The **key insight**: High importance matches *increase* α (floor), allowing fatigued players to still contribute—pushing through for crucial fixtures. Low importance matches *decrease* α and r, aggressively penalizing fatigue to preserve players for future matches.

### Piecewise linear form (4-band)

```
Λ_pw(F, T) = {
  1.00                                    if F/T ≤ 0.60  (green)
  1.00 - m₁ × (F/T - 0.60)               if 0.60 < F/T ≤ 0.80  (yellow)
  y₁ - m₂ × (F/T - 0.80)                 if 0.80 < F/T ≤ 1.00  (orange)
  max(α, y₂ - m₃ × (F/T - 1.00))         if F/T > 1.00  (red)
}
```

| Importance | m₁ | m₂ | m₃ | α |
|------------|-----|-----|-----|-----|
| High | 0.25 | 0.50 | 0.30 | 0.50 |
| Medium | 0.50 | 0.75 | 0.50 | 0.25 |
| Low | 0.75 | 1.00 | 0.40 | 0.15 |

### Worked examples (T=80, Medium importance)

| F | F/T | Calculation | Result |
|---|-----|-------------|--------|
| 40 | 0.50 | Green zone: 1.00 | **1.00** |
| 70 | 0.875 | 0.25 + 0.75 × (1 - σ(6 × 0.125)) = 0.25 + 0.75 × 0.320 | **0.49** |
| 85 | 1.0625 | 0.25 + 0.75 × (1 - σ(6 × 0.3125)) = 0.25 + 0.75 × 0.133 | **0.35** |
| 105 | 1.3125 | 0.25 + 0.75 × (1 - σ(6 × 0.5625)) = 0.25 + 0.75 × 0.034 | **0.28** |

At F=70 (yellow zone for this player), utility drops to **49%**—significant but usable. At F=105 (deep red), utility collapses to **28%**, making selection unwise except in emergencies.

---

## C. Condition multiplier Φ uses corrected thresholds aligned to realistic schedules

The draft specification had inconsistent threshold values. After analysis, the corrected thresholds reflect that High importance matches should tolerate lower condition (players must perform regardless), while Low importance should demand fresh players (preserving them).

### Corrected parameter table

| Importance | α (floor) | T_safe (threshold) | k (slope) | Rationale |
|------------|-----------|-------------------|-----------|-----------|
| High | 0.40 | 75 | 0.12 | Must field best XI even if tired |
| Medium | 0.35 | 82 | 0.10 | Standard balance |
| Low | 0.30 | 88 | 0.08 | Only fully fit players should play |
| Sharpness | 0.35 | 80 | 0.15 | Need condition for effective sharpness building |

### Smooth form

```
Φ(C, Ω) = α + (1 - α) × σ(k × (C - T_safe))
```

### Optional fixture density adjustment

When matches are closely spaced, apply a condition preservation premium:

```
Φ_adjusted(C, D_next, Ω) = Φ(C, Ω) × D_factor(D_next)

D_factor(D_next) = {
  1.00              if D_next ≥ 5 days
  0.95              if D_next = 4 days
  0.90              if D_next = 3 days  
  0.85              if D_next ≤ 2 days
}
```

This reduces utility for players who would have insufficient recovery before the next match.

### Worked examples (Medium importance)

| C | Calculation | Result |
|---|-------------|--------|
| 72 | 0.35 + 0.65 × σ(0.10 × -10) = 0.35 + 0.65 × 0.269 | **0.52** |
| 82 | 0.35 + 0.65 × σ(0) = 0.35 + 0.65 × 0.500 | **0.68** |
| 90 | 0.35 + 0.65 × σ(0.10 × 8) = 0.35 + 0.65 × 0.690 | **0.80** |
| 97 | 0.35 + 0.65 × σ(0.10 × 15) = 0.35 + 0.65 × 0.818 | **0.88** |

---

## D. State propagation equations enable deterministic 5-match simulation

The companion app must project player states across a planning horizon. These equations use **exponential decay** models consistent with sports science literature on training load recovery.

### Condition update

```
C_{k+1} = min(100, C_k - ΔC_match + ΔC_recovery)

ΔC_match = (minutes / 90) × drain_rate × (1 - stamina/200)
ΔC_recovery = days × recovery_rate × (natural_fitness/100)

Default parameters:
  drain_rate = 25-35 (position-dependent)
  recovery_rate = 12-18 per day (higher for higher natural fitness)
```

**Position-specific drain rates:**
| Position | drain_rate |
|----------|------------|
| GK | 15 |
| CB, DM | 25 |
| FB, CM, AM | 30 |
| W, ST | 35 |

### Sharpness update

```
Sh_{k+1} = Sh_k + ΔSh_gain - ΔSh_decay

ΔSh_gain = (minutes / 90) × gain_rate × match_type_factor × (1 + natural_fitness/400)
ΔSh_decay = days_since_match × decay_rate × (1 - natural_fitness/200)

Default parameters (Sharpness on 0-10000 scale, displayed as 0-100%):
  gain_rate = 1500 per full competitive match
  decay_rate = 100 per day without match
  match_type_factor: competitive=1.0, friendly=0.7, reserve=0.5
```

### Fatigue update

```
F_{k+1} = max(0, F_k + ΔF_match - ΔF_recovery)

ΔF_match = (minutes / 90) × fatigue_gain × intensity_factor
ΔF_recovery = days × recovery_rate × (1 + natural_fitness/100)

Default parameters:
  fatigue_gain = 15-25 per full match
  recovery_rate = 8-12 per rest day
  intensity_factor = 1.0 (normal), 1.3 (high-press), 0.8 (rotation match)
  
Special: vacation_bonus = 5.0 × natural_fitness/100 per vacation day
```

### Implementation pseudo-code

```python
def propagate_state(player, match_plan, current_state):
    """
    Propagate player state across k matches in the planning horizon.
    
    Args:
        player: Player attributes (stamina, natural_fitness, position)
        match_plan: List of (days_until, minutes_planned, importance, intensity)
        current_state: Dict with C, Sh, F values
    
    Returns:
        List of states [{C, Sh, F}, ...] for each match step
    """
    states = []
    state = current_state.copy()
    last_match_day = 0
    
    for k, (days_until, minutes, importance, intensity) in enumerate(match_plan):
        # Recovery from previous match to this one
        days_rest = days_until - last_match_day
        state = apply_recovery(state, player, days_rest)
        
        # Apply match load if playing
        if minutes > 0:
            state = apply_match_load(state, player, minutes, intensity)
            last_match_day = days_until
        
        states.append(state.copy())
    
    return states

def apply_recovery(state, player, days):
    nf = player.natural_fitness / 100
    return {
        'C': min(100, state['C'] + days * 15 * nf),
        'Sh': max(0, state['Sh'] - days * 100 * (1 - nf * 0.5)),
        'F': max(0, state['F'] - days * 10 * (1 + nf))
    }

def apply_match_load(state, player, minutes, intensity):
    fraction = minutes / 90
    nf = player.natural_fitness / 100
    stam = player.stamina / 200
    drain = POSITION_DRAIN[player.position]
    
    return {
        'C': state['C'] - fraction * drain * (1 - stam),
        'Sh': min(10000, state['Sh'] + fraction * 1500 * (1 + nf * 0.25)),
        'F': state['F'] + fraction * 20 * intensity
    }
```

---

## E. Shadow pricing enables multi-match awareness without exponential complexity

Shadow prices represent the **opportunity cost** of using a player now versus preserving them for future important matches. For a 5-match horizon with 25-40 players, exact dynamic programming is tractable but expensive. We provide two approaches.

### Simple approach: importance-weighted future value

This heuristic computes shadow costs in O(n × k) time per planning cycle:

```python
def compute_shadow_costs_simple(players, fixtures, states):
    """
    Simple shadow pricing based on future match importance.
    
    Returns: ShadowCost[player_id][match_k] matrix
    """
    n_players = len(players)
    horizon = len(fixtures)
    shadow = [[0.0] * horizon for _ in range(n_players)]
    
    # Discount factor for future matches
    gamma = 0.85
    
    for i, player in enumerate(players):
        for k in range(horizon):
            # Look ahead to future matches
            future_value = 0.0
            for j in range(k + 1, horizon):
                imp_weight = IMPORTANCE_WEIGHT[fixtures[j].importance]
                
                # Project state at match j given play at match k
                state_if_play = propagate_single(states[i], player, 
                                                  minutes=90, k_to_j=j-k)
                state_if_rest = propagate_single(states[i], player,
                                                  minutes=0, k_to_j=j-k)
                
                # Utility difference from playing vs resting now
                util_if_play = compute_utility(player, state_if_play, fixtures[j])
                util_if_rest = compute_utility(player, state_if_rest, fixtures[j])
                
                future_value += (gamma ** (j - k)) * imp_weight * (util_if_rest - util_if_play)
            
            shadow[i][k] = max(0, future_value)  # Opportunity cost is non-negative
    
    return shadow

IMPORTANCE_WEIGHT = {
    'High': 1.5,
    'Medium': 1.0,
    'Low': 0.6,
    'Sharpness': 0.8
}
```

### Accurate approach: Lagrangian relaxation

For higher fidelity, solve the multi-period problem via Lagrangian decomposition:

```python
def compute_shadow_costs_lagrangian(players, fixtures, states, max_iter=50):
    """
    Compute shadow prices via subgradient optimization on relaxed constraints.
    
    Constraints: Each player's cumulative load over horizon ≤ capacity
    """
    n = len(players)
    k = len(fixtures)
    
    # Lagrange multipliers for load constraints
    lambda_ = np.zeros((n, k))
    
    # Recovery/load capacity per player
    capacity = [compute_player_capacity(p) for p in players]
    
    for iteration in range(max_iter):
        # Solve k independent assignment problems with modified costs
        assignments = []
        for t in range(k):
            # Modified cost = base_cost + shadow_price
            modified_cost = base_cost_matrix(t) + lambda_[:, t].reshape(-1, 1)
            assignment = hungarian_solve(modified_cost)
            assignments.append(assignment)
        
        # Compute constraint violations (subgradient)
        violations = compute_load_violations(assignments, players, capacity)
        
        # Subgradient step
        step_size = 1.0 / (iteration + 1)
        lambda_ = np.maximum(0, lambda_ + step_size * violations)
        
        if np.max(np.abs(violations)) < 0.01:
            break
    
    return lambda_
```

### Integration with Hungarian cost matrix

Shadow costs modify the assignment cost matrix directly:

```python
def build_cost_matrix(players, slots, match_k, shadow_costs, stability_costs):
    """
    Build modified cost matrix for Hungarian algorithm.
    
    Cost = -Utility + ShadowCost + StabilityCost
    (Hungarian minimizes cost, so negate utility)
    """
    n_players = len(players)
    n_slots = len(slots)
    
    cost = np.zeros((n_players, n_slots))
    
    for i, player in enumerate(players):
        for j, slot in enumerate(slots):
            base_utility = compute_slot_utility(player, slot, match_k)
            
            # Shadow cost penalizes using valuable players now
            shadow = shadow_costs[i][match_k] if uses_player(slot) else 0
            
            # Stability cost penalizes position changes
            stability = stability_costs[i][j]
            
            cost[i, j] = -base_utility + shadow + stability
    
    return cost
```

---

## F. Polyvalent stability prevents oscillating assignments while preserving optimality

Versatile players create instability when their utility at multiple positions is similar. Two complementary approaches address this.

### Approach 1: Assignment inertia penalty (recommended)

Add a **switching cost** to the cost matrix that penalizes changing a player's assignment from the previous match:

```python
def compute_stability_costs(players, slots, prev_assignment, config):
    """
    Inertia penalty for changing player-slot assignments.
    
    Args:
        prev_assignment: Dict[player_id] -> slot_id from previous match
        config.inertia_weight: User-configurable slider [0, 1]
        config.base_switch_cost: Maximum penalty for switching
    """
    stability = np.zeros((len(players), len(slots)))
    
    for i, player in enumerate(players):
        prev_slot = prev_assignment.get(player.id)
        
        for j, slot in enumerate(slots):
            if prev_slot is None:
                # No previous assignment, no penalty
                stability[i, j] = 0
            elif slot.id == prev_slot:
                # Continuity bonus (negative cost = preference)
                stability[i, j] = -config.inertia_weight * config.continuity_bonus
            else:
                # Switching penalty
                stability[i, j] = config.inertia_weight * config.base_switch_cost
    
    return stability

# Default configuration
STABILITY_CONFIG = {
    'inertia_weight': 0.5,      # User slider: 0=pure optimal, 1=maximum stability
    'base_switch_cost': 0.15,   # ~15% utility penalty for switching
    'continuity_bonus': 0.05    # ~5% utility bonus for staying
}
```

### Approach 2: Soft-lock anchoring

After consistent assignment over N matches, anchor the player-slot pairing with elevated inertia:

```python
def compute_anchor_costs(players, slots, assignment_history, config):
    """
    Anchoring for players with consistent recent assignments.
    """
    anchors = {}
    
    for player in players:
        recent = assignment_history.get_recent(player.id, n=3)
        if len(recent) >= 3 and len(set(recent)) == 1:
            # Same slot 3+ consecutive matches → anchor
            anchors[player.id] = {
                'slot': recent[0],
                'strength': config.anchor_multiplier
            }
    
    anchor_costs = np.zeros((len(players), len(slots)))
    
    for i, player in enumerate(players):
        if player.id in anchors:
            anchor = anchors[player.id]
            for j, slot in enumerate(slots):
                if slot.id != anchor['slot']:
                    anchor_costs[i, j] = anchor['strength'] * config.base_switch_cost
    
    return anchor_costs
```

### User controls and lock handling

```python
class AssignmentManager:
    def __init__(self):
        self.manual_locks = {}      # player_id -> slot_id (user-forced)
        self.player_rejections = {} # player_id -> [slot_ids] (user blocked)
        self.confirmed_lineup = {}  # slot_id -> player_id (confirmed for match)
    
    def apply_constraints(self, cost_matrix, players, slots):
        """
        Apply hard constraints from user inputs.
        """
        INFINITY = 1e9
        
        for i, player in enumerate(players):
            # Enforce manual locks
            if player.id in self.manual_locks:
                locked_slot = self.manual_locks[player.id]
                for j, slot in enumerate(slots):
                    if slot.id != locked_slot:
                        cost_matrix[i, j] = INFINITY
            
            # Apply rejections
            if player.id in self.player_rejections:
                for j, slot in enumerate(slots):
                    if slot.id in self.player_rejections[player.id]:
                        cost_matrix[i, j] = INFINITY
        
        # Enforce confirmed lineup
        for slot_id, player_id in self.confirmed_lineup.items():
            j = slot_index(slot_id)
            for i, player in enumerate(players):
                if player.id != player_id:
                    cost_matrix[i, j] = INFINITY
        
        return cost_matrix
```

### Recommendation

**Use Assignment Inertia (Approach 1) as the primary mechanism** with an exposed slider. It integrates cleanly with Hungarian, respects all constraints, and provides intuitive tuning. Reserve Soft-Lock Anchoring (Approach 2) as an optional enhancement for squads where core positions should remain extremely stable.

---

## Complete utility computation walkthrough

Consider player "Marcus" assigned to the CM slot for a Medium importance match:

**Player attributes:**
- Base effectiveness B = 145 (harmonic mean of IP=150, OOP=140)
- Condition C = 82%
- Sharpness Sh = 7500 (75% displayed)
- Familiarity Fam = 14 (Accomplished at CM)
- Fatigue F = 65, Threshold T = 85

**Step-by-step calculation:**

1. **Condition multiplier Φ (Medium, T=82, k=0.10, α=0.35):**
   ```
   Φ = 0.35 + 0.65 × σ(0.10 × (82 - 82)) = 0.35 + 0.65 × 0.5 = 0.675
   ```

2. **Sharpness multiplier Ψ** (using standard FM curve, Sh=75%):
   ```
   Ψ = 0.40 + 0.60 × (Sh/100)^0.8 = 0.40 + 0.60 × 0.811 = 0.887
   ```

3. **Familiarity multiplier Θ (Medium, T=10, k=0.45, α=0.40):**
   ```
   Θ = 0.40 + 0.60 × σ(0.45 × (14 - 10)) = 0.40 + 0.60 × 0.858 = 0.915
   ```

4. **Fatigue multiplier Λ (Medium, r=0.75, k=6.0, α=0.25):**
   ```
   F/T = 65/85 = 0.765
   Λ = 0.25 + 0.75 × (1 - σ(6 × (0.765 - 0.75))) = 0.25 + 0.75 × 0.478 = 0.609
   ```

5. **Combined utility:**
   ```
   U = 145 × 0.675 × 0.887 × 0.915 × 0.609 = 48.4
   ```

Compare to the theoretical maximum (all multipliers at 1.0): U_max = 145. Marcus delivers **33.4%** of his potential utility in this state—the fatigue is the primary limiter.

---

## Calibration notes and tuning order

The system has **18+ tunable parameters** across the multipliers. Follow this priority order when calibrating:

1. **Threshold parameters (T, r)** — These determine *where* penalties begin. Set these first based on domain expectations (e.g., "condition below 75% is concerning").

2. **Floor parameters (α)** — These set *minimum* utility. Critical for preventing total exclusion of available players. Start at 0.25-0.40.

3. **Steepness parameters (k)** — These control *how fast* penalties apply. Tune last; start with conservative values (k < 0.5) and increase only if transitions feel too gradual.

4. **Stability weights** — The inertia slider should default to 0.4-0.6 for most users. Only advanced users should push toward extremes.

**Sensitive parameters to watch:**
- Fatigue steepness k: Values above 8.0 create very sharp cliffs
- Familiarity floor α: Below 0.25 can make unfamiliar players completely unusable
- Shadow discount γ: Values below 0.7 heavily favor immediate matches; above 0.9 over-preserves players

**Validation approach:** Run the optimizer on historical FM save data with known good lineups. Compare recommendations against human decisions and tune parameters to minimize divergence while respecting the app's rotation philosophy.