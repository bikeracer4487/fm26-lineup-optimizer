# Lineup Optimization System for Football Manager 26 Companion App

A Hungarian algorithm-based lineup optimizer can effectively balance player fitness, role suitability, and multi-match planning using the frameworks below. The system operates on stored sharpness values (0–10000), condition (0–100), fatigue (-500 to 1000 internal), and role ratings (0–200) to generate optimal lineups for a 5-match horizon while respecting user constraints.

---

## Deliverable A: Sharpness multiplier Ψ with smooth curve design

The sharpness multiplier transforms raw sharpness percentage into a performance modifier. Research from FM community testing shows sharpness has **exponential impact**—the gap between 90% and 100% affects win rate more than 8 attribute points. A sigmoid curve captures this nonlinear relationship with smooth transitions.

**Core Formula (Logistic Sigmoid):**
```
Ψ(Sh_pct) = Ψ_min + (Ψ_max - Ψ_min) / (1 + exp(-k × (Sh_pct - m)))
```
Where `Sh_pct = Sh_store / 100` and parameters vary by match importance mode:

| Mode | Ψ_min | Ψ_max | k (steepness) | m (midpoint) | Purpose |
|------|-------|-------|---------------|--------------|---------|
| **High** | 0.40 | 1.00 | 0.12 | 70 | Punish low sharpness severely |
| **Medium** | 0.55 | 1.00 | 0.10 | 60 | Balanced penalty |
| **Low** | 0.70 | 1.00 | 0.08 | 50 | Tolerate lower sharpness |
| **Sharpness** | 0.20 | 0.80 | -0.10 | 60 | *Inverted*: reward low sharpness |

**Computed Output Values:**

| Mode | Sh=10% | Sh=40% | Sh=70% | Sh=95% |
|------|--------|--------|--------|--------|
| High | 0.401 | 0.435 | 0.700 | 0.953 |
| Medium | 0.551 | 0.598 | 0.775 | 0.969 |
| Low | 0.701 | 0.738 | 0.850 | 0.978 |
| Sharpness | 0.793 | 0.650 | 0.500 | 0.215 |

The Sharpness mode inverts the curve (negative k), making low-sharpness players attractive for building match fitness. This smoothly rewards selecting players who need minutes without hard threshold jumps.

**Implementation:**
```python
def sharpness_multiplier(sh_store: int, mode: str) -> float:
    sh_pct = sh_store / 100  # Convert 0-10000 to 0-100
    params = {
        'High':      {'psi_min': 0.40, 'psi_max': 1.00, 'k': 0.12, 'm': 70},
        'Medium':    {'psi_min': 0.55, 'psi_max': 1.00, 'k': 0.10, 'm': 60},
        'Low':       {'psi_min': 0.70, 'psi_max': 1.00, 'k': 0.08, 'm': 50},
        'Sharpness': {'psi_min': 0.20, 'psi_max': 0.80, 'k': -0.10, 'm': 60},
    }[mode]
    p = params
    return p['psi_min'] + (p['psi_max'] - p['psi_min']) / (1 + math.exp(-p['k'] * (sh_pct - p['m'])))
```

---

## Deliverable B: Normalized unit system with rating-point anchoring

**Recommended approach: Option 1—keep utility in rating points (0–200 scale)** with all costs converted to equivalent rating-point penalties. This preserves interpretability: a shadow cost of 15 means "sacrificing the equivalent of 15 rating points for future benefit."

**Master Cost Formula:**
```
Cost[p,s] = -Utility[p,s] + λ_shadow × ShadowCost[p] + λ_stability × StabilityCost[p,s]
```

All terms expressed in rating points. For minimization via Hungarian algorithm, negate the entire expression or use `maximize=True`.

**Utility Calculation (in rating points):**
```
Utility[p,s] = B[p,s] × Φ(C[p]) × Ψ(Sh[p], mode) × Θ(Fam[p]) × Λ(F[p], T[p])
```

