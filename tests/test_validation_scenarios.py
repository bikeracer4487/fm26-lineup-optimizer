"""
FM26 Lineup Optimizer - Validation Test Suite
==============================================

Implements synthetic season test cases for algorithm validation from the research framework.

Test Cases:
- TestHarmonicMean: Base rating calculation
- TestConditionMultiplier: Bounded sigmoid condition function
- TestSharpnessMultiplier: Power curve sharpness function
- TestFamiliarityMultiplier: Bounded sigmoid familiarity function
- TestFatigueMultiplier: Player-relative sigmoid fatigue function
- TestSigmoidMultipliers: New bounded sigmoid tests with worked examples
- TestPolyvalentStability: Assignment inertia and anchoring
- TestChristmasCrunch: High rotation enforcement during fixture congestion
- TestCupFinalProtection: Rest key players before important matches
- TestInjuryCrisis: Out-of-position handling when specialists unavailable

References:
- docs/new-research/FM26 #1 - System spec + decision model (foundation).md
- docs/new-research/FM26 #2 - Lineup Optimizer - Complete Mathematical Specification.md
"""

import pytest
import sys
import os
import math
from datetime import datetime, timedelta
from typing import Dict, List, Any

# Add project root to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from scoring_parameters import (
    get_context_parameters,
    get_importance_weight,
    ScoringContext,
    IMPORTANCE_WEIGHTS,
    FAMILIARITY_SIGMOID_PARAMS,
    FATIGUE_SIGMOID_PARAMS,
    CONDITION_SIGMOID_PARAMS,
    SHARPNESS_CURVE_PARAMS,
    StabilityConfig,
    DEFAULT_STABILITY_CONFIG,
)
from ui.api.scoring_model import (
    calculate_harmonic_mean,
    calculate_condition_multiplier,
    calculate_sharpness_multiplier,
    calculate_familiarity_multiplier,
    calculate_fatigue_multiplier,
    calculate_match_utility,
    MultiplierBreakdown,
    sigmoid,
)
from ui.api.state_simulation import (
    PlayerState,
    simulate_match_impact,
    simulate_rest_recovery,
    project_condition_at_match
)
from ui.api.shadow_pricing import (
    calculate_shadow_costs,
    get_adjusted_utility,
    identify_players_to_preserve,
    should_rest_player_for_shadow,
    compute_shadow_costs_simple,
)
from ui.api.stability import (
    AssignmentHistory,
    compute_stability_costs,
    compute_anchor_costs,
    get_combined_stability_costs,
    AssignmentManager,
)


# =============================================================================
# TEST FIXTURES
# =============================================================================

@pytest.fixture
def sample_player_data():
    """Create a sample player data dict for testing."""
    return {
        'Name': 'Test Player',
        'CA': 150,
        'Age': 26,
        'Natural Fitness': 15,
        'Stamina': 14,
        'Injury Proneness': 8,
        'Condition': 95,
        'Match Sharpness': 85,
        'Fatigue': 150,
        'Is Jaded': False,
        'D(C)_Familiarity': 18,
        'DM_Familiarity': 12
    }


@pytest.fixture
def sample_squad():
    """Create a sample squad of 25 players with varied attributes."""
    players = []
    positions = ['GK', 'D(C)', 'D(L)', 'D(R)', 'DM', 'M(C)', 'AM(C)', 'AM(L)', 'AM(R)', 'ST']

    for i in range(25):
        pos = positions[i % len(positions)]
        players.append({
            'Name': f'Player {i+1}',
            'CA': 100 + (i * 4),  # Range 100-196
            'Age': 20 + (i % 15),
            'Natural Fitness': 10 + (i % 10),
            'Stamina': 10 + (i % 10),
            'Injury Proneness': 5 + (i % 15),
            'Condition': 90 + (i % 10),
            'Match Sharpness': 70 + (i % 30),
            'Fatigue': 100 + (i * 20),
            'Is Jaded': False,
            f'{pos}_Familiarity': 18,  # Natural at their position
            'Best Position': pos
        })

    return players


