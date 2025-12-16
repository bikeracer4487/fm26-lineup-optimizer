"""
API wrapper for Rotation Selector - provides First XI and Second XI data for UI.
Uses the same effective rating formula as the match selector but with ideal conditions:
- Applies positional familiarity penalty
- Assumes ideal condition (100%), sharpness (100%), fatigue (0)
- No rotation penalties, training bonuses, or other match-day factors
"""

import sys
import os
import json
import contextlib
import pandas as pd
import numpy as np
from scipy.optimize import linear_sum_assignment

# Add root directory to sys.path to allow importing from root scripts
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../')))

from fm_match_ready_selector import MatchReadySelector, normalize_name, MIN_POSITION_FAMILIARITY
import data_manager


@contextlib.contextmanager
def suppress_stdout():
    """Context manager to suppress stdout during initialization of parent class."""
    with open(os.devnull, 'w') as devnull:
        old_stdout = sys.stdout
        sys.stdout = devnull
        try:
            yield
        finally:
            sys.stdout = old_stdout


class ApiRotationSelector(MatchReadySelector):
    """
    Wrapper around MatchReadySelector to provide First XI and Second XI via API.
    Uses ideal effective ratings (no match-day factors).
    """
    def __init__(self, filepath):
        # Initialize without abilities file - we'll set up formation manually
        with suppress_stdout():
            super().__init__(filepath, abilities_filepath=None)

        # Override formation to use correct columns from single CSV:
        # - skill_col: FM positional skill (1-20)
        # - ability_col: Composite rating (50-110)
        self.formation = [
            ('GK', 'GoalKeeper', 'GK'),
            ('DL', 'Defender Left', 'D(R/L)'),
            ('DC1', 'Defender Center', 'D(C)'),
            ('DC2', 'Defender Center', 'D(C)'),
            ('DR', 'Defender Right', 'D(R/L)'),
            ('DM(L)', 'Defensive Midfielder', 'DM(L)'),
            ('DM(R)', 'Defensive Midfielder', 'DM(R)'),
            ('AML', 'Attacking Mid. Left', 'AM(L)'),
            ('AMC', 'Attacking Mid. Center', 'AM(C)'),
            ('AMR', 'Attacking Mid. Right', 'AM(R)'),
            ('STC', 'Striker_Familiarity', 'Striker')
        ]

    def calculate_ideal_effective_rating(self, row, skill_col, ability_col):
        """
        Calculate effective rating under ideal conditions.

        Uses the same base rating + familiarity penalty as the match selector,
        but without any match-day factors (condition, sharpness, fatigue, rotation, etc.)

        NOTE: Injured players ARE included - this is for squad planning under ideal
        conditions, not match-day selection. Injuries are temporary.

        Args:
            row: Player data row
            skill_col: FM positional skill column (1-20)
            ability_col: Composite ability column (50-110)

        Returns:
            Effective rating (higher is better, scale ~50-200), or -999.0 if unavailable
        """
        # Get positional skill rating (FM 1-20 familiarity)
        skill_rating = row.get(skill_col, 0)
        if pd.isna(skill_rating) or skill_rating < 1:
            return -999.0

        # Check if below minimum familiarity threshold (12 = Competent)
        below_threshold = skill_rating < MIN_POSITION_FAMILIARITY

        # Get ability rating (composite 50-110, keep full scale for CA/PA-like range)
        if ability_col and ability_col in row.index:
            ability_rating = row.get(ability_col, 0)
            if pd.notna(ability_rating) and ability_rating > 0:
                # Use ability rating as base (keep full scale, don't divide)
                base_rating = float(ability_rating)
            else:
                # Fall back to skill rating scaled up
                base_rating = float(skill_rating) * 5.0
        else:
            # No ability data, use skill rating scaled up
            base_rating = float(skill_rating) * 5.0

        effective_rating = base_rating

        # Apply positional familiarity penalty based on skill rating and Versatility
        # This is the key factor that penalizes playing out of position
        versatility = row.get('Versatility', 10)
        familiarity_penalty = self._get_familiarity_penalty(skill_rating, versatility)
        effective_rating *= (1 - familiarity_penalty)

        # Apply heavy penalty for players below minimum familiarity threshold
        # This discourages selecting "Unconvincing" or worse players
        if below_threshold:
            effective_rating *= 0.30  # 70% penalty

        return effective_rating

    def select_ideal_xi(self, exclude_players=None):
        """
        Select optimal XI using ideal effective ratings (Hungarian algorithm).

        Args:
            exclude_players: Set of player names to exclude from selection

        Returns:
            Dictionary mapping position to (player_name, rating, player_row)
        """
        # Filter available players
        available_df = self.df.copy()
        if exclude_players:
            available_df = available_df[~available_df['Name'].isin(exclude_players)]
        available_df = available_df.reset_index(drop=True)

        if available_df.empty:
            return {}

        # Build cost matrix (negative ratings for minimization)
        # Initialize with LARGE POSITIVE value so invalid entries are avoided
        n_players = len(available_df)
        n_positions = len(self.formation)
        cost_matrix = np.full((n_players, n_positions), 999.0)

        for i in range(n_players):
            player = available_df.iloc[i]
            for j, (pos_name, skill_col, ability_col) in enumerate(self.formation):
                rating = self.calculate_ideal_effective_rating(player, skill_col, ability_col)
                if rating > -999.0:
                    cost_matrix[i, j] = -rating  # Negative for minimization

        # Solve the assignment problem using Hungarian algorithm
        row_ind, col_ind = linear_sum_assignment(cost_matrix)

        # Build result dictionary
        selected_xi = {}
        for i, j in zip(row_ind, col_ind):
            pos_name = self.formation[j][0]
            player = available_df.iloc[i]
            cost_value = cost_matrix[i, j]

            # Only include players with valid ratings (not 999.0 placeholder)
            if cost_value < 998.0:  # Valid assignment (negative of actual rating)
                rating = -cost_value
                selected_xi[pos_name] = (player['Name'], rating, player)

        return selected_xi

    def get_squads_for_api(self):
        """
        Select First XI and Second XI with full player metadata.

        Returns:
            dict: {
                'success': bool,
                'firstXI': dict of position -> player data,
                'secondXI': dict of position -> player data,
                'teamRatings': { 'firstXIAverage', 'secondXIAverage' }
            }
        """
        # Select First XI
        first_xi = self.select_ideal_xi()

        # Get names of First XI players
        first_xi_players = {name for name, _, _ in first_xi.values()}

        # Select Second XI (excluding First XI players)
        second_xi = self.select_ideal_xi(exclude_players=first_xi_players)

        # Enrich both squads with player metadata
        first_xi_data = self._enrich_squad(first_xi)
        second_xi_data = self._enrich_squad(second_xi)

        # Calculate team averages
        first_xi_ratings = [p['rating'] for p in first_xi_data.values() if p]
        second_xi_ratings = [p['rating'] for p in second_xi_data.values() if p]

        first_avg = sum(first_xi_ratings) / len(first_xi_ratings) if first_xi_ratings else 0
        second_avg = sum(second_xi_ratings) / len(second_xi_ratings) if second_xi_ratings else 0

        return {
            'success': True,
            'firstXI': first_xi_data,
            'secondXI': second_xi_data,
            'teamRatings': {
                'firstXIAverage': round(first_avg, 1),
                'secondXIAverage': round(second_avg, 1)
            }
        }

    def _enrich_squad(self, squad_dict):
        """
        Enrich a squad dictionary with full player metadata.

        Args:
            squad_dict: dict of position -> (player_name, rating, player_row)

        Returns:
            dict of position -> player data dict
        """
        enriched = {}

        for position, (player_name, rating, player) in squad_dict.items():
            if not player_name:
                enriched[position] = None
                continue

            # Get player attributes
            age = player.get('Age', 0)
            ca = player.get('CA', 0)
            pa = player.get('PA', 0)
            # Try 'Best Position' first, then fall back to 'Positions'
            natural_position = player.get('Best Position', player.get('Positions', 'Unknown'))

            # Get condition (normalize if needed)
            condition = player.get('Condition', player.get('Condition (%)', 100))
            if pd.notna(condition):
                if condition > 100:
                    condition = condition / 100  # Was stored as 0-10000
            else:
                condition = 100

            # Get fatigue (raw value)
            fatigue = player.get('Fatigue', 0)
            if pd.isna(fatigue):
                fatigue = 0

            # Get match sharpness (normalize to 0-100)
            sharpness = player.get('Match Sharpness', 10000)
            if pd.notna(sharpness):
                if sharpness > 100:
                    sharpness = sharpness / 100  # Convert 0-10000 to 0-100
            else:
                sharpness = 100

            enriched[position] = {
                'name': player_name,
                'rating': round(rating, 1) if pd.notna(rating) else 0,
                'age': int(age) if pd.notna(age) else 0,
                'ca': int(ca) if pd.notna(ca) else 0,
                'pa': int(pa) if pd.notna(pa) else 0,
                'condition': round(condition, 1) if pd.notna(condition) else 100,
                'fatigue': round(fatigue, 0) if pd.notna(fatigue) else 0,
                'sharpness': round(sharpness, 1) if pd.notna(sharpness) else 100,
                'naturalPosition': str(natural_position) if pd.notna(natural_position) else 'Unknown'
            }

        return enriched


# --- Custom JSON Encoder to handle numpy types ---
class NumpyEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, (np.int_, np.intc, np.intp, np.int8,
                            np.int16, np.int32, np.int64, np.uint8,
                            np.uint16, np.uint32, np.uint64)):
            return int(obj)
        elif isinstance(obj, (np.float_, np.float16, np.float32,
                              np.float64)):
            return float(obj)
        elif isinstance(obj, (np.ndarray,)):
            return obj.tolist()
        elif isinstance(obj, (np.bool_)):
            return bool(obj)
        return json.JSONEncoder.default(self, obj)


def main():
    try:
        # Read JSON from stdin (may contain file paths)
        input_str = sys.stdin.read()

        # 1. UPDATE DATA FROM EXCEL
        with suppress_stdout():
            data_manager.update_player_data()

        # Use default status file
        status_file = 'players-current.csv'

        selector = ApiRotationSelector(status_file)
        result = selector.get_squads_for_api()

        print(json.dumps(result, cls=NumpyEncoder))

    except Exception as e:
        import traceback
        print(json.dumps({"success": False, "error": str(e), "traceback": traceback.format_exc()}))


if __name__ == '__main__':
    main()