| Multiplier | Formula | Range | Interpretation |
|------------|---------|-------|----------------|
| **Φ (Condition)** | `max(0.5, C/100)` | 0.50–1.00 | Linear above 50%, floor at 0.5 |
| **Ψ (Sharpness)** | See Deliverable A | 0.20–1.00 | Mode-dependent sigmoid |
| **Θ (Familiarity)** | `0.8 + 0.2 × (Fam/20)` | 0.80–1.00 | 20% boost at max familiarity |
| **Λ (Fatigue)** | `max(0.3, 1 - 0.7 × max(0, F-T)/(500-T))` | 0.30–1.00 | Penalizes F > threshold T |

**Example Calculation:**
- Base rating B = 162, Condition = 85, Sharpness = 7500 (75%), Familiarity = 16, Fatigue F = 300, Threshold T = 400
- Φ = 0.85, Ψ(High mode) ≈ 0.77, Θ = 0.96, Λ = 1.0 (F < T)
- Utility = 162 × 0.85 × 0.77 × 0.96 × 1.0 = **101.7 rating points**

**Weight Calibration for Penalty Terms:**
- `λ_shadow`: 1.0 (shadow costs already scaled to rating-point equivalents)
- `λ_stability`: 5–15 rating points per position change (tune via calibration harness)

---

## Deliverable C: Hungarian assignment matrix with REST slots

**Recommended Design: Rectangular with REST slot padding.** Use scipy's native rectangular support plus explicit REST columns to model "who rests."

**Matrix Structure (N=35 players, S=11 slots):**
```
Dimensions: 35 rows × 35 columns = [11 playing slots] + [24 REST slots]
```

| | Slot0 | Slot1 | ... | Slot10 | REST_0 | REST_1 | ... | REST_23 |
|---|-------|-------|-----|--------|--------|--------|-----|---------|
| Player0 | Cost | Cost | ... | Cost | RestCost | RestCost | ... | RestCost |
| Player1 | Cost | Cost | ... | Cost | RestCost | RestCost | ... | RestCost |
| ... | ... | ... | ... | ... | ... | ... | ... | ... |
| Player34 | Cost | Cost | ... | Cost | RestCost | RestCost | ... | RestCost |

**REST Cost Calculation:**
```python
def rest_cost(player, mode):
    # Base rest cost = 0 (neutral)
    # High fatigue players get NEGATIVE cost (encouraged to rest)
    # In maximization: higher = more attractive
    if player.injured or player.banned:
        return PRACTICAL_INF  # Force rest
    fatigue_bonus = max(0, player.fatigue - player.threshold) * 0.3
    sharpness_penalty = 0
    if mode == 'Sharpness' and player.sharpness_pct < 70:
        sharpness_penalty = -20  # Discourage resting low-sharpness players
    return fatigue_bonus + sharpness_penalty
```

**Constraint Encoding via Costs:**

| Constraint | Implementation |
|------------|----------------|
| **Lock (player P to slot S)** | `Cost[P,S] = -LOCK_BONUS` where LOCK_BONUS = max_utility × N + 1000 |
| **Reject (P cannot play S)** | `Cost[P,S] = +PRACTICAL_INF` (1e7) |
| **Injured/Banned** | Set entire row to +PRACTICAL_INF except REST columns |
| **Confirmed lineup (match k)** | Remove from optimization; fix assignments |

**Implementation Pseudocode:**
```python
def build_cost_matrix(players, slots, locks, rejects, banned, mode):
    N, S = len(players), len(slots)
    N_rest = N - S
    
    # Initialize: playing slots use computed costs
    cost = np.zeros((N, S + N_rest))
    for p_idx, player in enumerate(players):
        for s_idx, slot in enumerate(slots):
            cost[p_idx, s_idx] = compute_cost(player, slot, mode)
        # REST columns
        cost[p_idx, S:] = rest_cost(player, mode)
    
    # Apply constraints
    for p, s in locks:
        cost[p, s] = -1e9  # Guaranteed selection
    for p, s in rejects:
        cost[p, s] = 1e7   # Prohibited
    for p in banned:
        cost[p, :S] = 1e7  # Can't play
        cost[p, S:] = -1e9 # Must rest
    
    return cost

row_ind, col_ind = linear_sum_assignment(cost, maximize=False)
playing = [(r, c) for r, c in zip(row_ind, col_ind) if c < S]
resting = [r for r, c in zip(row_ind, col_ind) if c >= S]
```