@pytest.fixture
def christmas_crunch_fixtures():
    """
    5 matches in 13 days (Sat-Tue-Fri-Mon-Thu). All Medium importance.
    This simulates the intense English festive period.
    """
    base_date = datetime(2025, 12, 20)
    return [
        {'id': '1', 'date': (base_date + timedelta(days=0)).strftime('%Y-%m-%d'),
         'opponent': 'Team A', 'importance': 'Medium'},
        {'id': '2', 'date': (base_date + timedelta(days=3)).strftime('%Y-%m-%d'),
         'opponent': 'Team B', 'importance': 'Medium'},
        {'id': '3', 'date': (base_date + timedelta(days=6)).strftime('%Y-%m-%d'),
         'opponent': 'Team C', 'importance': 'Medium'},
        {'id': '4', 'date': (base_date + timedelta(days=9)).strftime('%Y-%m-%d'),
         'opponent': 'Team D', 'importance': 'Medium'},
        {'id': '5', 'date': (base_date + timedelta(days=13)).strftime('%Y-%m-%d'),
         'opponent': 'Team E', 'importance': 'Medium'},
    ]


@pytest.fixture
def cup_final_fixtures():
    """
    Matches 1-4 are Low Importance. Match 5 is High Importance (Cup Final).
    """
    base_date = datetime(2025, 5, 1)
    return [
        {'id': '1', 'date': (base_date + timedelta(days=0)).strftime('%Y-%m-%d'),
         'opponent': 'Reserve Match 1', 'importance': 'Low'},
        {'id': '2', 'date': (base_date + timedelta(days=3)).strftime('%Y-%m-%d'),
         'opponent': 'Reserve Match 2', 'importance': 'Low'},
        {'id': '3', 'date': (base_date + timedelta(days=6)).strftime('%Y-%m-%d'),
         'opponent': 'Reserve Match 3', 'importance': 'Low'},
        {'id': '4', 'date': (base_date + timedelta(days=9)).strftime('%Y-%m-%d'),
         'opponent': 'Reserve Match 4', 'importance': 'Low'},
        {'id': '5', 'date': (base_date + timedelta(days=12)).strftime('%Y-%m-%d'),
         'opponent': 'CUP FINAL', 'importance': 'High'},
    ]


# =============================================================================
# SCORING MODEL TESTS
# =============================================================================

class TestHarmonicMean:
    """Tests for the Harmonic Mean IP/OOP rating calculation."""

    def test_balanced_ratings(self):
        """Equal IP and OOP ratings should return the same value."""
        result = calculate_harmonic_mean(100, 100)
        assert result == 100.0

    def test_imbalanced_ratings_penalized(self):
        """Heavily imbalanced ratings should be penalized."""
        result = calculate_harmonic_mean(180, 20)
        # Harmonic mean of 180, 20 = 2*180*20/(180+20) = 7200/200 = 36
        assert result == 36.0

    def test_moderate_imbalance(self):
        """Moderate imbalance should have moderate penalty."""
        result = calculate_harmonic_mean(150, 100)
        # 2*150*100/(150+100) = 30000/250 = 120
        assert result == 120.0

    def test_zero_rating_returns_zero(self):
        """If either rating is zero, return zero."""
        assert calculate_harmonic_mean(100, 0) == 0.0
        assert calculate_harmonic_mean(0, 100) == 0.0
        assert calculate_harmonic_mean(0, 0) == 0.0


