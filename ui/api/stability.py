"""
FM26 Polyvalent Stability Mechanisms
=====================================

Implements stability mechanisms for lineup optimization to prevent oscillating
assignments when versatile players have similar utility at multiple positions.

Two complementary approaches:
1. Assignment Inertia Penalty - adds switching costs to cost matrix
2. Soft-Lock Anchoring - strengthens inertia for consistent assignments

Reference: docs/new-research/FM26 #2 - Lineup Optimizer - Complete Mathematical Specification.md
Section F: Polyvalent stability prevents oscillating assignments while preserving optimality
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Set, Tuple, Any
import numpy as np
import sys
import os

# Add parent to path for imports
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

from scoring_parameters import StabilityConfig, DEFAULT_STABILITY_CONFIG


@dataclass
class AssignmentHistory:
    """
    Tracks historical player-to-position assignments for stability calculations.
    """
    # Maps player_name -> list of (match_id, position) tuples, most recent first
    history: Dict[str, List[Tuple[str, str]]] = field(default_factory=dict)

    # Maximum history length to maintain
    max_history: int = 10

    def add_assignment(self, match_id: str, player_name: str, position: str) -> None:
        """Record a player's assignment for a match."""
        if player_name not in self.history:
            self.history[player_name] = []

        self.history[player_name].insert(0, (match_id, position))

        # Trim history if too long
        if len(self.history[player_name]) > self.max_history:
            self.history[player_name] = self.history[player_name][:self.max_history]

    def get_recent_positions(self, player_name: str, n: int = 3) -> List[str]:
        """Get the n most recent positions for a player."""
        if player_name not in self.history:
            return []
        return [pos for _, pos in self.history[player_name][:n]]

    def get_previous_assignment(self, player_name: str) -> Optional[str]:
        """Get the most recent position assignment for a player."""
        if player_name not in self.history or not self.history[player_name]:
            return None
        return self.history[player_name][0][1]

    def get_consecutive_count(self, player_name: str, position: str) -> int:
        """Count consecutive matches a player has been in the same position."""
        if player_name not in self.history:
            return 0

        count = 0
        for _, pos in self.history[player_name]:
            if pos == position:
                count += 1
            else:
                break
        return count


def compute_stability_costs(
    player_names: List[str],
    slot_ids: List[str],
    prev_assignment: Dict[str, str],
    config: StabilityConfig = DEFAULT_STABILITY_CONFIG
) -> np.ndarray:
    """
    Compute stability cost matrix for assignment inertia.

    Formula (from FM26 #2 spec):
    - Same position as previous: -inertia_weight × continuity_bonus (negative = preference)
    - Different position: +inertia_weight × base_switch_cost (positive = penalty)
    - No previous assignment: 0

    Args:
        player_names: List of player names (matrix rows)
        slot_ids: List of slot/position IDs (matrix columns)
        prev_assignment: Dict mapping player_name -> slot_id from previous match
        config: StabilityConfig with inertia parameters

    Returns:
        2D numpy array of stability costs [n_players × n_slots]
    """
    n_players = len(player_names)
    n_slots = len(slot_ids)
    stability = np.zeros((n_players, n_slots))

    for i, player in enumerate(player_names):
        prev_slot = prev_assignment.get(player)

        for j, slot in enumerate(slot_ids):
            if prev_slot is None:
                # No previous assignment, no penalty
                stability[i, j] = 0
            elif slot == prev_slot:
                # Continuity bonus (negative cost = preference)
                stability[i, j] = -config.inertia_weight * config.continuity_bonus
            else:
                # Switching penalty
                stability[i, j] = config.inertia_weight * config.base_switch_cost

    return stability