---

## Deliverable D: Deterministic minutes allocation model

A two-stage heuristic assigns minutes after the Hungarian algorithm determines the starting lineup. Minutes depend on match importance, player state, and role in the squad.

**Stage 1: Starter Minutes Assignment**

| Condition | Base Minutes | Fatigue Adjustment |
|-----------|--------------|-------------------|
| C ≥ 90 and F < T-100 | 90 | None |
| 80 ≤ C < 90 | 75 | -10 if F > T |
| 70 ≤ C < 80 | 60 | -15 if F > T |
| C < 70 | 45 | -15 if F > T |

**Formula:**
```python
def starter_minutes(player, match_importance):
    base = 90
    if player.condition < 90:
        base -= (90 - player.condition) // 10 * 15
    if player.fatigue > player.threshold:
        base -= 10 + (player.fatigue - player.threshold) // 100 * 5
    if match_importance == 'Low':
        base = min(base, 75)  # Cap for rotation
    return max(30, base)  # Minimum 30 if starting
```

**Stage 2: Substitute Minutes Assignment**

Select **3 substitutes** from resting players, ranked by: (1) utility if introduced at 60', (2) condition > 85, (3) different roles than starters for tactical flexibility.

| Sub Priority | Entry Time | Minutes |
|--------------|------------|---------|
| Impact sub (high utility) | 60' | 30 |
| Fresh legs (high condition) | 70' | 20 |
| Tactical option | 80' | 10 |

**Sharpness Mode Special Logic:**
When `mode == 'Sharpness'`:
- Players with Sh_pct < 50: guarantee at least 45 minutes
- Cap high-sharpness players (>90%) at 60 minutes
- Prioritize low-sharpness players as early subs (55'-60')

**Minutes Propagation for State Updates:**
```python
def update_player_state(player, minutes_played, match_importance):
    # Sharpness gain (diminishing returns at high values)
    if player.sharpness_pct < 90:
        gain = min(9, 11 - player.sharpness_pct // 10) * (minutes_played / 90)
    else:
        gain = 2 * (minutes_played / 90)
    player.sharpness_pct += gain
    
    # Condition loss
    condition_drop = 25 * (minutes_played / 90) * (1 + player.work_rate / 20)
    player.condition = max(0, player.condition - condition_drop)
    
    # Fatigue accumulation
    importance_mult = {'High': 1.2, 'Medium': 1.0, 'Low': 0.8}[match_importance]
    fatigue_gain = minutes_played * 2 * importance_mult
    player.fatigue = min(1000, player.fatigue + fatigue_gain)
```

---

## Deliverable E: Shadow pricing with planned minutes

Shadow pricing quantifies the opportunity cost of playing a player now versus preserving them for future high-importance matches. The system uses **planned minutes** rather than binary play/rest.

**Shadow Cost Formula:**
```
ShadowCost[p, match_k] = Σ_{j>k} Importance_weight[j] × Availability_impact(minutes_k, match_j)
```

**Availability Impact Function:**
Models how minutes in match k reduce expected contribution in match j:
```python
def availability_impact(player, minutes_k, days_between, match_j_importance):
    # Estimate condition at match j after playing minutes_k
    condition_drop = 25 * (minutes_k / 90)
    recovery_rate = 8 * player.natural_fitness / 10  # % per day
    expected_condition = min(100, player.condition - condition_drop + days_between * recovery_rate)
    
    # Estimate fatigue at match j
    fatigue_gain = minutes_k * 2
    fatigue_recovery = days_between * 50  # Approximate daily recovery
    expected_fatigue = max(-500, player.fatigue + fatigue_gain - fatigue_recovery)
    
    # Contribution loss if condition/fatigue suboptimal
    condition_penalty = max(0, 90 - expected_condition) * 0.5
    fatigue_penalty = max(0, expected_fatigue - player.threshold) * 0.3
    
    return (condition_penalty + fatigue_penalty) * importance_weight(match_j_importance)

def importance_weight(importance):
    return {'High': 1.5, 'Medium': 1.0, 'Low': 0.5, 'Sharpness': 0.3}[importance]
```

