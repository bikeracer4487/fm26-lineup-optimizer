#!/usr/bin/env python3
"""
FM26 Match-Ready Lineup Selector
Advanced lineup selection considering match sharpness, physical condition,
fatigue, positional skill ratings, and match scheduling for intelligent rotation.

Author: Doug Mason (2025)
"""

import sys
import pandas as pd
import numpy as np
from scipy.optimize import linear_sum_assignment
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional


class MatchReadySelector:
    """
    Intelligent team selector that factors in player condition, fatigue,
    match sharpness, and fixture scheduling for optimal rotation.
    """

    def __init__(self, filepath: str):
        """
        Initialize the selector with player data.

        Args:
            filepath: Path to CSV file containing comprehensive player data
        """
        # Load data
        if filepath.endswith('.csv'):
            self.df = pd.read_csv(filepath, encoding='utf-8-sig')
        else:
            self.df = pd.read_excel(filepath)

        # Clean up column names
        self.df.columns = self.df.columns.str.strip()

        # Convert numeric columns
        numeric_columns = [
            'Age', 'CA', 'PA', 'Condition (%)', 'Fatigue', 'Match Sharpness',
            'Natural Fitness', 'Stamina', 'Work Rate',
            'GoalKeeper', 'Defender Right', 'Defender Center', 'Defender Left',
            'Defensive Midfielder', 'Attacking Mid. Right', 'Attacking Mid. Center',
            'Attacking Mid. Left', 'Striker'
        ]

        for col in numeric_columns:
            if col in self.df.columns:
                self.df[col] = pd.to_numeric(self.df[col], errors='coerce')

        # Position mapping for 4-2-3-1
        self.position_mapping = {
            'GK': 'GoalKeeper',
            'DL': 'Defender Left',
            'DC1': 'Defender Center',
            'DC2': 'Defender Center',
            'DR': 'Defender Right',
            'DM(L)': 'Defensive Midfielder',
            'DM(R)': 'Defensive Midfielder',
            'AML': 'Attacking Mid. Left',
            'AMC': 'Attacking Mid. Center',
            'AMR': 'Attacking Mid. Right',
            'STC': 'Striker'
        }

        # Default formation
        self.formation = [
            ('GK', 'GoalKeeper'),
            ('DL', 'Defender Left'),
            ('DC1', 'Defender Center'),
            ('DC2', 'Defender Center'),
            ('DR', 'Defender Right'),
            ('DM(L)', 'Defensive Midfielder'),
            ('DM(R)', 'Defensive Midfielder'),
            ('AML', 'Attacking Mid. Left'),
            ('AMC', 'Attacking Mid. Center'),
            ('AMR', 'Attacking Mid. Right'),
            ('STC', 'Striker')
        ]

        # Store selections for multiple matches
        self.match_selections = []

    def calculate_effective_rating(self, row: pd.Series, position_col: str,
                                   match_importance: str = 'Medium',
                                   prioritize_sharpness: bool = False) -> float:
        """
        Calculate effective rating considering all factors.

        Args:
            row: Player data row
            position_col: Position column name
            match_importance: 'Low', 'Medium', or 'High'
            prioritize_sharpness: Give minutes to low-sharpness players

        Returns:
            Effective rating (lower is worse, can be negative)
        """
        # Check if player is available
        if row.get('Is Injured', False) or row.get('Banned', False):
            return -999.0

        # Get base positional rating
        base_rating = row.get(position_col, 0)
        if pd.isna(base_rating) or base_rating < 1:
            return -999.0

        # Start with base rating
        effective_rating = float(base_rating)

        # 1. Apply positional familiarity penalty
        familiarity_penalty = self._get_familiarity_penalty(base_rating)
        effective_rating *= (1 - familiarity_penalty)

        # 2. Match sharpness factor (5000-10000 scale)
        match_sharpness = row.get('Match Sharpness', 10000)
        if pd.notna(match_sharpness):
            sharpness_pct = match_sharpness / 10000

            if prioritize_sharpness and sharpness_pct < 0.85:
                # BOOST rating for low-sharpness players in unimportant matches
                # This encourages giving them minutes to build sharpness
                effective_rating *= 1.1
            else:
                # Standard penalty for low sharpness
                if sharpness_pct < 0.60:
                    effective_rating *= 0.70  # Severe penalty
                elif sharpness_pct < 0.75:
                    effective_rating *= 0.85  # Moderate penalty
                elif sharpness_pct < 0.85:
                    effective_rating *= 0.95  # Minor penalty

        # 3. Physical condition factor (percentage)
        condition = row.get('Condition (%)', 100)
        if pd.notna(condition):
            # Normalize to 0-100 scale if stored as 0-10000
            if condition > 100:
                condition = condition / 100

            if condition < 60:
                effective_rating *= 0.60  # Severe penalty, injury risk
            elif condition < 75:
                effective_rating *= 0.80  # Moderate penalty
            elif condition < 90:
                effective_rating *= 0.95  # Minor penalty

        # 4. Fatigue penalty (critical threshold at 400)
        fatigue = row.get('Fatigue', 0)
        if pd.notna(fatigue):
            if fatigue >= 500:
                effective_rating *= 0.65  # Severe penalty
            elif fatigue >= 400:
                effective_rating *= 0.85  # Moderate penalty
            # Negative fatigue (under-conditioned) also gets small penalty
            elif fatigue < -200:
                effective_rating *= 0.90

        # 5. Match importance modifier
        # For high-importance matches, further penalize unfit players
        if match_importance == 'High':
            if fatigue >= 400 or condition < 80:
                effective_rating *= 0.85  # Extra penalty in important matches
        elif match_importance == 'Low' and prioritize_sharpness:
            # In low-importance matches, we can afford to rest key players
            # This is handled by the sharpness boost above
            pass

        return effective_rating

    def _get_familiarity_penalty(self, rating: float) -> float:
        """Get penalty percentage based on positional rating tier."""
        if pd.isna(rating):
            return 0.40
        elif rating >= 18:  # Natural
            return 0.00
        elif rating >= 13:  # Accomplished
            return 0.10
        elif rating >= 10:  # Competent
            return 0.15
        elif rating >= 6:   # Unconvincing
            return 0.20
        elif rating >= 5:   # Awkward
            return 0.35
        else:               # Ineffectual
            return 0.40

    def select_match_xi(self, match_importance: str = 'Medium',
                       prioritize_sharpness: bool = False,
                       rested_players: List[str] = None) -> Dict:
        """
        Select optimal XI for a specific match.

        Args:
            match_importance: 'Low', 'Medium', or 'High'
            prioritize_sharpness: Give playing time to low-sharpness players
            rested_players: List of player names to rest (avoid selecting)

        Returns:
            Dictionary mapping position to (player_name, effective_rating, player_data)
        """
        if rested_players is None:
            rested_players = []

        n_players = len(self.df)
        n_positions = len(self.formation)

        # Create cost matrix (negative effective ratings for minimization)
        cost_matrix = np.full((n_players, n_positions), -999.0)

        # Fill cost matrix
        for i, player_idx in enumerate(self.df.index):
            player = self.df.loc[player_idx]

            # Skip rested players
            if player['Name'] in rested_players:
                continue

            for j, (pos_name, col_name) in enumerate(self.formation):
                effective_rating = self.calculate_effective_rating(
                    player, col_name, match_importance, prioritize_sharpness
                )

                if effective_rating > -999.0:
                    cost_matrix[i, j] = -effective_rating  # Negative for minimization

        # Solve assignment problem
        row_ind, col_ind = linear_sum_assignment(cost_matrix)

        # Build selection dictionary
        selection = {}
        for i, j in zip(row_ind, col_ind):
            if cost_matrix[i, j] > -998:  # Valid assignment
                player = self.df.loc[self.df.index[i]]
                pos_name, col_name = self.formation[j]
                effective_rating = -cost_matrix[i, j]

                selection[pos_name] = (player['Name'], effective_rating, player)

        return selection

    def plan_rotation(self, current_date_str: str, matches: List[Tuple[str, str]]):
        """
        Plan rotation across multiple matches.

        Args:
            current_date_str: Current date in format 'YYYY-MM-DD'
            matches: List of (date_str, importance) tuples for upcoming matches
        """
        print("\n" + "=" * 100)
        print("MATCH SCHEDULE AND ROTATION PLANNING")
        print("=" * 100)
        print(f"\nCurrent Date: {current_date_str}")
        print("\nUpcoming Matches:")

        try:
            current_date = datetime.strptime(current_date_str, '%Y-%m-%d')
        except ValueError:
            print("Error: Current date must be in YYYY-MM-DD format")
            return

        match_dates = []
        for i, (date_str, importance) in enumerate(matches, 1):
            try:
                match_date = datetime.strptime(date_str, '%Y-%m-%d')
                days_until = (match_date - current_date).days
                match_dates.append((match_date, importance, days_until))
                print(f"  {i}. {date_str} ({days_until} days) - {importance} importance")
            except ValueError:
                print(f"  Error: Match date '{date_str}' must be in YYYY-MM-DD format")
                return

        print("\n" + "=" * 100)

        # Plan selection for each match
        self.match_selections = []
        players_to_rest = []

        for i, (match_date, importance, days_until) in enumerate(match_dates):
            print(f"\n{'=' * 100}")
            print(f"LINEUP FOR MATCH {i+1}: {match_date.strftime('%Y-%m-%d')} ({importance} importance, {days_until} days)")
            print("=" * 100)

            # Determine selection strategy
            prioritize_sharpness = (importance == 'Low')

            # If high-importance match is coming soon, rest high-fatigue players
            if i < len(match_dates) - 1:
                next_match_date, next_importance, next_days = match_dates[i + 1]
                if next_importance == 'High' and days_until <= 3:
                    # Rest high-fatigue players before important match
                    players_to_rest = self._identify_players_to_rest()
                    if players_to_rest:
                        print(f"\nResting players before important match on {next_match_date.strftime('%Y-%m-%d')}:")
                        for player_name in players_to_rest:
                            print(f"  ⚠ {player_name}")
                        print()

            # Select XI
            selection = self.select_match_xi(importance, prioritize_sharpness, players_to_rest)
            self.match_selections.append((match_date, importance, selection))

            # Display selection
            self._print_match_selection(selection, importance, prioritize_sharpness)

            # Clear rest list for next iteration
            players_to_rest = []

        # Print rotation summary
        self._print_rotation_summary()

    def _identify_players_to_rest(self) -> List[str]:
        """Identify players who should be rested (high fatigue or low condition)."""
        rest_candidates = []

        for idx, row in self.df.iterrows():
            fatigue = row.get('Fatigue', 0)
            condition = row.get('Condition (%)', 100)

            # Normalize condition if needed
            if condition > 100:
                condition = condition / 100

            # Rest if fatigue >= 400 or condition < 75%
            if (pd.notna(fatigue) and fatigue >= 400) or (pd.notna(condition) and condition < 75):
                rest_candidates.append(row['Name'])

        return rest_candidates

    def _print_match_selection(self, selection: Dict, importance: str, prioritize_sharpness: bool):
        """Print formatted match selection."""
        if not selection:
            print("ERROR: Could not select a full team!")
            return

        # Calculate team average
        total_rating = sum(eff_rating for _, eff_rating, _ in selection.values())
        avg_rating = total_rating / len(selection) if selection else 0

        print("\nStarting XI:")
        print()

        # Group by formation sections
        formation_display = {
            'Goalkeeper': ['GK'],
            'Defence': ['DL', 'DC1', 'DC2', 'DR'],
            'Defensive Midfield': ['DM(L)', 'DM(R)'],
            'Attacking Midfield': ['AML', 'AMC', 'AMR'],
            'Striker': ['STC']
        }

        for section, positions in formation_display.items():
            print(f"{section}:")
            for pos in positions:
                if pos in selection:
                    player_name, eff_rating, player_data = selection[pos]

                    # Get status indicators
                    condition = player_data.get('Condition (%)', 100)
                    if condition > 100:
                        condition = condition / 100
                    fatigue = player_data.get('Fatigue', 0)
                    sharpness = player_data.get('Match Sharpness', 10000) / 10000

                    # Status icons
                    status_icons = []
                    if fatigue >= 400:
                        status_icons.append('💤')  # Fatigued
                    if condition < 80:
                        status_icons.append('❤️')  # Low condition
                    if sharpness < 0.80:
                        status_icons.append('🔄')  # Needs sharpness
                    if sharpness >= 0.95 and condition >= 90 and fatigue < 200:
                        status_icons.append('⭐')  # Peak form

                    status_str = ' '.join(status_icons) if status_icons else ''

                    print(f"  {pos:6}: {player_name:25} "
                          f"(Eff: {eff_rating:4.1f}) "
                          f"[Cond: {condition:3.0f}% | Fatigue: {fatigue:4.0f} | Sharp: {sharpness:3.0%}] "
                          f"{status_str}")
                else:
                    print(f"  {pos:6}: NO PLAYER FOUND")
            print()

        print("=" * 100)
        print(f"Team Average Effective Rating: {avg_rating:.2f}")
        if prioritize_sharpness:
            print("Strategy: Prioritizing match sharpness development for fringe players")
        print("=" * 100)

        # Legend
        print("\nSTATUS ICONS:")
        print("  ⭐ Peak form (high condition, low fatigue, sharp)")
        print("  💤 High fatigue (≥400, needs rest)")
        print("  ❤️  Low condition (<80%, injury risk)")
        print("  🔄 Needs match sharpness (<80%)")

    def _print_rotation_summary(self):
        """Print summary of player usage across matches."""
        print("\n" + "=" * 100)
        print("ROTATION SUMMARY")
        print("=" * 100)

        # Count appearances for each player
        player_appearances = {}

        for match_date, importance, selection in self.match_selections:
            for pos, (player_name, eff_rating, player_data) in selection.items():
                if player_name not in player_appearances:
                    player_appearances[player_name] = []
                player_appearances[player_name].append((match_date, pos))

        # Sort by number of appearances
        sorted_players = sorted(player_appearances.items(),
                               key=lambda x: len(x[1]), reverse=True)

        print(f"\nPlayer appearances across {len(self.match_selections)} matches:\n")

        for player_name, appearances in sorted_players:
            match_count = len(appearances)
            positions = ', '.join([pos for _, pos in appearances])
            print(f"  {player_name:25} - {match_count} matches  ({positions})")

        # Identify players who didn't play
        all_players = set(self.df['Name'].values)
        playing_players = set(player_appearances.keys())
        unused_players = all_players - playing_players

        if unused_players:
            print(f"\nPlayers not selected (consider for reserves/friendlies for sharpness):")
            for player in sorted(unused_players):
                player_data = self.df[self.df['Name'] == player].iloc[0]
                sharpness = player_data.get('Match Sharpness', 10000) / 10000
                print(f"  {player:25} - Sharpness: {sharpness:3.0%}")

        print("=" * 100)

    def suggest_training_focus(self):
        """Suggest training focus based on current squad status."""
        print("\n" + "=" * 100)
        print("TRAINING RECOMMENDATIONS")
        print("=" * 100)

        high_fatigue_count = 0
        low_condition_count = 0
        low_sharpness_count = 0

        for idx, row in self.df.iterrows():
            fatigue = row.get('Fatigue', 0)
            condition = row.get('Condition (%)', 100)
            sharpness = row.get('Match Sharpness', 10000) / 10000

            if condition > 100:
                condition = condition / 100

            if fatigue >= 400:
                high_fatigue_count += 1
            if condition < 80:
                low_condition_count += 1
            if sharpness < 0.80:
                low_sharpness_count += 1

        print("\nSquad Status:")
        print(f"  Players with high fatigue (≥400):     {high_fatigue_count}")
        print(f"  Players with low condition (<80%):    {low_condition_count}")
        print(f"  Players with low sharpness (<80%):    {low_sharpness_count}")
        print()

        recommendations = []

        if high_fatigue_count >= 5:
            recommendations.append("⚠️  HIGH PRIORITY: Schedule rest sessions - many players fatigued")
            recommendations.append("   Consider sending 1-2 most fatigued players on vacation")

        if low_condition_count >= 5:
            recommendations.append("⚠️  MEDIUM PRIORITY: Reduce training intensity this week")
            recommendations.append("   Use recovery sessions instead of intensive training")

        if low_sharpness_count >= 8:
            recommendations.append("⚠️  MEDIUM PRIORITY: Schedule friendly matches for fringe players")
            recommendations.append("   Consider match practice sessions in training")

        if not recommendations:
            recommendations.append("✅ Squad fitness is good - continue current training schedule")

        print("Recommendations:")
        for rec in recommendations:
            print(f"  {rec}")

        print("\n" + "=" * 100)


