#!/usr/bin/env python3
"""
FM26 Training Distribution Advisor
Recommends optimal training distribution based on squad depth analysis,
player role abilities, positional skill ratings, and training attributes.

Author: Doug Mason (2025)
"""

import sys
import pandas as pd
import numpy as np
from typing import Dict, List, Tuple, Optional


class TrainingAdvisor:
    """Analyzes squad and recommends position training for players."""

    def __init__(self, status_filepath: str, abilities_filepath: Optional[str] = None):
        """
        Initialize the training advisor with player data.

        Args:
            status_filepath: Path to CSV with positional skill ratings & attributes (players-current.csv)
            abilities_filepath: Optional path to CSV with role ability ratings (players.csv)
        """
        # Load status/attributes file (players-current.csv)
        if status_filepath.endswith('.csv'):
            self.status_df = pd.read_csv(status_filepath, encoding='utf-8-sig')
        else:
            self.status_df = pd.read_excel(status_filepath)

        self.status_df.columns = self.status_df.columns.str.strip()

        # Load abilities file if provided (players.csv)
        self.has_abilities = False
        if abilities_filepath:
            if abilities_filepath.endswith('.csv'):
                self.abilities_df = pd.read_csv(abilities_filepath, encoding='utf-8-sig')
            else:
                self.abilities_df = pd.read_excel(abilities_filepath)

            self.abilities_df.columns = self.abilities_df.columns.str.strip()

            # Check if abilities file has the required role ability columns
            required_cols = ['Name', 'Striker', 'AM(L)', 'AM(C)', 'AM(R)',
                           'DM(L)', 'DM(R)', 'D(C)', 'D(R/L)', 'GK']
            if all(col in self.abilities_df.columns for col in required_cols):
                # Merge on player name with suffixes to distinguish
                self.df = pd.merge(
                    self.status_df,
                    self.abilities_df[required_cols],
                    on='Name',
                    how='left',
                    suffixes=('_skill', '_ability')
                )
                self.has_abilities = True
            else:
                print("\nWARNING: Abilities file missing required columns. Using status file only.")
                self.df = self.status_df.copy()
        else:
            # Use status file only - no quality analysis possible
            self.df = self.status_df.copy()
            print("\nWARNING: No role abilities file provided. Quality analysis will be limited.")
            print("For best results, export role ability ratings to players.csv and provide both files.")
            print("The role ability file should have columns: Striker, AM(L), AM(C), AM(R), DM(L), DM(R), D(C), D(R/L), GK")
            print("These show how GOOD players are at each role (based on attributes), different from positional skill ratings!\n")

        # Convert numeric columns
        numeric_columns = [
            'Age', 'CA', 'PA', 'Versatility', 'Professionalism', 'Determination',
            'Natural Fitness', 'Stamina', 'Work Rate', 'Adaptability',
            # Positional skill ratings (1-20 familiarity scale)
            'GoalKeeper', 'Defender Right', 'Defender Center', 'Defender Left',
            'Defensive Midfielder', 'Attacking Mid. Right', 'Attacking Mid. Center',
            'Attacking Mid. Left', 'Striker'
        ]

        # Add role ability columns if they exist
        ability_columns = ['Striker', 'AM(L)', 'AM(C)', 'AM(R)', 'DM(L)', 'DM(R)',
                          'D(C)', 'D(R/L)', 'GK']
        for col in ability_columns:
            if col in self.df.columns:
                numeric_columns.append(col)

        for col in numeric_columns:
            if col in self.df.columns:
                self.df[col] = pd.to_numeric(self.df[col], errors='coerce')

        # Create DM_avg for abilities if we have them
        if 'DM(L)' in self.df.columns and 'DM(R)' in self.df.columns:
            self.df['DM_avg'] = (self.df['DM(L)'] + self.df['DM(R)']) / 2

        # Position mappings
        # Format: Position display name -> (skill rating column, ability rating column or None)
        # Note: "Striker" appears in both files, so after merge it becomes "Striker_skill" and "Striker_ability"
        if self.has_abilities:
            self.position_mapping = {
                'GK': ('GoalKeeper', 'GK'),
                'D(R)': ('Defender Right', 'D(R/L)'),
                'D(C)': ('Defender Center', 'D(C)'),
                'D(L)': ('Defender Left', 'D(R/L)'),
                'DM': ('Defensive Midfielder', 'DM_avg'),
                'AM(R)': ('Attacking Mid. Right', 'AM(R)'),
                'AM(C)': ('Attacking Mid. Center', 'AM(C)'),
                'AM(L)': ('Attacking Mid. Left', 'AM(L)'),
                'ST': ('Striker_skill', 'Striker_ability')  # Different from others due to name collision
            }
        else:
            # No abilities data - only skill ratings
            self.position_mapping = {
                'GK': ('GoalKeeper', None),
                'D(R)': ('Defender Right', None),
                'D(C)': ('Defender Center', None),
                'D(L)': ('Defender Left', None),
                'DM': ('Defensive Midfielder', None),
                'AM(R)': ('Attacking Mid. Right', None),
                'AM(C)': ('Attacking Mid. Center', None),
                'AM(L)': ('Attacking Mid. Left', None),
                'ST': ('Striker', None)
            }

        # Formation needs for 4-2-3-1
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

        # Note: Role ability ratings are on 0-200 scale
        # Quality will be determined relative to squad distribution (percentiles)

    def get_positional_familiarity_tier(self, rating: float) -> str:
        """Convert positional skill rating to familiarity tier."""
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

    def calculate_position_percentiles(self, position_col: str) -> Dict[str, float]:
        """
        Calculate percentile thresholds for a position based on squad distribution.

        Args:
            position_col: Column name for the position's ability ratings

        Returns:
            Dictionary with percentile thresholds
        """
        if position_col not in self.df.columns:
            return {
                'p90': 160,  # Fallback values
                'p75': 140,
                'p50': 120,
                'p25': 100
            }

        # Get all valid ability ratings for this position
        abilities = self.df[position_col].dropna()

        if len(abilities) == 0:
            return {
                'p90': 160,
                'p75': 140,
                'p50': 120,
                'p25': 100
            }

        return {
            'p90': abilities.quantile(0.90),  # Top 10%
            'p75': abilities.quantile(0.75),  # Top 25%
            'p50': abilities.quantile(0.50),  # Median
            'p25': abilities.quantile(0.25)   # Bottom 25%
        }

    def get_quality_tier(self, ability: float, percentiles: Dict[str, float]) -> str:
        """
        Get quality tier for role ability rating using squad-relative percentiles.

        Args:
            ability: Player's ability rating at the position (0-200 scale)
            percentiles: Percentile thresholds for this position

        Returns:
            Quality tier string
        """
        if pd.isna(ability):
            return 'Unknown'
        elif ability >= percentiles['p90']:
            return 'Excellent'  # Top 10% of squad
        elif ability >= percentiles['p75']:
            return 'Good'       # Top 25% of squad
        elif ability >= percentiles['p50']:
            return 'Adequate'   # Above median
        elif ability >= percentiles['p25']:
            return 'Poor'       # Below median
        else:
            return 'Inadequate' # Bottom 25%

    def analyze_squad_depth_quality(self) -> Dict[str, List[Tuple]]:
        """
        Analyze squad depth considering both familiarity AND ability.

        Returns:
            Dictionary mapping positions to list of (name, skill_rating, ability_rating, tiers) tuples
        """
        depth_analysis = {}

        for pos_name, (skill_col, ability_col) in self.position_mapping.items():
            players_data = []

            # Calculate percentiles for this position
            percentiles = self.calculate_position_percentiles(ability_col) if ability_col else None

            for idx, row in self.df.iterrows():
                skill_rating = row.get(skill_col, 0)
                ability_rating = row.get(ability_col, np.nan) if (ability_col and ability_col in self.df.columns) else np.nan

                # Only include if they have some familiarity OR good ability
                if pd.notna(skill_rating) and skill_rating >= 1:
                    skill_tier = self.get_positional_familiarity_tier(skill_rating)
                    ability_tier = self.get_quality_tier(ability_rating, percentiles) if percentiles else 'Unknown'

                    players_data.append((
                        row['Name'],
                        skill_rating,
                        ability_rating,
                        skill_tier,
                        ability_tier
                    ))

            # Sort by ability first (if available), then skill rating
            def sort_key(x):
                ability = x[2] if pd.notna(x[2]) else 0
                skill = x[1]
                return (-ability, -skill)

            players_data.sort(key=sort_key)
            depth_analysis[pos_name] = players_data

        return depth_analysis

    def identify_quality_gaps(self, depth_analysis: Dict) -> Dict[str, Dict]:
        """
        Identify positions with insufficient quality depth using squad-relative criteria.

        Returns:
            Dictionary mapping positions to gap analysis including shortage counts and quality levels
        """
        gaps = {}

        for pos_name, needed_count in self.formation_needs.items():
            if pos_name not in depth_analysis:
                gaps[pos_name] = {
                    'total_shortage': needed_count,
                    'quality_shortage': needed_count,
                    'current_quality': []
                }
                continue

            players_data = depth_analysis[pos_name]
            skill_col, ability_col = self.position_mapping[pos_name]

            # Count competent players (skill >= 10)
            competent_players = [p for p in players_data if p[1] >= 10]

            # Count good quality players (top 25% of squad at this position)
            # Players with 'Good' or 'Excellent' tier
            good_players = [p for p in players_data if p[4] in ['Good', 'Excellent']]

            # Count USABLE good players (both competent familiarity AND good ability)
            usable_good_players = [p for p in players_data if p[1] >= 10 and p[4] in ['Good', 'Excellent']]

            # Count good ability players who AREN'T competent yet (training candidates)
            good_but_not_competent = [p for p in players_data if p[1] < 10 and p[4] in ['Good', 'Excellent']]

            # We want:
            # - At least 2 competent players per position
            # - At least as many USABLE good quality players as needed in formation
            target_competent = max(2, needed_count)
            target_usable_good = needed_count

            competent_shortage = max(0, target_competent - len(competent_players))
            quality_shortage = max(0, target_usable_good - len(usable_good_players))

            # If we have good ability players who aren't competent, that's also a gap worth addressing
            has_training_potential = len(good_but_not_competent) > 0

            if competent_shortage > 0 or quality_shortage > 0 or has_training_potential:
                gaps[pos_name] = {
                    'total_shortage': competent_shortage,
                    'quality_shortage': quality_shortage,
                    'training_potential': len(good_but_not_competent),
                    'current_quality': [p for p in players_data[:5]]  # Top 5 for context
                }

        return gaps

    def recommend_training(self) -> List[Dict]:
        """
        Generate intelligent training recommendations using squad-relative quality assessment.

        Returns:
            List of dictionaries with training recommendations
        """
        depth_analysis = self.analyze_squad_depth_quality()
        gaps = self.identify_quality_gaps(depth_analysis)

        recommendations = []

        for pos_name, gap_info in gaps.items():
            skill_col, ability_col = self.position_mapping[pos_name]

            # Calculate percentiles for this position
            percentiles = self.calculate_position_percentiles(ability_col) if ability_col else None

            # Analyze three categories of candidates
            candidates = {
                'improve_natural': [],      # Already natural, train to improve ability
                'become_natural': [],       # Good ability, not yet natural
                'learn_position': []        # Potential, needs to learn position
            }

            for idx, row in self.df.iterrows():
                name = row['Name']
                age = row.get('Age', 99)
                skill_rating = row.get(skill_col, 0)
                ability_rating = row.get(ability_col, np.nan) if (ability_col and ability_col in self.df.columns) else np.nan

                skill_tier = self.get_positional_familiarity_tier(skill_rating)
                ability_tier = self.get_quality_tier(ability_rating, percentiles) if percentiles else 'Unknown'

                # Get training attributes
                versatility = row.get('Versatility', 10)
                professionalism = row.get('Professionalism', 10)
                determination = row.get('Determination', 10)
                ca = row.get('CA', 0)
                pa = row.get('PA', 0)

                # Calculate training potential
                age_factor = max(0, (28 - age) / 24) if pd.notna(age) else 0.5  # Younger is better
                versatility_factor = versatility / 20 if pd.notna(versatility) else 0.5
                professionalism_factor = professionalism / 20 if pd.notna(professionalism) else 0.5
                growth_potential = (pa - ca) if pd.notna(pa) and pd.notna(ca) else 10

                training_score = (
                    age_factor * 0.3 +
                    versatility_factor * 0.3 +
                    professionalism_factor * 0.3 +
                    min(growth_potential / 30, 1.0) * 0.1
                )

                # Categorize the candidate using squad-relative quality tiers
                if skill_rating >= 18:  # Already Natural
                    if pd.notna(ability_rating):
                        if ability_tier not in ['Good', 'Excellent']:
                            # Natural but not top 25% quality - train to improve
                            candidates['improve_natural'].append({
                                'name': name,
                                'age': age,
                                'skill_rating': skill_rating,
                                'skill_tier': skill_tier,
                                'ability_rating': ability_rating,
                                'ability_tier': ability_tier,
                                'training_score': training_score,
                                'reason': 'Already natural, train to improve ability'
                            })

                elif skill_rating >= 10:  # Competent/Accomplished but not Natural
                    if pd.notna(ability_rating) and ability_tier in ['Adequate', 'Good', 'Excellent']:
                        # Above median ability, should become natural
                        candidates['become_natural'].append({
                            'name': name,
                            'age': age,
                            'skill_rating': skill_rating,
                            'skill_tier': skill_tier,
                            'ability_rating': ability_rating,
                            'ability_tier': ability_tier,
                            'training_score': training_score,
                            'reason': 'Good ability, train to become natural'
                        })

                else:  # Below Competent
                    if pd.notna(ability_rating) and ability_tier in ['Adequate', 'Good', 'Excellent']:
                        # Has potential but needs to learn position
                        # Check if player is natural in similar position
                        has_similar = self._check_similar_positions(row, pos_name)

                        if age < 24 or has_similar or training_score > 0.6:
                            candidates['learn_position'].append({
                                'name': name,
                                'age': age,
                                'skill_rating': skill_rating,
                                'skill_tier': skill_tier,
                                'ability_rating': ability_rating,
                                'ability_tier': ability_tier,
                                'training_score': training_score,
                                'has_similar': has_similar,
                                'reason': 'Has potential, train new position'
                            })

            # Sort each category by training score
            for category in candidates.values():
                category.sort(key=lambda x: x['training_score'], reverse=True)

            # Generate recommendations prioritized by category
            priority_order = ['become_natural', 'improve_natural', 'learn_position']

            for category_name in priority_order:
                category = candidates[category_name]

                # Determine how many from this category we need
                if category_name == 'become_natural':
                    # These address quality gap most directly
                    needed = gap_info['quality_shortage']
                    priority = 'High'
                elif category_name == 'improve_natural':
                    # These improve existing players
                    needed = min(2, gap_info['quality_shortage'])
                    priority = 'Medium'
                else:  # learn_position
                    # These are longer-term investments
                    needed = min(1, gap_info['total_shortage'])
                    priority = 'Low'

                for candidate in category[:needed + 1]:  # +1 for alternatives
                    rec = {
                        'player': candidate['name'],
                        'position': pos_name,
                        'category': category_name.replace('_', ' ').title(),
                        'current_skill': candidate['skill_tier'],
                        'current_skill_rating': candidate['skill_rating'],
                        'ability_tier': candidate['ability_tier'],
                        'ability_rating': candidate.get('ability_rating', np.nan),
                        'age': candidate['age'],
                        'training_score': candidate['training_score'],
                        'priority': priority,
                        'reason': self._generate_detailed_reason(candidate, pos_name)
                    }
                    recommendations.append(rec)

        return recommendations

    def _check_similar_positions(self, row: pd.Series, target_pos: str) -> bool:
        """Check if player is natural in similar positions."""
        similarity_groups = {
            'D(R)': ['Defender Right', 'Defender Left'],
            'D(L)': ['Defender Left', 'Defender Right'],
            'D(C)': ['Defender Center'],
            'DM': ['Defensive Midfielder', 'Defender Center'],
            'AM(R)': ['Attacking Mid. Right', 'Attacking Mid. Left', 'Attacking Mid. Center'],
            'AM(L)': ['Attacking Mid. Left', 'Attacking Mid. Right', 'Attacking Mid. Center'],
            'AM(C)': ['Attacking Mid. Center', 'Attacking Mid. Left', 'Attacking Mid. Right'],
            'ST': ['Striker', 'Attacking Mid. Center'],
            'GK': []
        }

        similar_cols = similarity_groups.get(target_pos, [])

        for col in similar_cols:
            if col in row and pd.notna(row[col]) and row[col] >= 18:
                return True

        return False

    def _generate_detailed_reason(self, candidate: Dict, position: str) -> str:
        """Generate comprehensive reason for recommendation."""
        reasons = []

        # Category-specific reason
        if candidate['reason']:
            reasons.append(candidate['reason'])

        # Age
        age = candidate['age']
        if age < 21:
            reasons.append(f"very young ({age})")
        elif age < 24:
            reasons.append(f"young ({age})")

        # Training characteristics
        if candidate['training_score'] >= 0.7:
            reasons.append("excellent training attributes")
        elif candidate['training_score'] >= 0.5:
            reasons.append("good training attributes")

        # Ability level
        ability_tier = candidate.get('ability_tier', 'Unknown')
        if ability_tier in ['Excellent', 'Good']:
            reasons.append(f"{ability_tier.lower()} ability at position")

        # Similar position
        if candidate.get('has_similar'):
            reasons.append("natural in similar position")

        return " | ".join(reasons)

    def print_depth_analysis(self):
        """Print comprehensive depth analysis with quality assessment."""
        depth_analysis = self.analyze_squad_depth_quality()
        gaps = self.identify_quality_gaps(depth_analysis)

        print("=" * 110)
        print("SQUAD DEPTH & QUALITY ANALYSIS FOR 4-2-3-1 FORMATION")
        print("=" * 110)
        print()

        has_abilities = any(pd.notna(players[0][2]) for players in depth_analysis.values() if players)

        for pos_name in ['GK', 'D(L)', 'D(C)', 'D(R)', 'DM', 'AM(L)', 'AM(C)', 'AM(R)', 'ST']:
            players_data = depth_analysis.get(pos_name, [])
            needed = self.formation_needs.get(pos_name, 1)

            print(f"{pos_name:8} (Need {needed} in XI, want 2+ competent & 1+ good quality):")

            if not players_data:
                print(f"  {'NO PLAYERS AVAILABLE':50} - CRITICAL GAP!")
            else:
                for i, (name, skill_rating, ability_rating, skill_tier, ability_tier) in enumerate(players_data[:6], 1):
                    # Status indicator
                    status = "✓" if skill_rating >= 10 else "⚠"

                    # Quality indicator based on ability tier
                    if ability_tier == 'Excellent':
                        quality_icon = "⭐"
                    elif ability_tier == 'Good':
                        quality_icon = "✓✓"
                    elif ability_tier == 'Adequate':
                        quality_icon = "→"
                    elif ability_tier in ['Poor', 'Inadequate']:
                        quality_icon = "⚠"
                    else:
                        quality_icon = "?"

                    # Format output
                    if has_abilities and pd.notna(ability_rating):
                        print(f"  {status} {quality_icon} {name:28} {skill_tier:15} ({skill_rating:4.1f}/20) | "
                              f"{ability_tier:10} ability ({ability_rating:5.1f}/200)")
                    else:
                        print(f"  {status} {name:30} {skill_tier:15} ({skill_rating:4.1f}/20)")

            # Show gaps
            if pos_name in gaps:
                gap_info = gaps[pos_name]
                if gap_info['total_shortage'] > 0:
                    print(f"  >>> DEPTH GAP: Need {gap_info['total_shortage']} more competent player(s)")
                if gap_info['quality_shortage'] > 0:
                    print(f"  >>> QUALITY GAP: Need {gap_info['quality_shortage']} more good-quality player(s)")

            print()

        if has_abilities:
            print("\nQUALITY INDICATORS:")
            print("  ⭐ = Excellent ability (17+)")
            print("  ✓✓ = Good ability (15+)")
            print("  → = Adequate ability (13+)")
            print("  ⚠ = Below standard")

        print("=" * 110)

    def print_training_recommendations(self):
        """Print formatted training recommendations."""
        recommendations = self.recommend_training()

        if not recommendations:
            print("\n" + "=" * 110)
            print("TRAINING RECOMMENDATIONS")
            print("=" * 110)

            if not self.has_abilities:
                print("\n⚠️  Cannot provide training recommendations without role ability data.")
                print("\nTo get intelligent training recommendations:")
                print("  1. Export player role ability ratings from FM26 (Squad view with Striker, AM(L), etc. columns)")
                print("  2. Save as players.csv")
                print("  3. Run: python fm_training_advisor.py players-current.csv players.csv")
                print("\nRole ability ratings show how GOOD each player is at each position based on their attributes.")
                print("This is different from positional skill ratings (1-20 familiarity scale) already in players-current.csv.")
            else:
                print("\n✅ No training recommendations needed - squad depth and quality are adequate at all positions!")

            print("=" * 110)
            return

        print("\n" + "=" * 110)
        print("INTELLIGENT TRAINING RECOMMENDATIONS")
        print("=" * 110)
        print("\nRecommendations based on positional skill ratings, role abilities, and training attributes:")
        print()

        # Group by priority
        high_priority = [r for r in recommendations if r['priority'] == 'High']
        medium_priority = [r for r in recommendations if r['priority'] == 'Medium']
        low_priority = [r for r in recommendations if r['priority'] == 'Low']

        has_abilities = any(pd.notna(r['ability_rating']) for r in recommendations)

        def print_recommendations(recs, title):
            if not recs:
                return

            print(f"{title}:")
            print("-" * 110)

            for rec in recs:
                print(f"  Player: {rec['player']:28} → Train as: {rec['position']:8} [{rec['category']}]")

                if has_abilities and pd.notna(rec['ability_rating']):
                    print(f"         Familiarity: {rec['current_skill']:15} ({rec['current_skill_rating']:4.1f}/20) | "
                          f"Ability: {rec['ability_tier']:10} ({rec['ability_rating']:5.1f}/200)")
                else:
                    print(f"         Familiarity: {rec['current_skill']:15} ({rec['current_skill_rating']:4.1f}/20)")

                print(f"         Age: {rec['age']:2} | Training Score: {rec['training_score']:.2f} | {rec['reason']}")
                print()

        print_recommendations(high_priority, "HIGH PRIORITY (Address quality gaps)")
        print_recommendations(medium_priority, "MEDIUM PRIORITY (Improve existing players)")
        print_recommendations(low_priority, "LOW PRIORITY (Long-term investments)")

        print("=" * 110)
        print("\nTRAINING CATEGORIES EXPLAINED:")
        print("  • Become Natural: Players with good ability who should train to reach Natural (18+) familiarity")
        print("  • Improve Natural: Players already Natural but need to improve their ability through training")
        print("  • Learn Position: Players with potential who should train into a new position")
        print()
        print("TRAINING TIMELINE EXPECTATIONS:")
        print("  • Competent level (10/20):  6-9 months of training + match experience")
        print("  • Accomplished level (13+): 12 months of training + regular playing time")
        print("  • Natural level (18+):      12-24 months (requires consistent matches)")
        print()
        print("KEY FACTORS FOR FASTER TRAINING:")
        print("  • Age under 24 (younger players learn faster)")
        print("  • High Versatility attribute (accelerates position learning)")
        print("  • High Professionalism (trains harder and more effectively)")
        print("  • Natural in similar positions (easier to adapt)")
        print("  • Both individual training AND match experience needed")
        print("=" * 110)