**Output Shape:** `ShadowCost[player][match]` (not per-slot, since shadow cost is player-specific)

**Horizon Decay:** Apply discount factor for distant matches:
```
ShadowCost[p, k] = Σ_{j=k+1}^{k+4} γ^(j-k-1) × availability_impact(...)
```
Where γ = 0.85 (15% discount per match into future)

**Full Computation:**
```python
def compute_shadow_costs(players, matches, current_match_idx):
    shadow = {}
    for p in players:
        total_cost = 0
        for j in range(current_match_idx + 1, min(current_match_idx + 5, len(matches))):
            future_match = matches[j]
            days_between = (future_match.date - matches[current_match_idx].date).days
            discount = 0.85 ** (j - current_match_idx - 1)
            
            # Compare full 90 vs planned minutes
            planned_minutes = estimate_minutes(p, matches[current_match_idx].importance)
            impact = availability_impact(p, planned_minutes, days_between, future_match.importance)
            total_cost += discount * impact
        
        shadow[p.id] = total_cost
    return shadow
```

---

## Deliverable F: Explainability system with 12 reason string templates

The system decomposes utility into factor contributions and selects the most significant factors for human-readable explanations.

**Factor Contribution Calculation (Additive Decomposition):**
```python
def compute_contributions(player, slot, mode):
    B = role_rating(player, slot)  # 0-200
    C = player.condition
    Sh = player.sharpness_pct
    Fam = player.familiarity
    F, T = player.fatigue, player.threshold
    
    # Compute multipliers
    phi = max(0.5, C / 100)
    psi = sharpness_multiplier(player.sharpness_store, mode)
    theta = 0.8 + 0.2 * (Fam / 20)
    lambd = max(0.3, 1 - 0.7 * max(0, F - T) / (500 - T)) if F > T else 1.0
    
    # Contribution relative to perfect state (all multipliers = 1.0)
    base_contribution = B  # Perfect state utility
    actual_utility = B * phi * psi * theta * lambd
    
    return {
        'base_rating': B,
        'condition_effect': B * (phi - 1),        # Negative if C < 100
        'sharpness_effect': B * phi * (psi - 1),  # Negative if Sh < optimal
        'familiarity_effect': B * phi * psi * (theta - 1),
        'fatigue_effect': B * phi * psi * theta * (lambd - 1),
        'final_utility': actual_utility
    }
```

**12 Reason String Templates with Trigger Logic:**

| # | Trigger Condition | Template | Example Output |
|---|-------------------|----------|----------------|
| 1 | Selected AND B ≥ 150 AND all multipliers > 0.9 | "Selected: excellent role fit (B={B}), peak condition" | "Selected: excellent role fit (B=162), peak condition" |
| 2 | Selected AND psi < 0.7 AND mode == 'Sharpness' | "Selected: needs match fitness (Sh={Sh}%), building sharpness" | "Selected: needs match fitness (Sh=52%), building sharpness" |
| 3 | Selected AND lambd < 0.85 | "Selected despite fatigue risk: squad depth limited" | — |
| 4 | Selected AND shadow_cost > 10 | "Selected: high importance match justifies (shadow={shadow:.0f})" | "Selected: high importance match justifies (shadow=18)" |
| 5 | Benched AND lambd < 0.7 | "Benched: fatigue risk (F/T={ratio:.2f}), needs recovery" | "Benched: fatigue risk (F/T=1.15), needs recovery" |
| 6 | Benched AND phi < 0.75 | "Benched: low condition ({C}%), recovering fitness" | "Benched: low condition (68%), recovering fitness" |
| 7 | Benched AND shadow_cost > 20 | "Preserved for {future_match}: shadow cost applied" | "Preserved for UCL Semi: shadow cost applied" |
| 8 | Benched AND B < 120 for slot | "Benched: limited role fit (B={B}) for {slot}" | "Benched: limited role fit (B=98) for DM" |
| 9 | Benched AND stability_cost < -5 | "Benched: rotation policy—played {recent_games}/5 recent" | "Benched: rotation policy—played 5/5 recent" |
| 10 | Locked by user | "Locked: user selection override" | — |
| 11 | Rejected by user | "Excluded: user rejection for this slot" | — |
| 12 | Injured/Banned | "Unavailable: {reason} until {return_date}" | "Unavailable: hamstring strain until Dec 15" |

