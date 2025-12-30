"""
FM26 Match Importance API (AMICS)
=================================

Automated Match Importance Classification System based on Step 9 research.

Key Features (Step 9 Research):
1. FIS Formula: FIS = (Base x M_opp x M_sched x M_user) + B_context
2. Base Importance Table: Competition/stage-based starting scores
3. Opponent Modifiers: Strength-based adjustments (Titan to Minnow)
4. Schedule Modifiers: 72-hour rule, ACWR-based congestion handling
5. Context Bonuses: Derby, form correction, cup run
6. Manager Profiles: Customizable competition weights
7. Sharpness Detection: Identifies opportunities for match fitness

References:
- docs/new-research/09-RESULTS-match-importance.md (Step 9 Research)
- docs/new-research/12-IMPLEMENTATION-PLAN.md (consolidated specification)
"""

import sys
import os
from typing import Dict, List, Tuple, Optional, Any
from dataclasses import dataclass

# Add root directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

# Import Step 9 parameters from scoring_parameters
from scoring_parameters import (
    BASE_IMPORTANCE,
    get_base_importance,
    OPPONENT_MODIFIERS,
    classify_opponent_strength,
    get_opponent_modifier,
    SCHEDULE_MODIFIERS,
    get_schedule_modifier,
    CONTEXT_BONUSES,
    FIS_THRESHOLDS,
    classify_importance_level,
    MANAGER_PROFILES,
    get_manager_profile,
    get_profile_weight,
    SHARPNESS_DETECTION,
)


@dataclass
class MatchContext:
    """Context information for a match."""
    competition: str           # 'league', 'champions_league', 'domestic_cup', etc.
    stage: str                 # 'title_race', 'knockout', 'early', etc.
    opponent_reputation: float # Opponent's reputation (0-10000)
    user_reputation: float     # User team's reputation (0-10000)
    is_derby: bool = False
    is_rivalry: bool = False
    losing_streak: int = 0     # Consecutive losses
    cup_objective: bool = False


@dataclass
class ScheduleContext:
    """Schedule context for calculating modifiers."""
    days_to_next_match: int = 7
    next_match_importance: int = 50
    matches_in_last_7_days: int = 0
    days_since_last_match: int = 3


@dataclass
class SquadContext:
    """Squad state for sharpness detection."""
    rusty_key_player_count: int = 0
    average_sharpness: float = 80.0
    key_players_below_threshold: List[str] = None


@dataclass
class ImportanceRecommendation:
    """Result of importance calculation."""
    level: str                  # 'High', 'Medium', 'Low', 'Sharpness'
    fis_score: float            # Final Importance Score (0-120+)
    confidence: float           # Confidence in recommendation (0-1)
    reasoning: List[str]        # Explanation of factors
    base_score: int             # Starting base score
    modifiers: Dict[str, float] # Applied modifiers
    bonuses: Dict[str, int]     # Applied bonuses