def main():
    """Main execution function."""
    import os

    # Get file paths
    status_file = None
    abilities_file = None

    if len(sys.argv) > 1:
        status_file = sys.argv[1]
        if len(sys.argv) > 2:
            abilities_file = sys.argv[2]
    else:
        # Try common filenames
        if os.path.exists('players-current.csv'):
            status_file = 'players-current.csv'
        elif os.path.exists('players.csv'):
            status_file = 'players.csv'

        # Look for abilities file
        if os.path.exists('players.csv') and status_file == 'players-current.csv':
            abilities_file = 'players.csv'
        elif os.path.exists('players-abilities.csv'):
            abilities_file = 'players-abilities.csv'

    if not status_file:
        print("Error: No player data file found!")
        print("\nUsage:")
        print("  python fm_training_advisor.py <status_file.csv> [abilities_file.csv]")
        print("\nFiles needed:")
        print("  1. Status file (players-current.csv): Positional skill ratings, attributes, condition, etc.")
        print("  2. Abilities file (players.csv): Role ability ratings [OPTIONAL but RECOMMENDED]")
        print("\nFor best results, provide both files!")
        sys.exit(1)

    print(f"\nLoading player status/attributes from: {status_file}")
    if abilities_file:
        print(f"Loading role abilities from: {abilities_file}")
    else:
        print("No role abilities file provided - analysis will be limited")

    try:
        advisor = TrainingAdvisor(status_file, abilities_file)
        advisor.print_depth_analysis()
        advisor.print_training_recommendations()

    except FileNotFoundError as e:
        print(f"\nError: {str(e)}")
        sys.exit(1)
    except Exception as e:
        print(f"\nError: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