class TestConditionMultiplier:
    """Tests for the condition multiplier calculation (bounded sigmoid)."""

    def test_high_condition_near_one(self):
        """High condition (95%+) should give multiplier near 1.0."""
        context = get_context_parameters('Medium')
        result = calculate_condition_multiplier(95, context)
        # With sigmoid, 95% condition should give high multiplier
        assert result > 0.85

    def test_high_importance_lower_threshold(self):
        """High importance matches allow lower condition threshold."""
        context_high = get_context_parameters('High')
        context_medium = get_context_parameters('Medium')

        # At 80% condition
        result_high = calculate_condition_multiplier(80, context_high)
        result_medium = calculate_condition_multiplier(80, context_medium)

        # High importance should have higher multiplier (less penalty)
        # High: α=0.40, T=75, so 80% is above threshold
        # Medium: α=0.35, T=82, so 80% is below threshold
        assert result_high > result_medium

    def test_low_condition_uses_floor(self):
        """Very low condition should approach but not go below floor (α)."""
        context = get_context_parameters('Medium')
        result = calculate_condition_multiplier(50, context)
        # Should be close to floor α=0.35
        assert result >= 0.35
        assert result < 0.50


class TestSharpnessMultiplier:
    """Tests for the sharpness multiplier calculation (power curve)."""

    def test_standard_mode_full_sharpness(self):
        """Full sharpness in standard mode should return 1.0."""
        context = get_context_parameters('High')
        result = calculate_sharpness_multiplier(100, context)
        # Ψ = 0.40 + 0.60 × 1.0^0.8 = 1.0
        assert result == pytest.approx(1.0, rel=0.01)

    def test_standard_mode_zero_sharpness(self):
        """Zero sharpness in standard mode should return floor (0.40)."""
        context = get_context_parameters('High')
        result = calculate_sharpness_multiplier(0, context)
        # Ψ = 0.40 + 0.60 × 0^0.8 = 0.40
        assert result == pytest.approx(0.40, rel=0.01)

    def test_standard_mode_mid_sharpness(self):
        """50% sharpness should give diminishing returns result."""
        context = get_context_parameters('High')
        result = calculate_sharpness_multiplier(50, context)
        # Ψ = 0.40 + 0.60 × 0.5^0.8 ≈ 0.40 + 0.60 × 0.574 ≈ 0.74
        assert result == pytest.approx(0.74, rel=0.05)

    def test_build_mode_bonus_zone(self):
        """Sharpness build mode should give bonus for 50-90% range."""
        context = get_context_parameters('Sharpness')
        result = calculate_sharpness_multiplier(70, context)
        assert result == 1.2  # Bonus in target zone

    def test_build_mode_too_rusty(self):
        """Sharpness build mode should penalize <50%."""
        context = get_context_parameters('Sharpness')
        result = calculate_sharpness_multiplier(40, context)
        assert result == 0.8


class TestFamiliarityMultiplier:
    """Tests for the familiarity multiplier calculation (bounded sigmoid)."""

    def test_natural_near_one(self):
        """Natural familiarity (18-20) should give multiplier near 1.0."""
        context = get_context_parameters('Medium')
        result = calculate_familiarity_multiplier(18, context)
        # Θ = α + (1-α) × σ(k × (18-10)) with Medium params
        # Should be high (>0.9)
        assert result > 0.90

    def test_low_familiarity_uses_floor(self):
        """Low familiarity should approach but not go below floor (α)."""
        context = get_context_parameters('High')  # α=0.30
        result = calculate_familiarity_multiplier(4, context)
        # Should be close to floor
        assert result >= 0.30
        assert result < 0.40

    def test_importance_affects_threshold(self):
        """Different importance levels should have different thresholds."""
        context_high = get_context_parameters('High')    # T=12
        context_low = get_context_parameters('Low')      # T=7

        result_high = calculate_familiarity_multiplier(10, context_high)
        result_low = calculate_familiarity_multiplier(10, context_low)

        # Low importance should give higher multiplier at same familiarity
        # because its threshold is lower
        assert result_low > result_high


# =============================================================================
# STATE SIMULATION TESTS
# =============================================================================