**Implementation:**
```python
def generate_reason(player, slot, decision, factors, context):
    if player.injured:
        return f"Unavailable: {player.injury_type} until {player.return_date}"
    if context.get('locked'):
        return "Locked: user selection override"
    if context.get('rejected'):
        return "Excluded: user rejection for this slot"
    
    B = factors['base_rating']
    psi = factors['sharpness_multiplier']
    lambd = factors['fatigue_multiplier']
    phi = factors['condition_multiplier']
    shadow = context.get('shadow_cost', 0)
    
    if decision == 'selected':
        if B >= 150 and psi > 0.9 and lambd > 0.9 and phi > 0.9:
            return f"Selected: excellent role fit (B={B}), peak condition"
        if psi < 0.7 and context['mode'] == 'Sharpness':
            return f"Selected: needs match fitness (Sh={player.sharpness_pct:.0f}%), building sharpness"
        if lambd < 0.85:
            return "Selected despite fatigue risk: squad depth limited"
        if shadow > 10:
            return f"Selected: high importance match justifies (shadow={shadow:.0f})"
        return f"Selected: best available for {slot.name} (B={B})"
    
    else:  # benched
        if lambd < 0.7:
            return f"Benched: fatigue risk (F/T={player.fatigue/player.threshold:.2f}), needs recovery"
        if phi < 0.75:
            return f"Benched: low condition ({player.condition:.0f}%), recovering fitness"
        if shadow > 20:
            return f"Preserved for {context['next_high_match']}: shadow cost applied"
        if B < 120:
            return f"Benched: limited role fit (B={B}) for {slot.name}"
        return "Benched: rotation preference"
```

---

## Deliverable G: Calibration harness for offline evaluation

The calibration harness evaluates lineup recommendations against historical snapshots without requiring live gameplay.

**Input Schema:**
```python
@dataclass
class SquadSnapshot:
    date: datetime
    players: List[PlayerState]  # All player stats at this moment
    fixtures: List[Fixture]     # Next 5 matches with dates and importance

@dataclass  
class PlayerState:
    id: str
    role_ratings: Dict[str, int]  # slot_name → rating
    condition: float
    sharpness_store: int
    fatigue: float
    threshold: float
    familiarity: int
    injured: bool
    banned: bool
```

**Output Schema:**
```python
@dataclass
class EvaluationResult:
    lineups: List[List[Tuple[str, str]]]  # 5 matches of (player_id, slot) assignments
    trajectories: Dict[str, List[PlayerState]]  # player_id → state after each match
    metrics: EvaluationMetrics

@dataclass
class EvaluationMetrics:
    match_strength: List[float]      # Sum of utilities per match
    avg_strength: float
    rotation_count: int              # Total position changes across 5 matches
    rotation_rate: float             # rotation_count / (5 × 11)
    fatigue_violations: int          # Matches where player played with F > T
    sharpness_improvement: float     # Avg Sh change for players with Sh < 70%
    stability_score: float           # % of slots unchanged between consecutive matches
```