def compute_anchor_costs(
    player_names: List[str],
    slot_ids: List[str],
    assignment_history: AssignmentHistory,
    config: StabilityConfig = DEFAULT_STABILITY_CONFIG
) -> np.ndarray:
    """
    Compute anchor cost matrix for soft-lock anchoring.

    After N consecutive matches in the same position, a player becomes "anchored"
    and has elevated switching costs to maintain lineup stability.

    Args:
        player_names: List of player names (matrix rows)
        slot_ids: List of slot/position IDs (matrix columns)
        assignment_history: AssignmentHistory with recent assignments
        config: StabilityConfig with anchor parameters

    Returns:
        2D numpy array of anchor costs [n_players × n_slots]
    """
    n_players = len(player_names)
    n_slots = len(slot_ids)
    anchor_costs = np.zeros((n_players, n_slots))

    # Identify anchored players
    anchors = {}
    for player in player_names:
        recent = assignment_history.get_recent_positions(player, n=config.anchor_threshold)
        if len(recent) >= config.anchor_threshold and len(set(recent)) == 1:
            # Same position for N+ consecutive matches → anchor
            anchors[player] = {
                'slot': recent[0],
                'strength': config.anchor_multiplier
            }

    # Apply anchor costs
    for i, player in enumerate(player_names):
        if player in anchors:
            anchor = anchors[player]
            for j, slot in enumerate(slot_ids):
                if slot != anchor['slot']:
                    anchor_costs[i, j] = anchor['strength'] * config.base_switch_cost

    return anchor_costs


def get_combined_stability_costs(
    player_names: List[str],
    slot_ids: List[str],
    prev_assignment: Dict[str, str],
    assignment_history: Optional[AssignmentHistory] = None,
    config: StabilityConfig = DEFAULT_STABILITY_CONFIG
) -> np.ndarray:
    """
    Get combined stability costs (inertia + anchoring).

    Args:
        player_names: List of player names (matrix rows)
        slot_ids: List of slot/position IDs (matrix columns)
        prev_assignment: Dict mapping player_name -> slot_id from previous match
        assignment_history: Optional AssignmentHistory for anchor costs
        config: StabilityConfig with all parameters

    Returns:
        2D numpy array of combined stability costs [n_players × n_slots]
    """
    # Always apply inertia costs
    stability = compute_stability_costs(player_names, slot_ids, prev_assignment, config)

    # Optionally add anchor costs
    if assignment_history is not None:
        anchor = compute_anchor_costs(player_names, slot_ids, assignment_history, config)
        stability = stability + anchor

    return stability