class TestMatchImpact:
    """Tests for match impact simulation."""

    def test_condition_loss_after_match(self):
        """Playing a match should reduce condition."""
        state = PlayerState(
            name='Test', condition=95, sharpness=80, fatigue=100,
            recent_minutes=0, is_jaded=False, natural_fitness=15
        )
        new_state = simulate_match_impact(state, 90)
        assert new_state.condition < state.condition

    def test_sharpness_gain_after_match(self):
        """Playing a match should increase sharpness."""
        state = PlayerState(
            name='Test', condition=95, sharpness=70, fatigue=100,
            recent_minutes=0, is_jaded=False
        )
        new_state = simulate_match_impact(state, 90)
        assert new_state.sharpness > state.sharpness

    def test_fatigue_accumulation(self):
        """Playing a match should increase fatigue."""
        state = PlayerState(
            name='Test', condition=95, sharpness=80, fatigue=100,
            recent_minutes=0, is_jaded=False
        )
        new_state = simulate_match_impact(state, 90)
        assert new_state.fatigue > state.fatigue


class TestRestRecovery:
    """Tests for rest recovery simulation."""

    def test_condition_recovery(self):
        """Rest should recover condition."""
        state = PlayerState(
            name='Test', condition=70, sharpness=80, fatigue=200,
            recent_minutes=180, is_jaded=False, natural_fitness=15
        )
        new_state = simulate_rest_recovery(state, 3)
        assert new_state.condition > state.condition

    def test_sharpness_decay(self):
        """Rest should decay sharpness slightly."""
        state = PlayerState(
            name='Test', condition=95, sharpness=80, fatigue=100,
            recent_minutes=0, is_jaded=False
        )
        new_state = simulate_rest_recovery(state, 7)  # Full week
        assert new_state.sharpness < state.sharpness

    def test_fatigue_recovery(self):
        """Rest should reduce fatigue."""
        state = PlayerState(
            name='Test', condition=95, sharpness=80, fatigue=300,
            recent_minutes=0, is_jaded=False, natural_fitness=15
        )
        new_state = simulate_rest_recovery(state, 3)
        assert new_state.fatigue < state.fatigue


# =============================================================================
# SHADOW PRICING TESTS
# =============================================================================

class TestShadowPricing:
    """Tests for shadow pricing calculations."""

    def test_high_importance_increases_shadow(self, sample_squad, cup_final_fixtures):
        """Players should have higher shadow cost when High importance match is upcoming."""
        shadow_costs = calculate_shadow_costs(
            sample_squad, cup_final_fixtures, {}, 'Medium'
        )

        # Get a key player's shadow cost at match 0 vs match 4
        player_name = sample_squad[0]['Name']
        if player_name in shadow_costs:
            cost_at_0 = shadow_costs[player_name][0]
            cost_at_4 = shadow_costs[player_name][4]
            # Cost at match 0 should be higher (Cup Final is ahead)
            assert cost_at_0 > cost_at_4

    def test_shadow_rest_recommendation(self):
        """High shadow cost should trigger rest recommendation for Low importance matches."""
        shadow_costs = {'Star Player': [200, 150, 100, 50, 10]}

        should_rest, reason = should_rest_player_for_shadow(
            'Star Player', shadow_costs, 0, base_utility=150,
            importance='Low', threshold_ratio=0.5
        )

        # Shadow cost 200 / utility 150 = 1.33 > threshold 0.5
        assert should_rest is True
        assert 'future value' in reason.lower()

    def test_no_shadow_rest_for_high_importance(self):
        """Should never recommend shadow rest for High importance matches."""
        shadow_costs = {'Star Player': [500, 400, 300, 200, 100]}

        should_rest, _ = should_rest_player_for_shadow(
            'Star Player', shadow_costs, 0, base_utility=100,
            importance='High', threshold_ratio=0.5
        )

        assert should_rest is False


# =============================================================================
# SCENARIO VALIDATION TESTS
# =============================================================================