def main():
    """Main execution function."""
    # Get file path from command line or use default
    if len(sys.argv) > 1:
        filepath = sys.argv[1]
    else:
        import os
        if os.path.exists('players-current.csv'):
            filepath = 'players-current.csv'
        elif os.path.exists('players.csv'):
            filepath = 'players.csv'
        elif os.path.exists('players.xlsx'):
            filepath = 'players.xlsx'
        else:
            print("Error: No player data file found!")
            print("Usage: python fm_match_ready_selector.py <path_to_player_data.csv>")
            sys.exit(1)

    print(f"\nLoading player data from: {filepath}")

    try:
        selector = MatchReadySelector(filepath)

        # Interactive input for match planning
        print("\n" + "=" * 100)
        print("FM26 MATCH-READY LINEUP SELECTOR")
        print("=" * 100)

        current_date = input("\nEnter current date (YYYY-MM-DD): ").strip()

        matches = []
        print("\nEnter details for next 3 matches:")

        for i in range(3):
            print(f"\nMatch {i+1}:")
            match_date = input("  Date (YYYY-MM-DD): ").strip()
            importance = input("  Importance (Low/Medium/High): ").strip().capitalize()

            if importance not in ['Low', 'Medium', 'High']:
                importance = 'Medium'

            matches.append((match_date, importance))

        # Plan rotation
        selector.plan_rotation(current_date, matches)

        # Training recommendations
        selector.suggest_training_focus()

    except FileNotFoundError:
        print(f"\nError: File '{filepath}' not found!")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n\nOperation cancelled by user.")
        sys.exit(0)
    except Exception as e:
        print(f"\nError: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