@dataclass
class AssignmentManager:
    """
    Manages player assignments with support for locks, rejections, and constraints.

    This class handles:
    - Manual locks (user forces player to specific position)
    - Player rejections (user blocks player from certain positions)
    - Confirmed lineups (selections that should be preserved)
    - Assignment history (for stability calculations)
    """

    # player_name -> slot_id (user-forced assignments)
    manual_locks: Dict[str, str] = field(default_factory=dict)

    # player_name -> [slot_ids] (user-blocked positions)
    player_rejections: Dict[str, List[str]] = field(default_factory=dict)

    # slot_id -> player_name (confirmed for match)
    confirmed_lineup: Dict[str, str] = field(default_factory=dict)

    # Assignment history for stability
    history: AssignmentHistory = field(default_factory=AssignmentHistory)

    # Stability configuration
    config: StabilityConfig = field(default_factory=lambda: DEFAULT_STABILITY_CONFIG)

    def lock_player(self, player_name: str, slot_id: str) -> None:
        """Force a player to a specific position."""
        self.manual_locks[player_name] = slot_id

    def unlock_player(self, player_name: str) -> None:
        """Remove a player's position lock."""
        if player_name in self.manual_locks:
            del self.manual_locks[player_name]

    def reject_position(self, player_name: str, slot_id: str) -> None:
        """Block a player from a specific position."""
        if player_name not in self.player_rejections:
            self.player_rejections[player_name] = []
        if slot_id not in self.player_rejections[player_name]:
            self.player_rejections[player_name].append(slot_id)

    def clear_rejection(self, player_name: str, slot_id: str) -> None:
        """Remove a position rejection for a player."""
        if player_name in self.player_rejections:
            self.player_rejections[player_name] = [
                s for s in self.player_rejections[player_name] if s != slot_id
            ]

    def confirm_assignment(self, slot_id: str, player_name: str) -> None:
        """Confirm a player's assignment for a match."""
        self.confirmed_lineup[slot_id] = player_name

    def clear_confirmed(self) -> None:
        """Clear all confirmed assignments."""
        self.confirmed_lineup.clear()

    def record_match_assignments(self, match_id: str, lineup: Dict[str, str]) -> None:
        """
        Record a full lineup for history tracking.

        Args:
            match_id: Unique match identifier
            lineup: Dict mapping slot_id -> player_name
        """
        for slot_id, player_name in lineup.items():
            self.history.add_assignment(match_id, player_name, slot_id)

    def apply_constraints(
        self,
        cost_matrix: np.ndarray,
        player_names: List[str],
        slot_ids: List[str]
    ) -> np.ndarray:
        """
        Apply hard constraints (locks, rejections, confirmations) to cost matrix.

        Sets infinity cost for impossible assignments.

        Args:
            cost_matrix: Base cost matrix to modify
            player_names: List of player names (matrix rows)
            slot_ids: List of slot/position IDs (matrix columns)

        Returns:
            Modified cost matrix with constraints applied
        """
        INFINITY = 1e9
        modified = cost_matrix.copy()

        # Create name-to-index mappings
        player_idx = {name: i for i, name in enumerate(player_names)}
        slot_idx = {slot: j for j, slot in enumerate(slot_ids)}

        # Enforce manual locks
        for player_name, locked_slot in self.manual_locks.items():
            if player_name in player_idx and locked_slot in slot_idx:
                i = player_idx[player_name]
                # Set all other positions to infinity
                for j, slot in enumerate(slot_ids):
                    if slot != locked_slot:
                        modified[i, j] = INFINITY

        # Apply rejections
        for player_name, rejected_slots in self.player_rejections.items():
            if player_name in player_idx:
                i = player_idx[player_name]
                for slot in rejected_slots:
                    if slot in slot_idx:
                        modified[i, slot_idx[slot]] = INFINITY

        # Enforce confirmed lineup
        for slot_id, player_name in self.confirmed_lineup.items():
            if slot_id in slot_idx and player_name in player_idx:
                j = slot_idx[slot_id]
                # Set all other players to infinity for this slot
                for i, name in enumerate(player_names):
                    if name != player_name:
                        modified[i, j] = INFINITY

        return modified

    def get_previous_assignment_map(self) -> Dict[str, str]:
        """Get mapping of player -> most recent position for stability costs."""
        return {
            player: self.history.get_previous_assignment(player)
            for player in self.history.history.keys()
            if self.history.get_previous_assignment(player) is not None
        }


def build_cost_matrix_with_stability(
    base_utility_matrix: np.ndarray,
    player_names: List[str],
    slot_ids: List[str],
    shadow_costs: Optional[np.ndarray] = None,
    assignment_manager: Optional[AssignmentManager] = None,
    config: StabilityConfig = DEFAULT_STABILITY_CONFIG
) -> np.ndarray:
    """
    Build complete cost matrix for Hungarian algorithm with all costs integrated.

    Cost = -Utility + ShadowCost + StabilityCost
    (Hungarian minimizes cost, so we negate utility)

    Args:
        base_utility_matrix: Player-slot utility scores [n_players × n_slots]
        player_names: List of player names (matrix rows)
        slot_ids: List of slot/position IDs (matrix columns)
        shadow_costs: Optional shadow cost matrix from multi-match planning
        assignment_manager: Optional manager for locks/rejections/stability
        config: Stability configuration

    Returns:
        Cost matrix ready for Hungarian algorithm
    """
    # Start with negated utility (minimize cost = maximize utility)
    cost = -base_utility_matrix.copy()

    # Add shadow costs if provided
    if shadow_costs is not None:
        cost = cost + shadow_costs

    # Add stability costs if manager is provided
    if assignment_manager is not None:
        prev_assignment = assignment_manager.get_previous_assignment_map()
        stability = get_combined_stability_costs(
            player_names, slot_ids, prev_assignment,
            assignment_manager.history, config
        )
        cost = cost + stability

        # Apply hard constraints (locks, rejections, confirmations)
        cost = assignment_manager.apply_constraints(cost, player_names, slot_ids)

    return cost