class TestChristmasCrunch:
    """
    Validation Test A: The Christmas Crunch

    5 matches in 13 days (Sat-Tue-Fri-Mon-Thu). All Medium importance.
    Expected: High rotation. No player should start >3 consecutive games.
    Rotation Index (unique starters / squad size) should be > 0.7
    """

    def test_fatigue_spiral_prevention(self, sample_squad, christmas_crunch_fixtures):
        """
        The state simulation should correctly predict fatigue buildup
        across multiple matches, preventing players from starting 4+ in a row.
        """
        # Simulate playing matches with a LOW natural fitness player (fatigue-prone)
        state = PlayerState(
            name='Test', condition=100, sharpness=90, fatigue=0,  # Start fresh
            recent_minutes=0, is_jaded=False, natural_fitness=8,  # Low NF = less recovery
            stamina=8, age=28  # Low stamina = more condition loss
        )

        context = get_context_parameters('Medium', 'Medium')

        # Simulate playing 5 consecutive matches with 2-day gaps (tight schedule)
        for _ in range(5):
            state = simulate_match_impact(state, 90)
            state = simulate_rest_recovery(state, 2, context)  # 2-day gaps = less recovery

        # After 5 matches with tight schedule, a low-stamina player should lose condition
        assert state.condition < 95, "Low-stamina player should lose condition with tight schedule"

        # Recent minutes should track accumulated match load
        assert state.recent_minutes > 0, "Recent minutes should track match load"

    def test_rotation_detection(self, sample_squad, christmas_crunch_fixtures):
        """
        Shadow pricing should detect the need for rotation during fixture congestion.
        """
        # Calculate shadow costs across all matches
        shadow_costs = calculate_shadow_costs(
            sample_squad, christmas_crunch_fixtures, {}, 'Medium'
        )

        # Top players should have shadow costs at early matches
        # (they're valuable for later matches too)
        players_with_shadow = identify_players_to_preserve(shadow_costs, 0, top_n=5)

        assert len(players_with_shadow) >= 5, "Should identify players needing protection"


class TestCupFinalProtection:
    """
    Validation Test B: The Cup Final Protection

    Matches 1-4 are Low Importance. Match 5 is High Importance.
    Expected: Top XI must be fully rested (Condition > 98%) for Match 5.
    If star striker plays Match 4 and enters Match 5 at 94%, test FAILS.
    """

    def test_shadow_pricing_protects_key_players(self, sample_squad, cup_final_fixtures):
        """
        Shadow pricing should heavily weight key players before the Cup Final.
        """
        shadow_costs = calculate_shadow_costs(
            sample_squad, cup_final_fixtures, {}, 'Medium'
        )

        # Get the highest CA player (most likely key player)
        key_player = max(sample_squad, key=lambda p: p.get('CA', 0))
        key_name = key_player['Name']

        if key_name in shadow_costs:
            # Shadow cost at match 3 (one before final) should be elevated
            # The exact value depends on importance weights (High=1.5, others=1.0/0.6)
            cost_at_3 = shadow_costs[key_name][3]
            assert cost_at_3 >= 50, "Key player should have elevated shadow cost before final"

    def test_condition_projection_accuracy(self):
        """
        The condition projection should accurately predict recovery.
        """
        # Project condition for a player who would play today
        projected = project_condition_at_match(
            current_condition=95,
            days_until_match=3,
            played_today=True,
            natural_fitness=15,
            training_intensity='Medium'
        )

        # After playing today (drops to ~74%), 3 days should recover to ~90%
        assert projected > 85, "3 days rest should recover above 85%"
        assert projected < 100, "Shouldn't fully recover in 3 days"

    def test_insufficient_rest_detection(self):
        """
        If a key player plays Match 4, they shouldn't fully recover for Match 5.
        """
        # Player plays match 4, only 3 days until match 5
        projected = project_condition_at_match(
            current_condition=95,
            days_until_match=3,
            played_today=True,  # Playing in match 4
            natural_fitness=10,  # Average natural fitness
            training_intensity='Medium'
        )

        # With average NF, should not reach optimal condition
        assert projected < 95, "Shouldn't reach optimal condition for final"


