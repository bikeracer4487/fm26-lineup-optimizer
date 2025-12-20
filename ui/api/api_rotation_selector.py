"""
API wrapper for Rotation Selector - provides First XI and Second XI data for UI.
Uses rating_calculator for IP/OOP role-based combined ratings.
Assumes ideal conditions (100% condition, 100% sharpness, 0 fatigue).
Dynamically builds formation from saved tactic configuration.
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

from fm_match_ready_selector import MatchReadySelector, normalize_name
import data_manager
import rating_calculator


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


def load_tactic_config():
    """Load tactic configuration from app_state.json."""
    app_state_path = os.path.join(os.path.dirname(__file__), '..', 'data', 'app_state.json')
    if os.path.exists(app_state_path):
        with open(app_state_path, 'r', encoding='utf-8') as f:
            app_state = json.load(f)
            return app_state.get('tacticConfig', None)
    return None


def slot_to_pos_key(slot_id):
    """Convert slot ID (e.g., 'D_L', 'AM_R') to rating_calculator position key (e.g., 'D(L)', 'AM(R)').

    CRITICAL: Must use exact string matching, not 'L' in string,
    because D_CL/D_CR/AM_CL/AM_CR contain 'L'/'R' but are center positions.

    Slot naming convention:
    - _L = left position (D_L, AM_L, M_L, WB_L)
    - _R = right position (D_R, AM_R, M_R, WB_R)
    - _C, _CL, _CR = center positions (D_C, D_CL, D_CR, AM_C, etc.)
    """
    if slot_id == 'GK':
        return 'GK'
    if slot_id.startswith('ST_'):
        return 'ST'
    if slot_id.startswith('AM_'):
        if slot_id == 'AM_L': return 'AM(L)'
        if slot_id == 'AM_R': return 'AM(R)'
        return 'AM(C)'  # AM_C, AM_CL, AM_CR
    if slot_id.startswith('M_'):
        if slot_id == 'M_L': return 'M(L)'
        if slot_id == 'M_R': return 'M(R)'
        return 'M(C)'  # M_C, M_CL, M_CR
    if slot_id.startswith('DM_'):
        return 'DM'
    if slot_id.startswith('WB_'):
        if slot_id == 'WB_L': return 'WB(L)'
        if slot_id == 'WB_R': return 'WB(R)'
        return 'WB(C)'
    if slot_id.startswith('D_'):
        # D_L = left fullback, D_R = right fullback
        # D_C, D_CL, D_CR = center-backs
        if slot_id == 'D_L': return 'D(L)'
        if slot_id == 'D_R': return 'D(R)'
        return 'D(C)'
    return slot_id


def slot_to_display_pos(slot_id):
    """Convert slot ID to human-readable position for display.

    Uses exact string matching to correctly distinguish between:
    - _L = left position (e.g., AM_L -> AM(L))
    - _R = right position (e.g., AM_R -> AM(R))
    - _CL = center-left position (e.g., D_CL -> D(CL))
    - _CR = center-right position (e.g., D_CR -> D(CR))
    - _C = center position (e.g., AM_C -> AM(C))
    """
    if slot_id == 'GK':
        return 'GK'
    if slot_id.startswith('ST_'):
        if slot_id == 'ST_L': return 'ST(L)'
        if slot_id == 'ST_R': return 'ST(R)'
        return 'ST'
    if slot_id.startswith('AM_'):
        if slot_id == 'AM_L': return 'AM(L)'
        if slot_id == 'AM_R': return 'AM(R)'
        if slot_id == 'AM_CL': return 'AM(CL)'
        if slot_id == 'AM_CR': return 'AM(CR)'
        return 'AM(C)'
    if slot_id.startswith('M_'):
        if slot_id == 'M_L': return 'M(L)'
        if slot_id == 'M_R': return 'M(R)'
        if slot_id == 'M_CL': return 'M(CL)'
        if slot_id == 'M_CR': return 'M(CR)'
        return 'M(C)'
    if slot_id.startswith('DM_'):
        if slot_id == 'DM_L': return 'DM(L)'
        if slot_id == 'DM_R': return 'DM(R)'
        return 'DM'
    if slot_id.startswith('WB_'):
        if slot_id == 'WB_L': return 'WB(L)'
        if slot_id == 'WB_R': return 'WB(R)'
        return 'WB'
    if slot_id.startswith('D_'):
        if slot_id == 'D_L': return 'D(L)'
        if slot_id == 'D_R': return 'D(R)'
        if slot_id == 'D_CL': return 'D(CL)'
        if slot_id == 'D_CR': return 'D(CR)'
        return 'D(C)'
    return slot_id


def build_formation_from_tactic(tactic_config):
    """
    Build formation list from tactic configuration.

    Args:
        tactic_config: dict with ipPositions, oopPositions, mapping

    Returns:
        List of (display_name, slot_id, ip_pos_key, ip_role, oop_pos_key, oop_role) tuples
        or None if config is invalid
    """
    if not tactic_config:
        return None

    ip_positions = tactic_config.get('ipPositions', {})
    oop_positions = tactic_config.get('oopPositions', {})
    mapping = tactic_config.get('mapping', {})

    formation = []
    for slot_id, ip_role in ip_positions.items():
        if not ip_role:
            continue  # Skip slots without assigned IP roles

        # Get OOP slot and role from mapping
        oop_slot = mapping.get(slot_id, slot_id)  # Default to same slot if not mapped
        oop_role = oop_positions.get(oop_slot)

        if not oop_role:
            continue  # Skip if no OOP role defined

        # Convert slot IDs to position keys for rating_calculator
        ip_pos_key = slot_to_pos_key(slot_id)
        oop_pos_key = slot_to_pos_key(oop_slot)

        # Generate display name
        ip_display = slot_to_display_pos(slot_id)
        oop_display = slot_to_display_pos(oop_slot)

        if ip_display == oop_display or slot_id == oop_slot:
            display_name = ip_display
        else:
            display_name = f"{ip_display}→{oop_display}"

        formation.append((display_name, slot_id, ip_pos_key, ip_role, oop_pos_key, oop_role))

    return formation if formation else None


def get_default_formation():
    """Return default 4-2-3-1 formation with standard roles."""
    return [
        ('GK', 'GK', 'GK', 'Goalkeeper', 'GK', 'Goalkeeper'),
        ('D(L)', 'D_L', 'D(L)', 'Full-Back', 'D(L)', 'Full-Back'),
        ('D(CL)', 'D_CL', 'D(C)', 'Centre-Back', 'D(C)', 'Centre-Back'),
        ('D(CR)', 'D_CR', 'D(C)', 'Centre-Back', 'D(C)', 'Centre-Back'),
        ('D(R)', 'D_R', 'D(R)', 'Full-Back', 'D(R)', 'Full-Back'),
        ('DM(L)', 'DM_L', 'DM', 'Defensive Midfielder', 'DM', 'Defensive Midfielder'),
        ('DM(R)', 'DM_R', 'DM', 'Defensive Midfielder', 'DM', 'Defensive Midfielder'),
        ('AM(L)', 'AM_L', 'AM(L)', 'Winger', 'AM(L)', 'Winger'),
        ('AM(C)', 'AM_C', 'AM(C)', 'Attacking Midfielder', 'AM(C)', 'Attacking Midfielder'),
        ('AM(R)', 'AM_R', 'AM(R)', 'Winger', 'AM(R)', 'Winger'),
        ('ST', 'ST_C', 'ST', 'Centre Forward', 'ST', 'Centre Forward'),
    ]


class ApiRotationSelector(MatchReadySelector):
    """
    Wrapper around MatchReadySelector to provide First XI and Second XI via API.
    Uses rating_calculator for IP/OOP combined ratings under ideal conditions.
    """
    def __init__(self, filepath, tactic_config=None):
        # Initialize parent class
        with suppress_stdout():
            super().__init__(filepath, abilities_filepath=None)

        # Store formation with full IP/OOP data
        self.tactic_formation = None

        # Try to build formation from passed tactic config
        if tactic_config:
            self.tactic_formation = build_formation_from_tactic(tactic_config)

        # Fallback: try to load from app_state.json
        if not self.tactic_formation:
            loaded_config = load_tactic_config()
            if loaded_config:
                self.tactic_formation = build_formation_from_tactic(loaded_config)

        # Final fallback: default formation
        if not self.tactic_formation:
            self.tactic_formation = get_default_formation()

    def calculate_combined_rating(self, player_row, ip_pos, ip_role, oop_pos, oop_role):
        """
        Calculate combined IP/OOP rating using rating_calculator.

        Args:
            player_row: Player data row (pandas Series or dict)
            ip_pos: In-Possession position key (e.g., 'D(L)')
            ip_role: In-Possession role name (e.g., 'Wing Back')
            oop_pos: Out-of-Possession position key (e.g., 'M(L)')
            oop_role: Out-of-Possession role name (e.g., 'Wide Midfielder')

        Returns:
            Combined rating (0-200 scale), or -999.0 if player unavailable
        """
        # Convert to dict if pandas Series
        if hasattr(player_row, 'to_dict'):
            player_attrs = player_row.to_dict()
        else:
            player_attrs = dict(player_row)

        try:
            rating = rating_calculator.calculate_combined_rating(
                player_attrs, ip_pos, ip_role, oop_pos, oop_role
            )
            return rating if rating is not None else -999.0
        except Exception:
            return -999.0

    def select_ideal_xi(self, exclude_players=None):
        """
        Select optimal XI using combined IP/OOP ratings (Hungarian algorithm).

        Args:
            exclude_players: Set of player names to exclude from selection

        Returns:
            Dictionary mapping display_name to (player_name, rating, player_row)
        """
        # Filter available players
        available_df = self.df.copy()
        if exclude_players:
            available_df = available_df[~available_df['Name'].isin(exclude_players)]
        available_df = available_df.reset_index(drop=True)

        if available_df.empty:
            return {}

        # Build cost matrix (negative ratings for minimization)
        n_players = len(available_df)
        n_positions = len(self.tactic_formation)
        cost_matrix = np.full((n_players, n_positions), 999.0)

        for i in range(n_players):
            player = available_df.iloc[i]
            for j, (display_name, slot_id, ip_pos, ip_role, oop_pos, oop_role) in enumerate(self.tactic_formation):
                rating = self.calculate_combined_rating(player, ip_pos, ip_role, oop_pos, oop_role)
                if rating > -999.0:
                    cost_matrix[i, j] = -rating  # Negative for minimization

        # Solve the assignment problem using Hungarian algorithm
        row_ind, col_ind = linear_sum_assignment(cost_matrix)

        # Build result dictionary
        selected_xi = {}
        for i, j in zip(row_ind, col_ind):
            display_name = self.tactic_formation[j][0]
            player = available_df.iloc[i]
            cost_value = cost_matrix[i, j]

            # Only include players with valid ratings (not 999.0 placeholder)
            if cost_value < 998.0:  # Valid assignment
                rating = -cost_value
                selected_xi[display_name] = (player['Name'], rating, player)

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
                    sharpness = sharpness / 100
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
