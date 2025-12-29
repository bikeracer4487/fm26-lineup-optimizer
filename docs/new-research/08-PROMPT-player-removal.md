# Research Prompt 08: Player Removal Model

## Context

Squad management requires decisions about which players to keep, sell, loan, or release. Our app has `api_player_removal.py` but it needs a sophisticated multi-factor model that acts like an intelligent sporting director.

### Current Implementation Issues

- Simple CA-based sorting (doesn't capture nuance)
- No consideration of squad balance
- Missing age curve and potential analysis
- No protection for critical players
- Doesn't consider financial factors

## Research Objective

**Goal**: Design a player removal decision model that:
1. Identifies surplus players without damaging squad depth
2. Weighs multiple factors (ability, potential, wages, age, contribution)
3. Recommends appropriate action (sell, loan, release)
4. Protects critical players from removal

## The Player Removal Problem

### Why Remove Players?

1. **Wage Budget**: Free up wages for better players
2. **Squad Size**: Maintain manageable squad numbers
3. **Playing Time**: Let young players get minutes elsewhere
4. **Performance**: Replace underperforming players
5. **Age Curve**: Sell before value decline

### Actions Available

| Action | When Appropriate | Financial Impact |
|--------|------------------|------------------|
| **Sell** | Marketable player with value | Receive transfer fee |
| **Loan Out** | Young player needing minutes | Save wages, gain development |
| **Release** | Low value, high wages | Save wages, no fee |
| **Keep** | Valuable to squad | Status quo |

### Constraints

- Must maintain minimum squad depth
- Cannot remove "untouchable" players
- Must consider registration rules (domestic/foreign quotas)
- Should respect player wishes (somewhat)

## Questions to Resolve

### 1. Contribution Score

**How do we measure a player's value to the squad?**

**Factors**:
- Current Ability (raw quality)
- Position importance (GK more critical than 3rd striker)
- Squad role (starter, rotation, depth, youth prospect)
- Recent performances (if available)
- Unique capabilities (only player who can play position X)

**Questions**:
- How do we weight these factors?
- Should contribution be position-specific?
- How do we handle players who haven't played much?

### 2. Future Value Assessment

**Will this player be worth more or less in the future?**

**Factors**:
- Age vs peak age for position
- Potential Ability (PA) vs Current Ability (CA)
- Development trajectory (improving or stagnating?)
- Injury history
- Contract length

**Age Curve by Position**:
| Position | Peak Age | Decline Start |
|----------|----------|---------------|
| GK | 30-33 | 35 |
| CB | 27-31 | 33 |
| FB | 25-29 | 31 |
| CM | 26-30 | 32 |
| AM/W | 24-28 | 30 |
| ST | 25-29 | 31 |

**Questions**:
- How much should PA influence decisions for young players?
- When is a player "past their peak" enough to sell?
- How do we factor in injury proneness?

### 3. Financial Analysis

**What are the financial implications?**

**Factors**:
- Current market value (estimated sale price)
- Weekly wages
- Contract years remaining
- Wage ratio (wages vs contribution)

**Wage Efficiency**:
```
wage_efficiency = contribution_score / weekly_wages
```

**Questions**:
- What wage_efficiency threshold indicates overpayment?
- Should we consider amortization of transfer fee?
- How do we estimate market value?

### 4. Squad Balance Check

**Will removing this player create a problem?**

**Checks**:
- Position depth: Are there enough players for each position?
- Quality depth: Is the drop to next player acceptable?
- Registration: Will removal affect domestic/foreign balance?
- Upcoming fixtures: Do we need depth for congestion?

**Questions**:
- What is minimum acceptable depth per position?
- How do we define "acceptable quality drop"?
- Should we flag registration implications?

### 5. Protection Rules

**Which players should never be recommended for removal?**

**Protection Categories**:
- Key players (top N by contribution)
- Players with no backup (unique position coverage)
- Youth with high potential (investment protection)
- Recent signings (give chance to settle)
- User-flagged players (manual protection)

**Questions**:
- How many players should be "protected"?
- Should protection be absolute or just raise threshold?
- How do we identify youth worth protecting?

### 6. Action Selection Logic

**Given player should be removed, which action?**

```
IF player.value > wage_threshold AND player.age < peak_decline:
    IF player.age < 23 AND player.needs_minutes:
        RECOMMEND: Loan
    ELSE:
        RECOMMEND: Sell
ELIF player.value > 0:
    RECOMMEND: Sell
ELSE:
    RECOMMEND: Release
```

**Questions**:
- What value threshold makes selling worthwhile?
- When is loan better than sale?
- How do we decide between loan and keeping?

### 7. Hidden Attributes Consideration

FM has hidden attributes affecting performance:
- Consistency: Affects match-to-match reliability
- Important Matches: Performance in big games
- Injury Proneness: Long-term availability
- Professionalism: Training/development impact

**Questions**:
- If we can access these, how should they factor in?
- If we can't, how do we proxy for them?
- Which hidden attributes matter most for removal decisions?

## Expected Deliverables

### A. Contribution Score Algorithm

```python
def calculate_contribution_score(player, squad, formation):
    """
    Returns: float (0-100)

    Components:
    - ability_component: based on CA and role ratings
    - position_component: how critical is their position
    - depth_component: how replaceable are they
    - performance_component: recent form (if available)
    """
```

**Component Weights**:
| Component | Weight | Rationale |
|-----------|--------|-----------|

### B. Future Value Model

```python
def assess_future_value(player):
    """
    Returns: FutureValueAssessment

    FutureValueAssessment:
        current_phase: str ('rising', 'peak', 'declining')
        value_trend: str ('increasing', 'stable', 'decreasing')
        pa_headroom: int (PA - CA)
        years_to_peak: int
        years_until_decline: int
        recommended_action_timing: str ('sell now', 'sell next season', 'keep')
    """
```

### C. Financial Analysis

```python
def analyze_financial_impact(player, squad_budget):
    """
    Returns: FinancialAnalysis

    FinancialAnalysis:
        estimated_value: int
        weekly_wages: int
        wage_efficiency: float
        wage_budget_percentage: float
        wage_vs_contribution_ratio: float
        recommendation: str
    """
```

### D. Squad Balance Check

```python
def check_squad_balance_impact(player, squad):
    """
    Returns: BalanceImpact

    BalanceImpact:
        positions_affected: List[str]
        depth_warnings: List[str]
        registration_impact: str
        blocking_issue: bool
        blocking_reason: str or None
    """
```

### E. Protection Rules

```python
def apply_protection_rules(player, squad, config):
    """
    Returns: ProtectionStatus

    ProtectionStatus:
        is_protected: bool
        protection_type: str or None
        override_possible: bool
        reason: str
    """
```

**Protection Configuration**:
| Rule | Default | Adjustable |
|------|---------|------------|
| Top N by contribution | 15 | Yes |
| Youth PA threshold | 150 | Yes |
| Recent signing period | 6 months | Yes |
| Sole position coverage | Automatic | No |

### F. Removal Decision Algorithm

```python
def recommend_player_removal(players, squad, config):
    """
    Returns: List[RemovalRecommendation]

    RemovalRecommendation:
        player: Player
        action: str ('sell', 'loan', 'release', 'keep')
        priority: int (1=highest)
        confidence: str ('high', 'medium', 'low')
        reason: str
        estimated_fee: int (for sell)
        wage_savings: int
        considerations: List[str]
    """
```

### G. UI Output Format

```json
{
  "removal_candidates": [
    {
      "player": "Player Name",
      "action": "Sell",
      "priority": 1,
      "reason": "High wages (120k/w) for limited contribution; 4th choice CM",
      "estimated_fee": "£15M",
      "wage_savings": "£6.2M/year",
      "considerations": [
        "Approaching 30, value will decline",
        "Interested clubs: Team A, Team B"
      ],
      "confidence": "high"
    }
  ],
  "protected_players": [
    {
      "player": "Star Player",
      "protection_reason": "Top 5 contributor, no adequate backup"
    }
  ],
  "squad_health": {
    "size": 28,
    "target_size": 25,
    "overstaffed_positions": ["CM", "CB"],
    "understaffed_positions": ["LB"]
  }
}
```

### H. Decision Tree Visualization

```
                    ┌─────────────┐
                    │ Is Protected?│
                    └──────┬──────┘
                      No   │   Yes
              ┌────────────┴────────────┐
              ▼                         ▼
        ┌───────────┐            ┌─────────────┐
        │ Below Depth│            │ KEEP (protected)│
        │ Threshold? │            └─────────────┘
        └─────┬─────┘
          Yes │ No
              ▼
        ┌───────────────┐
        │ Financial Ratio│
        │ Acceptable?    │
        └───────┬───────┘
           Yes  │  No
                ▼
          ┌───────────┐
          │ Age/Value │
          │ Analysis  │
          └─────┬─────┘
                ▼
        [SELL/LOAN/RELEASE]
```

## Validation Criteria

The removal model is successful if:
- Never recommends removing player that creates critical gap
- Identifies overpaid/underperforming players correctly
- Distinguishes between sell, loan, and release appropriately
- Protects youth with high potential
- Recommendations align with typical FM sporting director behavior

## Output Format

1. **Contribution Algorithm**: Complete formula with weights
2. **Future Value Model**: Age curves and PA analysis
3. **Financial Formulas**: Efficiency calculations
4. **Balance Checks**: Depth requirements
5. **Protection Rules**: Complete configuration
6. **Decision Tree**: Full logic flow
7. **UI Specification**: Output data structures