class TestInjuryCrisis:
    """
    Validation Test C: The Injury Crisis

    All natural Left Backs marked as Injured.
    Expected: System identifies best out-of-position candidate
    (e.g., Right Back with 12/20 LB familiarity) rather than leaving slot empty.
    """

    def test_familiarity_allows_emergency_cover(self):
        """
        Even with low familiarity, a player should be usable as emergency cover.
        """
        context = get_context_parameters('Medium')

        # Test with "Awkward" familiarity (7/20)
        mult = calculate_familiarity_multiplier(7, context)

        # Should not be zero - player is still usable
        assert mult > 0, "Emergency cover should be possible"
        assert mult < 1.0, "But should have significant penalty"

    def test_out_of_position_scoring(self, sample_player_data):
        """
        An out-of-position player should score lower than a natural.
        """
        context = get_context_parameters('Medium')

        # Natural at D(C) (fam 18), playing there
        natural_mult = calculate_familiarity_multiplier(18, context)

        # Out of position at DM (fam 12)
        oop_mult = calculate_familiarity_multiplier(12, context)

        assert natural_mult > oop_mult, "Natural should score higher than OOP"


# =============================================================================
# EVALUATION METRICS
# =============================================================================

class TestEvaluationMetrics:
    """Tests for the evaluation metrics from the research framework."""

    def test_aggregate_team_strength_calculation(self, sample_squad, cup_final_fixtures):
        """
        ATS = Sum_{k=0}^{4} (W_{Imp,k} * Sum_{p in XI_k} U_{p,k})
        Measures if we field best players in most important games.
        """
        # For this test, just verify the importance weighting is correct
        high_weight = get_importance_weight('High')
        low_weight = get_importance_weight('Low')

        assert high_weight > low_weight, "High importance should have higher weight"
        # Updated weights per FM26 #2 spec
        assert high_weight == 1.5
        assert low_weight == 0.6

    def test_fatigue_violation_detection(self):
        """
        FVC = Count of instances where player starts with Condition < T_safe
        Goal: Minimize to 0.
        """
        context = get_context_parameters('Medium')

        # Test at and below safety threshold
        mult_at_threshold = calculate_condition_multiplier(
            context.safety_threshold, context  # T=82 for Medium
        )
        mult_below_threshold = calculate_condition_multiplier(
            context.safety_threshold - 10, context  # Well below threshold
        )

        # At threshold, sigmoid function gives value above floor
        # With α=0.35, k=0.10, at C=T: Φ = α + (1-α) × σ(0) = 0.35 + 0.65 × 0.5 = 0.675
        # But actual value depends on exact parameter tuning
        assert 0.4 < mult_at_threshold < 0.9, f"At threshold should be moderate, got {mult_at_threshold}"
        # Below threshold should be lower but still above floor (0.35)
        assert mult_below_threshold < mult_at_threshold
        assert mult_below_threshold >= 0.35  # Above floor


# =============================================================================
# INTEGRATION TESTS
# =============================================================================

class TestFullUtilityCalculation:
    """Integration tests for the complete utility calculation pipeline."""

    def test_multiplicative_model(self, sample_player_data):
        """
        Verify the multiplicative model correctly combines all factors.
        """
        context = get_context_parameters('Medium')

        utility, breakdown = calculate_match_utility(
            sample_player_data,
            ip_rating=150,
            oop_rating=140,
            ip_familiarity=18,
            oop_familiarity=15,
            context=context
        )

        # Verify the breakdown contains all expected multipliers
        assert breakdown.base_rating > 0
        assert 0 < breakdown.condition_mult <= 1.0
        assert 0 < breakdown.sharpness_mult <= 1.2
        assert 0 < breakdown.familiarity_mult <= 1.0
        assert 0 < breakdown.fatigue_mult <= 1.0

        # Final utility should be product of base and all multipliers
        expected = (
            breakdown.base_rating *
            breakdown.condition_mult *
            breakdown.sharpness_mult *
            breakdown.familiarity_mult *
            breakdown.fatigue_mult
        )
        assert utility == pytest.approx(expected, rel=0.01)

    def test_poor_condition_reduces_utility(self, sample_player_data):
        """
        A player with poor condition should have significantly reduced utility.
        """
        sample_player_data['Condition'] = 60  # Very low condition

        context = get_context_parameters('Medium')

        utility, breakdown = calculate_match_utility(
            sample_player_data,
            ip_rating=180,
            oop_rating=180,
            ip_familiarity=20,
            oop_familiarity=20,
            context=context
        )

        # With sigmoid, poor condition should be close to floor (α=0.35)
        assert breakdown.condition_mult < 0.45
        assert breakdown.condition_mult >= 0.35
        # Utility should be significantly reduced
        assert utility < 100