**Calibration Workflow:**
```python
class CalibrationHarness:
    def __init__(self, optimizer, param_grid):
        self.optimizer = optimizer
        self.param_grid = param_grid
    
    def run_calibration(self, snapshots: List[SquadSnapshot]) -> Dict:
        results = []
        
        for params in self.param_grid:
            self.optimizer.set_params(params)
            
            snapshot_results = []
            for snapshot in snapshots:
                # Generate 5-match lineup plan
                lineups, trajectories = self.optimizer.plan_horizon(
                    snapshot.players, snapshot.fixtures
                )
                
                # Compute metrics
                metrics = self.evaluate(lineups, trajectories, snapshot)
                snapshot_results.append(metrics)
            
            # Aggregate across snapshots
            aggregated = self.aggregate_metrics(snapshot_results)
            results.append({'params': params, 'metrics': aggregated})
        
        # Select best parameters (multi-objective)
        best = self.select_best(results)
        sensitivity = self.compute_sensitivity(results)
        
        return {
            'best_params': best['params'],
            'all_results': results,
            'sensitivity': sensitivity
        }
    
    def select_best(self, results):
        # Weighted objective: maximize strength, penalize fatigue violations
        def score(r):
            m = r['metrics']
            return (
                0.5 * m.avg_strength / 200 +      # Normalize to ~1
                0.2 * m.stability_score +
                0.2 * m.sharpness_improvement / 20 +
                -0.1 * m.fatigue_violations / 5
            )
        return max(results, key=score)
```

**Sensitivity Analysis:**
```python
def compute_sensitivity(self, results):
    # One-at-a-time sensitivity
    baseline = [r for r in results if r['params'] == self.baseline_params][0]
    sensitivity = {}
    
    for param_name in self.param_names:
        param_results = [r for r in results if self.differs_only_in(r['params'], param_name)]
        scores = [self.score(r) for r in param_results]
        sensitivity[param_name] = {
            'range': (min(scores), max(scores)),
            'std': np.std(scores),
            'critical': np.std(scores) > 0.05  # Flag if score varies >5%
        }
    
    return sensitivity
```

**Recommended Parameter Grid:**

| Parameter | Test Values | Purpose |
|-----------|-------------|---------|
| `lambda_shadow` | [0.5, 0.75, 1.0, 1.25, 1.5] | Shadow pricing weight |
| `lambda_stability` | [5, 10, 15, 20] | Stability penalty (rating points) |
| `sharpness_k` (High mode) | [0.08, 0.10, 0.12, 0.14] | Sigmoid steepness |
| `fatigue_penalty_rate` | [0.2, 0.3, 0.4, 0.5] | Fatigue multiplier decay rate |
| `horizon_discount` | [0.7, 0.85, 0.95] | Future match discount factor |

**Metrics Target Ranges:**
- **avg_strength**: > 150 (assumes B≈160 for starters with minor penalties)
- **rotation_rate**: 15–25% (healthy rotation without chaos)
- **fatigue_violations**: 0 ideal, < 3 acceptable
- **stability_score**: > 70% (7+ unchanged slots between matches)
- **sharpness_improvement**: > 5% for low-sharpness players

---

## Implementation architecture summary

The system processes lineup optimization through this pipeline:

1. **State Loading** → Read player stats, apply injury/ban flags
2. **Mode Selection** → User chooses High/Medium/Low/Sharpness per match
3. **Utility Computation** → Calculate `B × Φ × Ψ × Θ × Λ` for each player-slot pair
4. **Shadow Pricing** → Compute forward-looking opportunity costs
5. **Cost Matrix Assembly** → Build N×(S+REST) matrix with constraints encoded
6. **Hungarian Optimization** → Solve assignment problem (scipy)
7. **Minutes Allocation** → Assign starter minutes + select 3 subs
8. **State Propagation** → Update sharpness/condition/fatigue for next match
9. **Explanation Generation** → Create reason strings for each decision
10. **Repeat** for matches 2–5

The calibration harness runs this pipeline across historical snapshots to tune parameters without overfitting, ensuring robust real-world performance across diverse squad configurations and fixture congestion scenarios.