def calculate_fis(
    match_context: MatchContext,
    schedule_context: ScheduleContext,
    manager_profile: str = 'balanced',
    squad_context: Optional[SquadContext] = None
) -> ImportanceRecommendation:
    """
    Calculate Final Importance Score (FIS) for a match.

    FIS = (Base x M_opp x M_sched x M_user) + B_context

    Args:
        match_context: Match information (competition, opponent, etc.)
        schedule_context: Schedule information (days to next, congestion)
        manager_profile: Manager profile ID for weight adjustments
        squad_context: Optional squad state for sharpness detection

    Returns:
        ImportanceRecommendation with level, score, and reasoning
    """
    reasoning = []
    modifiers = {}
    bonuses = {}

    # --- 1. Base Importance ---
    base_score = get_base_importance(match_context.competition, match_context.stage)
    reasoning.append(f"Base: {match_context.competition}/{match_context.stage} = {base_score}")

    # --- 2. Opponent Modifier ---
    relative_strength = (
        match_context.opponent_reputation / match_context.user_reputation
        if match_context.user_reputation > 0 else 1.0
    )
    opp_classification = classify_opponent_strength(relative_strength)
    opp_modifier = get_opponent_modifier(relative_strength)
    modifiers['opponent'] = opp_modifier

    if opp_modifier != 1.0:
        reasoning.append(
            f"Opponent: {opp_classification} (rel={relative_strength:.2f}) x{opp_modifier}"
        )

    # --- 3. Schedule Modifier ---
    sched_modifier, sched_reason = get_schedule_modifier(
        schedule_context.days_to_next_match,
        schedule_context.next_match_importance,
        schedule_context.matches_in_last_7_days,
        schedule_context.days_since_last_match
    )
    modifiers['schedule'] = sched_modifier

    if sched_modifier != 1.0:
        reasoning.append(f"Schedule: {sched_reason}")

    # --- 4. Manager Profile Modifier ---
    profile_modifier = get_profile_weight(manager_profile, match_context.competition)
    modifiers['profile'] = profile_modifier

    if profile_modifier != 1.0:
        profile = get_manager_profile(manager_profile)
        reasoning.append(f"Profile: {profile['name']} x{profile_modifier}")

    # --- 5. Calculate Modified Score ---
    fis_raw = base_score * opp_modifier * sched_modifier * profile_modifier

    # --- 6. Contextual Bonuses ---
    if match_context.is_derby or match_context.is_rivalry:
        bonus = CONTEXT_BONUSES['rivalry']
        bonuses['rivalry'] = bonus
        fis_raw += bonus
        reasoning.append(f"Derby/Rivalry: +{bonus}")

    if match_context.losing_streak >= 3:
        bonus = CONTEXT_BONUSES['form_correction']
        bonuses['form_correction'] = bonus
        fis_raw += bonus
        reasoning.append(f"Form correction (losing streak {match_context.losing_streak}): +{bonus}")

    if match_context.cup_objective and match_context.stage in ['quarter_final', 'semi_final', 'final']:
        bonus = CONTEXT_BONUSES['cup_run']
        bonuses['cup_run'] = bonus
        fis_raw += bonus
        reasoning.append(f"Cup run objective: +{bonus}")

    # --- 7. Sharpness Detection ---
    if squad_context and should_suggest_sharpness(fis_raw, squad_context, schedule_context):
        return ImportanceRecommendation(
            level='Sharpness',
            fis_score=fis_raw,
            confidence=0.85,
            reasoning=[
                "Match stakes are low (FIS < 50)",
                f"{squad_context.rusty_key_player_count} key players need match fitness",
                "Sufficient recovery time before next match"
            ],
            base_score=base_score,
            modifiers=modifiers,
            bonuses=bonuses
        )

    # --- 8. Final Classification ---
    level = classify_importance_level(fis_raw)

    # Calculate confidence (how clear-cut is the decision)
    confidence = calculate_confidence(fis_raw)

    return ImportanceRecommendation(
        level=level,
        fis_score=round(fis_raw, 1),
        confidence=confidence,
        reasoning=reasoning,
        base_score=base_score,
        modifiers=modifiers,
        bonuses=bonuses
    )


def should_suggest_sharpness(
    fis: float,
    squad_context: SquadContext,
    schedule_context: ScheduleContext
) -> bool:
    """
    Determine if this match should be designated as a 'Sharpness' match.

    Conditions:
    1. FIS is low (< 50)
    2. Multiple key players have low sharpness
    3. Sufficient recovery time after this match

    Args:
        fis: Current FIS score
        squad_context: Squad sharpness state
        schedule_context: Schedule information

    Returns:
        True if sharpness designation is recommended
    """
    config = SHARPNESS_DETECTION

    # FIS must be below threshold
    if fis >= config['fis_threshold']:
        return False

    # Need minimum number of rusty key players
    if squad_context.rusty_key_player_count < config['min_rusty_players']:
        return False

    # Need sufficient recovery time
    if schedule_context.days_to_next_match < config['min_recovery_days']:
        return False

    return True


def calculate_confidence(fis: float) -> float:
    """
    Calculate confidence level based on how far FIS is from thresholds.

    A score right at a threshold boundary has lower confidence.

    Args:
        fis: Final Importance Score

    Returns:
        Confidence value (0.0 to 1.0)
    """
    high_threshold = FIS_THRESHOLDS['high']
    medium_threshold = FIS_THRESHOLDS['medium']

    # Calculate distance from nearest threshold
    if fis >= high_threshold:
        distance = fis - high_threshold
    elif fis >= medium_threshold:
        distance = min(fis - medium_threshold, high_threshold - fis)
    else:
        distance = medium_threshold - fis

    # Map distance to confidence (0-20 points from threshold = 60-100% confidence)
    confidence = min(1.0, 0.6 + (distance / 50))
    return round(confidence, 2)