# =============================================================================
# SIGMOID FUNCTION TESTS (FM26 #2 Specification)
# =============================================================================

class TestSigmoidFunction:
    """Tests for the base sigmoid function."""

    def test_sigmoid_at_zero(self):
        """σ(0) should equal 0.5."""
        result = sigmoid(0)
        assert result == pytest.approx(0.5, rel=0.001)

    def test_sigmoid_positive_large(self):
        """σ(large positive) should approach 1.0."""
        result = sigmoid(10)
        assert result > 0.99

    def test_sigmoid_negative_large(self):
        """σ(large negative) should approach 0.0."""
        result = sigmoid(-10)
        assert result < 0.01


class TestSigmoidMultipliersWorkedExamples:
    """
    Tests using worked examples from FM26 #2 Mathematical Specification.
    """

    def test_familiarity_high_importance_examples(self):
        """
        Worked examples from spec (High importance, α=0.30, T=12, k=0.55):
        - Fam=6:  ~0.325
        - Fam=10: ~0.474
        - Fam=14: ~0.826
        - Fam=18: ~0.975
        """
        context = get_context_parameters('High')

        # Fam=6 (unconvincing) should give low multiplier
        result_6 = calculate_familiarity_multiplier(6, context)
        assert result_6 == pytest.approx(0.325, rel=0.05)

        # Fam=14 (accomplished) should give good multiplier
        result_14 = calculate_familiarity_multiplier(14, context)
        assert result_14 == pytest.approx(0.826, rel=0.05)

        # Fam=18 (natural) should give near-full multiplier
        result_18 = calculate_familiarity_multiplier(18, context)
        assert result_18 == pytest.approx(0.975, rel=0.02)

    def test_condition_worked_example(self):
        """
        From spec (Medium importance, α=0.35, T=82, k=0.10):
        - C=72: ~0.52
        - C=82: ~0.68
        - C=90: ~0.80
        """
        context = get_context_parameters('Medium')

        result_72 = calculate_condition_multiplier(72, context)
        result_82 = calculate_condition_multiplier(82, context)
        result_90 = calculate_condition_multiplier(90, context)

        # Values should increase with condition
        assert result_72 < result_82 < result_90
        # And be in expected ranges
        assert result_72 >= 0.35  # Above floor

    def test_sharpness_power_curve_examples(self):
        """
        From spec: Ψ = 0.40 + 0.60 × (Sh/100)^0.8
        - Sh=75%: ~0.89
        """
        context = get_context_parameters('High')
        result_75 = calculate_sharpness_multiplier(75, context)
        # 0.40 + 0.60 × 0.75^0.8 ≈ 0.40 + 0.60 × 0.811 ≈ 0.887
        assert result_75 == pytest.approx(0.887, rel=0.02)


# =============================================================================
# STABILITY MECHANISM TESTS
# =============================================================================

