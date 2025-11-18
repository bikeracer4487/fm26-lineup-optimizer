#!/usr/bin/env python3
"""
FM26 Training Distribution Advisor
Recommends optimal training distribution based on squad depth analysis,
player attributes, and positional skill ratings.

Author: Doug Mason (2025)
"""

import sys
import pandas as pd
import numpy as np
from typing import Dict, List, Tuple


class TrainingAdvisor:
    """Analyzes squad and recommends position training for players."""

    def __init__(self, filepath: str):
        """
        Initialize the training advisor with player data.

        Args:
            filepath: Path to CSV file containing player data
        """
        # Load data
        if filepath.endswith('.csv'):
            self.df = pd.read_csv(filepath, encoding='utf-8-sig')
        else:
            self.df = pd.read_excel(filepath)

        # Clean up column names (remove BOM and extra spaces)
        self.df.columns = self.df.columns.str.strip()

        # Convert numeric columns
        numeric_columns = [
            'Age', 'CA', 'PA', 'Versatility', 'Professionalism',
            'GoalKeeper', 'Defender Right', 'Defender Center', 'Defender Left',
            'Defensive Midfielder', 'Attacking Mid. Right', 'Attacking Mid. Center',
            'Attacking Mid. Left', 'Striker'
        ]

        for col in numeric_columns:
            if col in self.df.columns:
                self.df[col] = pd.to_numeric(self.df[col], errors='coerce')

        # Define position mappings for 4-2-3-1 formation
        self.position_mapping = {
            'GK': 'GoalKeeper',
            'D(R)': 'Defender Right',
            'D(C)': 'Defender Center',
            'D(L)': 'Defender Left',
            'DM': 'Defensive Midfielder',
            'AM(R)': 'Attacking Mid. Right',
            'AM(C)': 'Attacking Mid. Center',
            'AM(L)': 'Attacking Mid. Left',
            'ST': 'Striker'
        }

        # Positions needed for 4-2-3-1 formation
        self.formation_needs = {
            'GK': 1,
            'D(R)': 1,
            'D(C)': 2,
            'D(L)': 1,
            'DM': 2,
            'AM(R)': 1,
            'AM(C)': 1,
            'AM(L)': 1,
            'ST': 1
        }

    def get_positional_familiarity_tier(self, rating: float) -> str:
        """Convert positional rating to familiarity tier."""
        if pd.isna(rating) or rating < 1:
            return 'Ineffectual'
        elif rating <= 4:
            return 'Ineffectual'
        elif rating <= 8:
            return 'Awkward'
        elif rating <= 9:
            return 'Unconvincing'
        elif rating <= 12:
            return 'Competent'
        elif rating <= 17:
            return 'Accomplished'
        else:  # 18-20
            return 'Natural'

    def analyze_squad_depth(self) -> Dict[str, List[Tuple[str, float, str]]]:
        """
        Analyze squad depth for each position.

        Returns:
            Dictionary mapping positions to list of (player_name, rating, tier) tuples
        """
        depth_analysis = {}

        for pos_name, col_name in self.position_mapping.items():
            if col_name not in self.df.columns:
                continue

            # Get all players with ratings for this position
            players_data = []
            for idx, row in self.df.iterrows():
                rating = row[col_name]
                if pd.notna(rating) and rating >= 1:
                    tier = self.get_positional_familiarity_tier(rating)
                    players_data.append((row['Name'], rating, tier))

            # Sort by rating (descending)
            players_data.sort(key=lambda x: x[1], reverse=True)
            depth_analysis[pos_name] = players_data

        return depth_analysis

    def identify_depth_gaps(self, depth_analysis: Dict) -> Dict[str, int]:
        """
        Identify positions with insufficient depth.

        Args:
            depth_analysis: Output from analyze_squad_depth()

        Returns:
            Dictionary mapping positions to shortage count
        """
        gaps = {}

        for pos_name, needed_count in self.formation_needs.items():
            if pos_name not in depth_analysis:
                gaps[pos_name] = needed_count
                continue

            # Count players who are at least Competent (rating >= 10)
            competent_players = [p for p in depth_analysis[pos_name] if p[1] >= 10]

            # We want at least 2 competent players per position (starter + backup)
            target = max(2, needed_count)
            shortage = target - len(competent_players)

            if shortage > 0:
                gaps[pos_name] = shortage

        return gaps

    def recommend_training(self) -> List[Dict]:
        """
        Generate training recommendations for players.

        Returns:
            List of dictionaries with training recommendations
        """
        depth_analysis = self.analyze_squad_depth()
        gaps = self.identify_depth_gaps(depth_analysis)

        recommendations = []

        # For each position gap, find best candidates to retrain
        for pos_name, shortage in gaps.items():
            col_name = self.position_mapping[pos_name]

            # Find candidates for retraining to this position
            candidates = []

            for idx, row in self.df.iterrows():
                name = row['Name']
                age = row.get('Age', 99)
                current_rating = row.get(col_name, 0)
                tier = self.get_positional_familiarity_tier(current_rating)

                # Skip if already competent or better
                if current_rating >= 10:
                    continue

                # Prefer younger players (under 24 is ideal)
                age_factor = max(0, 24 - age) / 24 if pd.notna(age) else 0.5

                # Check versatility (if available)
                versatility = row.get('Versatility', 10)
                versatility_factor = versatility / 20 if pd.notna(versatility) else 0.5

                # Check if player has some existing familiarity
                familiarity_bonus = current_rating / 20 if pd.notna(current_rating) else 0

                # Calculate suitability score
                suitability = (age_factor * 0.4) + (versatility_factor * 0.4) + (familiarity_bonus * 0.2)

                # Check if player is natural in similar positions
                similar_positions = self._get_similar_positions(pos_name)
                has_similar_natural = False
                for sim_pos in similar_positions:
                    if sim_pos in self.position_mapping:
                        sim_col = self.position_mapping[sim_pos]
                        if sim_col in row and pd.notna(row[sim_col]) and row[sim_col] >= 18:
                            has_similar_natural = True
                            suitability += 0.2  # Bonus for similar position mastery
                            break

                candidates.append({
                    'name': name,
                    'age': age,
                    'current_rating': current_rating,
                    'tier': tier,
                    'suitability': suitability,
                    'versatility': versatility,
                    'has_similar_natural': has_similar_natural
                })

            # Sort candidates by suitability
            candidates.sort(key=lambda x: x['suitability'], reverse=True)

            # Recommend top candidates
            for i, candidate in enumerate(candidates[:shortage + 2]):  # +2 for alternatives
                recommendation = {
                    'player': candidate['name'],
                    'position': pos_name,
                    'current_tier': candidate['tier'],
                    'current_rating': candidate['current_rating'],
                    'age': candidate['age'],
                    'priority': 'High' if i < shortage else 'Medium',
                    'reason': self._generate_recommendation_reason(candidate, pos_name, shortage)
                }
                recommendations.append(recommendation)

        return recommendations

    def _get_similar_positions(self, position: str) -> List[str]:
        """Get positions that are similar (easier to retrain between)."""
        similarity_groups = {
            'D(R)': ['D(L)', 'DM'],
            'D(L)': ['D(R)', 'DM'],
            'D(C)': ['DM'],
            'DM': ['D(C)', 'D(R)', 'D(L)', 'AM(C)'],
            'AM(R)': ['AM(L)', 'AM(C)', 'ST'],
            'AM(L)': ['AM(R)', 'AM(C)', 'ST'],
            'AM(C)': ['AM(R)', 'AM(L)', 'DM', 'ST'],
            'ST': ['AM(C)', 'AM(R)', 'AM(L)'],
            'GK': []
        }
        return similarity_groups.get(position, [])

    def _generate_recommendation_reason(self, candidate: Dict, position: str, shortage: int) -> str:
        """Generate human-readable reason for recommendation."""
        reasons = []

        if candidate['age'] < 24:
            reasons.append(f"young age ({candidate['age']})")

        if candidate['versatility'] >= 15:
            reasons.append("high versatility")

        if candidate['has_similar_natural']:
            reasons.append("natural in similar position")

        if candidate['current_rating'] >= 6:
            reasons.append(f"some existing familiarity ({candidate['tier']})")

        if not reasons:
            reasons.append("squad depth need")

        return f"Good candidate due to: {', '.join(reasons)}"

    def print_depth_analysis(self):
        """Print formatted depth analysis report."""
        depth_analysis = self.analyze_squad_depth()
        gaps = self.identify_depth_gaps(depth_analysis)

        print("=" * 90)
        print("SQUAD DEPTH ANALYSIS FOR 4-2-3-1 FORMATION")
        print("=" * 90)
        print()

        for pos_name in ['GK', 'D(L)', 'D(C)', 'D(R)', 'DM', 'AM(L)', 'AM(C)', 'AM(R)', 'ST']:
            players_data = depth_analysis.get(pos_name, [])
            needed = self.formation_needs.get(pos_name, 1)

            print(f"{pos_name:8} (Need {needed} in XI, want 2+ competent):")

            if not players_data:
                print(f"  {'NO PLAYERS AVAILABLE':40} - CRITICAL GAP!")
            else:
                for i, (name, rating, tier) in enumerate(players_data[:5], 1):  # Top 5
                    status = "✓" if rating >= 10 else "⚠"
                    print(f"  {status} {name:30} {tier:15} ({rating:.1f}/20)")

            # Show gap if exists
            if pos_name in gaps:
                print(f"  >>> DEPTH GAP: Need {gaps[pos_name]} more competent player(s)")

            print()

        print("=" * 90)

    def print_training_recommendations(self):
        """Print formatted training recommendations."""
        recommendations = self.recommend_training()

        if not recommendations:
            print("\n" + "=" * 90)
            print("TRAINING RECOMMENDATIONS")
            print("=" * 90)
            print("\nNo training recommendations needed - squad depth is adequate at all positions!")
            print("=" * 90)
            return

        print("\n" + "=" * 90)
        print("TRAINING RECOMMENDATIONS")
        print("=" * 90)
        print("\nThe following players should be trained in new positions to improve squad depth:")
        print()

        # Group by priority
        high_priority = [r for r in recommendations if r['priority'] == 'High']
        medium_priority = [r for r in recommendations if r['priority'] == 'Medium']

        if high_priority:
            print("HIGH PRIORITY (Critical depth gaps):")
            print("-" * 90)
            for rec in high_priority:
                print(f"  Player: {rec['player']:25} → Train as: {rec['position']:8}")
                print(f"         Current: {rec['current_tier']:15} ({rec['current_rating']:.1f}/20)")
                print(f"         Age: {rec['age']:2}  |  {rec['reason']}")
                print()

        if medium_priority:
            print("MEDIUM PRIORITY (Additional depth options):")
            print("-" * 90)
            for rec in medium_priority:
                print(f"  Player: {rec['player']:25} → Train as: {rec['position']:8}")
                print(f"         Current: {rec['current_tier']:15} ({rec['current_rating']:.1f}/20)")
                print(f"         Age: {rec['age']:2}  |  {rec['reason']}")
                print()

        print("=" * 90)
        print("\nTRAINING TIMELINE EXPECTATIONS:")
        print("  • Competent level (10/20):  6-9 months of training + match experience")
        print("  • Accomplished level (13+): 12 months of training + regular playing time")
        print("  • Natural level (18+):      12-24 months (requires consistent matches)")
        print("\nKEY FACTORS:")
        print("  • Younger players (under 24) learn faster")
        print("  • High Versatility attribute accelerates retraining significantly")
        print("  • Players need both individual training AND match experience")
        print("  • Similar positions retrain faster (e.g., DL → DR, AM(C) → ST)")
        print("=" * 90)


def main():
    """Main execution function."""
    # Get file path from command line or use default
    if len(sys.argv) > 1:
        filepath = sys.argv[1]
    else:
        # Try common filenames
        import os
        if os.path.exists('players-current.csv'):
            filepath = 'players-current.csv'
        elif os.path.exists('players.csv'):
            filepath = 'players.csv'
        elif os.path.exists('players.xlsx'):
            filepath = 'players.xlsx'
        else:
            print("Error: No player data file found!")
            print("Usage: python fm_training_advisor.py <path_to_player_data.csv>")
            sys.exit(1)

    print(f"\nLoading player data from: {filepath}")

    try:
        advisor = TrainingAdvisor(filepath)
        advisor.print_depth_analysis()
        advisor.print_training_recommendations()

    except FileNotFoundError:
        print(f"\nError: File '{filepath}' not found!")
        sys.exit(1)
    except Exception as e:
        print(f"\nError: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
