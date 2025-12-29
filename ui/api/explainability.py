"""
FM26 Explainability Module
==========================

Generates human-readable justifications for algorithmic selection decisions.
Critical for building user trust in the automated system.

Reference: docs/new-research/FM26 #1 - System spec + decision model (foundation).md
Section 5: Explainability and UI Feedback
"""

from typing import Dict, Any, Optional, List
from dataclasses import dataclass
import sys
import os

# Add parent to path for imports
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

from scoring_parameters import ScoringContext


@dataclass
class SelectionExplanation:
    """Full explanation for a player selection decision."""
    player_name: str
    position: str
    decision: str  # 'selected', 'excluded', 'benched'
    primary_reason: str
    secondary_reasons: List[str]
    multiplier_breakdown: Dict[str, float]
    warnings: List[str]
    projected_condition: Optional[float] = None
    next_important_match: Optional[str] = None


def identify_limiting_factor(multipliers: Dict[str, float]) -> str:
    """
    Identify which multiplier had the greatest negative impact.

    Args:
        multipliers: Dict of multiplier_name -> value

    Returns:
        Name of the most impactful (lowest) multiplier
    """
    if not multipliers:
        return 'unknown'

    # Filter to multipliers that are penalties (< 1.0) or bonuses (> 1.0)
    # The lowest one is the limiting factor
    min_mult = min(multipliers.values())
    for name, value in multipliers.items():
        if value == min_mult:
            return name

    return 'unknown'


def generate_selection_reason(
    player_data: Dict[str, Any],
    position: str,
    context: ScoringContext,
    multipliers: Dict[str, float],
    is_selected: bool,
    shadow_cost: float = 0.0,
    next_high_match: Optional[Dict] = None,
    projected_condition: Optional[float] = None
) -> SelectionExplanation:
    """
    Generate a comprehensive explanation for a selection decision.

    Analyzes which multiplier caused the greatest impact and generates
    appropriate human-readable reason strings.

    Args:
        player_data: Player's full data dict
        position: Position being considered
        context: Scoring context with importance parameters
        multipliers: Dict of multiplier name -> value
        is_selected: Whether player was selected for the XI
        shadow_cost: Shadow pricing cost (if applicable)
        next_high_match: Dict with next high importance match info
        projected_condition: Projected condition for next important match

    Returns:
        SelectionExplanation with all decision details
    """
    player_name = player_data.get('Name', 'Unknown')
    condition = player_data.get('Condition', 100)
    if condition > 100:
        condition = condition / 100
    sharpness = player_data.get('Match Sharpness', 100)
    if sharpness > 100:
        sharpness = sharpness / 100
    fatigue = player_data.get('Fatigue', 0)
    is_jaded = player_data.get('Is Jaded', False)

    # Get familiarity (from position column)
    familiarity_col = f"{position}_Familiarity"
    familiarity = player_data.get(familiarity_col, 10)

    primary_reason = ""
    secondary_reasons = []
    warnings = []
    decision = 'selected' if is_selected else 'excluded'

    # Identify the limiting factor
    limiting_factor = identify_limiting_factor(multipliers)

    # Generate primary reason based on limiting factor and context
    if is_selected:
        # Player was selected - explain why
        if context.sharpness_mode == 'build' and multipliers.get('sharpness', 1.0) > 1.0:
            primary_reason = f"Selected to build match fitness (Sharpness {sharpness:.0f}% is in target zone)."
        elif multipliers.get('condition', 1.0) >= 0.95 and multipliers.get('fatigue', 1.0) >= 0.95:
            primary_reason = "Selected based on high match utility and excellent physical condition."
        elif context.importance == 'High':
            primary_reason = "Selected for optimal match effectiveness (High Importance match)."
        else:
            primary_reason = "Selected based on overall match utility score."

        # Add warnings for concerning factors even if selected
        if is_jaded and context.importance == 'High':
            warnings.append(f"Starting despite jadedness warning (High Importance Match Override).")
        if condition < context.safety_threshold + 5:
            warnings.append(f"Condition ({condition:.0f}%) approaching safety threshold ({context.safety_threshold:.0f}%).")
        if fatigue > 300:
            warnings.append(f"Elevated fatigue level ({fatigue:.0f}).")

    else:
        # Player was excluded - explain why
        if limiting_factor == 'condition' and multipliers.get('condition', 1.0) < 0.5:
            primary_reason = (
                f"Excluded due to high injury risk "
                f"(Condition {condition:.0f}% < Safety Threshold {context.safety_threshold:.0f}%)."
            )
        elif limiting_factor == 'fatigue' and is_jaded:
            primary_reason = "Excluded: Player is jaded and needs rest."
        elif limiting_factor == 'fatigue' and multipliers.get('fatigue', 1.0) < 0.7:
            primary_reason = f"Excluded due to high fatigue level ({fatigue:.0f})."
        elif limiting_factor == 'familiarity' and multipliers.get('familiarity', 1.0) < 0.5:
            primary_reason = (
                f"Avoided despite potential: Lack of tactical familiarity "
                f"({familiarity:.0f}/20 in {position})."
            )
        elif limiting_factor == 'sharpness' and sharpness < 50:
            primary_reason = f"Excluded due to severe match rustiness (Sharpness {sharpness:.0f}%)."
        elif shadow_cost > 0 and next_high_match:
            opponent = next_high_match.get('opponent', 'upcoming match')
            match_idx = next_high_match.get('index', 0)
            primary_reason = (
                f"Resting for upcoming {opponent} (Match {match_idx + 1}). "
                f"Projected condition if played today: {projected_condition:.0f}% (Risk)."
            )
        else:
            primary_reason = "Not selected based on overall match utility comparison."

    # Add secondary reasons for additional context
    if multipliers.get('condition', 1.0) < 1.0 and limiting_factor != 'condition':
        secondary_reasons.append(f"Condition penalty applied ({condition:.0f}%).")
    if multipliers.get('sharpness', 1.0) < 1.0 and limiting_factor != 'sharpness':
        secondary_reasons.append(f"Sharpness penalty applied ({sharpness:.0f}%).")
    if multipliers.get('fatigue', 1.0) < 1.0 and limiting_factor != 'fatigue':
        secondary_reasons.append(f"Fatigue penalty applied ({fatigue:.0f}).")
    if multipliers.get('familiarity', 1.0) < 1.0 and limiting_factor != 'familiarity':
        secondary_reasons.append(f"Position familiarity penalty ({familiarity:.0f}/20).")

    return SelectionExplanation(
        player_name=player_name,
        position=position,
        decision=decision,
        primary_reason=primary_reason,
        secondary_reasons=secondary_reasons,
        multiplier_breakdown=multipliers,
        warnings=warnings,
        projected_condition=projected_condition,
        next_important_match=next_high_match.get('opponent') if next_high_match else None
    )