def get_importance_suggestion(
    competition: str,
    stage: str,
    opponent_reputation: float,
    user_reputation: float,
    days_to_next: int = 7,
    next_match_importance: int = 50,
    is_derby: bool = False,
    losing_streak: int = 0,
    manager_profile: str = 'balanced',
    rusty_players: int = 0
) -> Dict[str, Any]:
    """
    Convenience function to get match importance suggestion.

    Args:
        competition: Competition type
        stage: Competition stage
        opponent_reputation: Opponent reputation (0-10000)
        user_reputation: User team reputation (0-10000)
        days_to_next: Days until next match
        next_match_importance: Importance of next match
        is_derby: Whether this is a derby match
        losing_streak: Current consecutive losses
        manager_profile: Manager profile ID
        rusty_players: Number of key players with low sharpness

    Returns:
        Dict with level, score, confidence, reasoning
    """
    match_ctx = MatchContext(
        competition=competition,
        stage=stage,
        opponent_reputation=opponent_reputation,
        user_reputation=user_reputation,
        is_derby=is_derby,
        losing_streak=losing_streak
    )

    schedule_ctx = ScheduleContext(
        days_to_next_match=days_to_next,
        next_match_importance=next_match_importance
    )

    squad_ctx = SquadContext(
        rusty_key_player_count=rusty_players
    ) if rusty_players > 0 else None

    result = calculate_fis(match_ctx, schedule_ctx, manager_profile, squad_ctx)

    return {
        'level': result.level,
        'score': result.fis_score,
        'confidence': result.confidence,
        'reasoning': result.reasoning,
        'base_score': result.base_score,
        'modifiers': result.modifiers,
        'bonuses': result.bonuses
    }


def get_all_manager_profiles() -> Dict[str, Dict[str, Any]]:
    """Return all available manager profiles."""
    return MANAGER_PROFILES


def validate_importance_scenarios() -> List[Dict[str, Any]]:
    """
    Run validation scenarios from Step 9 research.

    Returns validation results for each scenario.
    """
    scenarios = [
        {
            'name': 'Giant Killing Setup',
            'description': 'FA Cup 3rd Round vs League Two team',
            'match': MatchContext(
                competition='domestic_cup',
                stage='early',
                opponent_reputation=2000,
                user_reputation=8000
            ),
            'schedule': ScheduleContext(),
            'expected_level': 'Low'
        },
        {
            'name': 'Congestion Crunch',
            'description': 'League vs peer, CL QF in 3 days',
            'match': MatchContext(
                competition='league',
                stage='contention',
                opponent_reputation=7500,
                user_reputation=8000
            ),
            'schedule': ScheduleContext(
                days_to_next_match=3,
                next_match_importance=95  # CL knockout
            ),
            'expected_level': 'Medium'
        },
        {
            'name': 'Title Race Derby',
            'description': 'League title race, derby match',
            'match': MatchContext(
                competition='league',
                stage='title_race',
                opponent_reputation=7000,
                user_reputation=8000,
                is_derby=True
            ),
            'schedule': ScheduleContext(),
            'expected_level': 'High'
        }
    ]

    results = []
    for scenario in scenarios:
        result = calculate_fis(
            scenario['match'],
            scenario['schedule']
        )
        results.append({
            'name': scenario['name'],
            'description': scenario['description'],
            'expected': scenario['expected_level'],
            'actual': result.level,
            'fis': result.fis_score,
            'passed': result.level == scenario['expected_level'],
            'reasoning': result.reasoning
        })

    return results


if __name__ == '__main__':
    # Run validation scenarios
    import json

    print("=== Match Importance Validation Scenarios ===\n")
    results = validate_importance_scenarios()

    for r in results:
        status = "PASS" if r['passed'] else "FAIL"
        print(f"[{status}] {r['name']}: {r['description']}")
        print(f"  Expected: {r['expected']}, Actual: {r['actual']} (FIS={r['fis']})")
        print(f"  Reasoning: {'; '.join(r['reasoning'][:2])}")
        print()

    print(f"Results: {sum(1 for r in results if r['passed'])}/{len(results)} passed")
