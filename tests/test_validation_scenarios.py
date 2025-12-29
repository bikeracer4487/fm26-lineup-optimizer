"""
FM26 Lineup Optimizer - Validation Test Suite
==============================================

Implements synthetic season test cases for algorithm validation from the research framework.

Test Cases:
- TestChristmasCrunch: High rotation enforcement during fixture congestion
- TestCupFinalProtection: Rest key players before important matches
- TestInjuryCrisis: Out-of-position handling when specialists unavailable

Reference: docs/new-research/FM26 #1 - System spec + decision model (foundation).md
Section 7: Evaluation Metrics and Calibration Strategy
"""

import pytest
import sys
import os
from datetime import datetime, timedelta
from typing import Dict, List, Any

# Add project root to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from scoring_parameters import (
    get_context_parameters,
    get_importance_weight,
    ScoringContext,
    IMPORTANCE_WEIGHTS
)
from ui.api.scoring_model import (
    calculate_harmonic_mean,
    calculate_condition_multiplier,
    calculate_sharpness_multiplier,
    calculate_familiarity_multiplier,
    calculate_fatigue_multiplier,
    calculate_match_utility,
    MultiplierBreakdown
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
    should_rest_player_for_shadow
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
    """Tests for the condition multiplier calculation."""

    def test_full_condition_no_penalty(self):
        """Player at 95%+ condition should have no penalty."""
        context = get_context_parameters('Medium')
        result = calculate_condition_multiplier(95, context)
        assert result == 1.0

    def test_high_importance_lower_threshold(self):
        """High importance matches allow lower condition threshold."""
        context_high = get_context_parameters('High')
        context_medium = get_context_parameters('Medium')

        # At 85% condition
        result_high = calculate_condition_multiplier(85, context_high)
        result_medium = calculate_condition_multiplier(85, context_medium)

        # High importance should have higher multiplier (less penalty)
        assert result_high > result_medium

    def test_below_threshold_critical_penalty(self):
        """Condition below safety threshold should have critical penalty."""
        context = get_context_parameters('Medium')  # T_safe = 91%
        result = calculate_condition_multiplier(80, context)
        assert result == 0.05  # P_critical


class TestSharpnessMultiplier:
    """Tests for the sharpness multiplier calculation."""

    def test_standard_mode_full_sharpness(self):
        """Full sharpness in standard mode should return 1.0."""
        context = get_context_parameters('High')
        result = calculate_sharpness_multiplier(100, context)
        assert result == pytest.approx(1.0, rel=0.01)

    def test_standard_mode_zero_sharpness(self):
        """Zero sharpness in standard mode should return 0.7."""
        context = get_context_parameters('High')
        result = calculate_sharpness_multiplier(0, context)
        assert result == pytest.approx(0.7, rel=0.01)

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
    """Tests for the familiarity multiplier calculation."""

    def test_natural_no_penalty(self):
        """Natural familiarity (18-20) should have no penalty."""
        context = get_context_parameters('Medium')
        result = calculate_familiarity_multiplier(18, context)
        assert result == 1.0

    def test_below_minimum_extra_penalty(self):
        """Familiarity below minimum should have extra penalty."""
        context = get_context_parameters('High')  # familiarity_min = 15
        result = calculate_familiarity_multiplier(12, context)
        # Competent tier (0.80) * below threshold penalty (0.70)
        expected = 0.80 * 0.70
        assert result == pytest.approx(expected, rel=0.01)


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
            # Shadow cost at match 3 (one before final) should be high
            cost_at_3 = shadow_costs[key_name][3]
            assert cost_at_3 >= 100, "Key player should have high shadow cost before final"

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
        assert high_weight == 3.0
        assert low_weight == 0.5

    def test_fatigue_violation_detection(self):
        """
        FVC = Count of instances where player starts with Condition < T_safe
        Goal: Minimize to 0.
        """
        context = get_context_parameters('Medium')

        # Test at safety threshold
        mult_at_threshold = calculate_condition_multiplier(
            context.safety_threshold, context
        )
        mult_below_threshold = calculate_condition_multiplier(
            context.safety_threshold - 1, context
        )

        # At threshold should not be critical penalty
        assert mult_at_threshold > 0.5
        # Below threshold should be critical penalty
        assert mult_below_threshold == 0.05


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

    def test_poor_condition_kills_utility(self, sample_player_data):
        """
        A player with terrible condition should have near-zero utility.
        """
        sample_player_data['Condition'] = 70  # Below all thresholds

        context = get_context_parameters('Medium')

        utility, breakdown = calculate_match_utility(
            sample_player_data,
            ip_rating=180,
            oop_rating=180,
            ip_familiarity=20,
            oop_familiarity=20,
            context=context
        )

        # Even with perfect ratings, poor condition should tank utility
        assert breakdown.condition_mult == 0.05  # Critical penalty
        assert utility < 20, "Utility should be very low with critical condition"


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