def generate_bench_reason(
    player_data: Dict[str, Any],
    position: str,
    context: ScoringContext,
    starter_name: str,
    utility_difference: float
) -> str:
    """
    Generate reason why a player is on the bench instead of starting.

    Args:
        player_data: Benched player's data
        position: Position they were considered for
        context: Scoring context
        starter_name: Name of the player who was selected
        utility_difference: Difference in utility scores

    Returns:
        Human-readable bench reason
    """
    player_name = player_data.get('Name', 'Unknown')

    if utility_difference > 20:
        return f"On bench: {starter_name} rated significantly higher for {position}."
    elif utility_difference > 10:
        return f"On bench: {starter_name} provides better match utility for {position}."
    else:
        return f"On bench: Marginal preference for {starter_name} in {position}."


def generate_rotation_warning(
    player_name: str,
    consecutive_matches: int,
    position: str,
    rotation_threshold: int
) -> Optional[str]:
    """
    Generate warning about rotation needs.

    Args:
        player_name: Player name
        consecutive_matches: Matches played consecutively
        position: Position played
        rotation_threshold: Threshold for this position

    Returns:
        Warning string if rotation needed, None otherwise
    """
    if consecutive_matches >= rotation_threshold:
        return (
            f"{player_name} has started {consecutive_matches} consecutive matches "
            f"at {position}. Rotation recommended to avoid fatigue buildup."
        )
    elif consecutive_matches >= rotation_threshold - 1:
        return (
            f"{player_name} approaching rotation threshold ({consecutive_matches}/{rotation_threshold} matches). "
            f"Consider resting in next Low/Medium importance match."
        )
    return None


def generate_match_summary(
    selections: Dict[str, Any],
    importance: str,
    opponent: str
) -> str:
    """
    Generate a summary explanation for the entire match lineup.

    Args:
        selections: Dict of position -> selection info
        importance: Match importance level
        opponent: Opponent name

    Returns:
        Summary paragraph for the match
    """
    num_positions = len(selections)
    warnings = []
    strategy_notes = []

    # Count players with various statuses
    low_condition_count = 0
    high_sharpness_count = 0
    rotation_risk_count = 0

    for pos, sel in selections.items():
        if isinstance(sel, dict):
            status = sel.get('status', [])
            if 'Low Condition' in status:
                low_condition_count += 1
            if 'Peak Form' in status:
                high_sharpness_count += 1
            if 'Rotation Risk' in status:
                rotation_risk_count += 1

    # Generate summary based on match type
    if importance == 'High':
        summary = f"Starting XI optimized for maximum match effectiveness against {opponent}."
        if low_condition_count > 0:
            warnings.append(f"{low_condition_count} player(s) starting below optimal condition.")
        if high_sharpness_count >= 8:
            strategy_notes.append("Squad is in excellent form for this critical fixture.")

    elif importance == 'Sharpness':
        summary = f"XI selected to build match sharpness against {opponent}."
        strategy_notes.append("Players needing match time have been prioritized.")

    elif importance == 'Low':
        summary = f"Rotation-focused XI selected for {opponent}."
        if rotation_risk_count > 0:
            strategy_notes.append(f"{rotation_risk_count} player(s) rested for upcoming fixtures.")

    else:  # Medium
        summary = f"Balanced XI selected against {opponent}."

    # Combine into final summary
    parts = [summary]
    if strategy_notes:
        parts.append(' '.join(strategy_notes))
    if warnings:
        parts.append('Note: ' + '; '.join(warnings))

    return ' '.join(parts)


def format_multiplier_breakdown(multipliers: Dict[str, float]) -> str:
    """
    Format multiplier breakdown for display.

    Args:
        multipliers: Dict of multiplier_name -> value

    Returns:
        Formatted string like "Base: 150 x Cond: 0.95 x Sharp: 1.00 = 142.5"
    """
    parts = []

    for name, value in multipliers.items():
        if name == 'base':
            parts.append(f"Base: {value:.0f}")
        elif name == 'final':
            continue  # Skip final, we'll calculate it
        else:
            display_name = {
                'condition': 'Cond',
                'sharpness': 'Sharp',
                'familiarity': 'Fam',
                'fatigue': 'Fatigue'
            }.get(name, name.title())
            parts.append(f"{display_name}: {value:.2f}")

    final = multipliers.get('final', 0)
    formula = ' x '.join(parts)

    return f"{formula} = {final:.1f}"