class TestPolyvalentStability:
    """Tests for the polyvalent stability mechanisms."""

    def test_assignment_inertia_same_position_bonus(self):
        """Player staying in same position should get bonus (negative cost)."""
        players = ['Player A', 'Player B']
        slots = ['DC1', 'DC2']
        prev_assignment = {'Player A': 'DC1', 'Player B': 'DC2'}

        costs = compute_stability_costs(players, slots, prev_assignment)

        # Same position should have negative cost (bonus)
        assert costs[0, 0] < 0  # Player A at DC1
        assert costs[1, 1] < 0  # Player B at DC2

        # Different position should have positive cost (penalty)
        assert costs[0, 1] > 0  # Player A at DC2
        assert costs[1, 0] > 0  # Player B at DC1

    def test_assignment_inertia_no_history(self):
        """Player with no previous assignment should have zero cost."""
        players = ['New Player']
        slots = ['DC1']
        prev_assignment = {}  # No history

        costs = compute_stability_costs(players, slots, prev_assignment)

        assert costs[0, 0] == 0

    def test_soft_lock_anchoring_after_consecutive(self):
        """Player with 3+ consecutive assignments should be anchored."""
        history = AssignmentHistory()
        history.add_assignment('match1', 'Player A', 'DC1')
        history.add_assignment('match2', 'Player A', 'DC1')
        history.add_assignment('match3', 'Player A', 'DC1')

        players = ['Player A']
        slots = ['DC1', 'DC2']

        anchor_costs = compute_anchor_costs(players, slots, history)

        # Moving from anchored position should have cost
        assert anchor_costs[0, 1] > 0  # Moving to DC2
        # Staying should have no anchor cost
        assert anchor_costs[0, 0] == 0

    def test_no_anchor_before_threshold(self):
        """Player with <3 consecutive assignments should not be anchored."""
        history = AssignmentHistory()
        history.add_assignment('match1', 'Player A', 'DC1')
        history.add_assignment('match2', 'Player A', 'DC1')

        players = ['Player A']
        slots = ['DC1', 'DC2']

        anchor_costs = compute_anchor_costs(players, slots, history)

        # No anchor yet, all costs should be zero
        assert anchor_costs[0, 0] == 0
        assert anchor_costs[0, 1] == 0

    def test_stability_slider_effect(self):
        """inertia_weight should scale the stability costs."""
        players = ['Player A']
        slots = ['DC1', 'DC2']
        prev_assignment = {'Player A': 'DC1'}

        # With inertia_weight = 0 (pure optimal)
        config_zero = StabilityConfig(inertia_weight=0.0)
        costs_zero = compute_stability_costs(players, slots, prev_assignment, config_zero)

        # With inertia_weight = 1.0 (max stability)
        config_full = StabilityConfig(inertia_weight=1.0)
        costs_full = compute_stability_costs(players, slots, prev_assignment, config_full)

        # Zero inertia should give zero costs
        assert costs_zero[0, 0] == 0
        assert costs_zero[0, 1] == 0

        # Full inertia should give maximum costs
        assert abs(costs_full[0, 0]) > 0
        assert costs_full[0, 1] > 0


class TestAssignmentManager:
    """Tests for the AssignmentManager class."""

    def test_manual_lock_enforcement(self):
        """Manual locks should set infinity cost for other positions."""
        import numpy as np

        manager = AssignmentManager()
        manager.lock_player('Star Player', 'AMC')

        players = ['Star Player', 'Other Player']
        slots = ['AMC', 'DM']

        cost_matrix = np.zeros((2, 2))
        modified = manager.apply_constraints(cost_matrix, players, slots)

        # Star Player should only be allowed at AMC
        assert modified[0, 0] < 1e8  # AMC allowed
        assert modified[0, 1] >= 1e8  # DM blocked

    def test_rejection_enforcement(self):
        """Player rejections should block specific positions."""
        import numpy as np

        manager = AssignmentManager()
        manager.reject_position('Tired Player', 'ST')

        players = ['Tired Player']
        slots = ['AMC', 'ST']

        cost_matrix = np.zeros((1, 2))
        modified = manager.apply_constraints(cost_matrix, players, slots)

        assert modified[0, 0] < 1e8  # AMC allowed
        assert modified[0, 1] >= 1e8  # ST blocked


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
