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
    """
    FM26 Strategic Training Advisor for 4-2-3-1 Formation.

    Implements the "25+3" Squad Architecture Model based on lineup-depth-strategy.md research:
    - Tier 1 (14-15 players): Elite starters, 70%+ playing time
    - Tier 2 (7-8 players): Rotation squad, 30-40% playing time
    - Tier 3 (3 players): Universalists covering 3+ positions, emergency backup

    Key FM26 Unity Engine Considerations:
    - High-attrition zones: Wing-backs (5 total), DMs (5 total) need extra depth
    - Strategic retraining pathways: Winger→WB (most efficient), Aging AMC→DM
    - Universalist doctrine: 4th CB must cover DM/FB roles
    - Condition Floor: Injury risk exponential below 90% condition
    - Tactical variety: Strikers need pace + target man profiles

    Provides depth analysis, quality assessment, injury risk evaluation, and
    intelligent training recommendations aligned with FM26 tactical demands.
    """

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
            # Core attributes
            'Age', 'CA', 'PA',
            # Training attributes
            'Versatility', 'Professionalism', 'Determination', 'Adaptability',
            # Physical/Fitness attributes (FM26 Unity engine fatigue model)
            'Natural Fitness', 'Stamina', 'Work Rate',
            'Condition (%)', 'Injury Proneness',
            # Technical attributes for strategic retraining analysis
            'Pace', 'Acceleration', 'Strength', 'Jumping Reach', 'Heading',
            'Technique', 'Dribbling', 'Flair', 'Vision', 'Passing', 'Decisions',
            'Off the Ball', 'Finishing',
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

        # FM26 4-2-3-1 Depth Targets based on "25+3" Squad Architecture Model
        # See: lineup-depth-strategy.md for strategic rationale
        # Tier 1: Elite starters (70%+ starts), Tier 2: Rotation (30-40%), Tier 3: Universalists (<10%)
        # High-attrition zones (WB, DM) need significantly more depth due to Unity engine fatigue
        self.formation_depth_targets = {
            'GK': {
                'tier1': 1,      # Starting GK
                'tier2': 1,      # Backup GK
                'tier3_hg': 1,   # 3rd choice (Home-Grown for registration)
                'total_target': 3,
                'high_attrition': False,
                'notes': 'GK suffers minimal fatigue - 90% budget on No.1'
            },
            'D(R)': {
                'tier1': 1,      # Starting RB/RWB
                'tier2': 2,      # Rotation options
                'universalist_share': 0.5,  # Share of utility player
                'total_target': 4,   # ~3.5 rounded up
                'high_attrition': True,  # Wing-backs are highest attrition zone
                'notes': 'Pressing WB role extremely demanding - need depth + tactical variety'
            },
            'D(C)': {
                'tier1': 2,      # Starting CB partnership
                'tier2': 2,      # Rotation CBs
                'universalist': 1,  # 4th/5th CB must cover DM/FB
                'total_target': 5,
                'high_attrition': False,
                'notes': '4th CB MUST be universalist covering DM/FB - "CB only" is wasted bench slot'
            },
            'D(L)': {
                'tier1': 1,      # Starting LB/LWB
                'tier2': 2,      # Rotation options
                'universalist_share': 0.5,  # Share of utility player
                'total_target': 4,   # ~3.5 rounded up
                'high_attrition': True,  # Wing-backs are highest attrition zone
                'notes': 'Pressing WB role extremely demanding - need depth + tactical variety'
            },
            'DM': {
                'tier1': 2,      # Starting pivot partnership
                'tier2': 2,      # Rotation DMs
                'youth': 1,      # High-potential youth
                'total_target': 5,
                'high_attrition': True,  # High-collision zone with frequent injuries
                'notes': 'Pressing DM reaches critical fatigue by 65min - Condition Floor must be respected'
            },
            'AM(R)': {
                'tier1': 1,      # Starting right winger
                'tier2': 1,      # Rotation/backup
                'total_target': 2,
                'high_attrition': False,
                'notes': 'Must pair tactically with right full-back (Playmaking WB needs Inside Forward)'
            },
            'AM(C)': {
                'tier1': 1,      # Starting CAM
                'tier2': 1,      # Rotation (consider Tracking AM for defensive subs)
                'total_target': 2,
                'high_attrition': False,
                'notes': 'Backup should be Tracking AM profile for defensive solidity'
            },
            'AM(L)': {
                'tier1': 1,      # Starting left winger
                'tier2': 1,      # Rotation/backup
                'total_target': 2,
                'high_attrition': False,
                'notes': 'Must pair tactically with left full-back (Playmaking WB needs Inside Forward)'
            },
            'ST': {
                'tier1': 1,      # Starting striker
                'tier2': 1,      # Rotation striker (MUST be different profile)
                'youth': 1,      # Development striker
                'total_target': 3,
                'high_attrition': False,
                'tactical_variety_required': True,
                'notes': 'CRITICAL: Need tactical variety - pace striker + target man for different approaches'
            }
        }

        # Legacy simple count (for backward compatibility in some methods)
        self.formation_needs = {pos: data['total_target'] for pos, data in self.formation_depth_targets.items()}

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

                skill_tier = self.get_positional_familiarity_tier(skill_rating)
                ability_tier = self.get_quality_tier(ability_rating, percentiles) if percentiles else 'Unknown'

                # Only include players who are:
                # 1. At least Awkward (8/20) - minimally playable
                # 2. OR have Good/Excellent ability (training candidates worth showing)
                is_somewhat_familiar = pd.notna(skill_rating) and skill_rating >= 8
                is_training_candidate = ability_tier in ['Good', 'Excellent']

                if is_somewhat_familiar or is_training_candidate:
                    players_data.append((
                        row['Name'],
                        skill_rating,
                        ability_rating,
                        skill_tier,
                        ability_tier
                    ))

            # Sort with familiarity weighted heavily - players who can actually play the position rank higher
            def sort_key(x):
                skill = x[1] if pd.notna(x[1]) else 0
                ability = x[2] if pd.notna(x[2]) else 0

                # Create composite score that values familiarity heavily
                if skill >= 18:  # Natural - ready to play, high familiarity bonus
                    composite = ability + 60
                elif skill >= 13:  # Accomplished - ready to play, good bonus
                    composite = ability + 35
                elif skill >= 10:  # Competent - playable, moderate bonus
                    composite = ability + 15
                elif skill >= 8:  # Awkward - emergency option, small bonus
                    composite = ability + 5
                else:  # Below Awkward - training candidates only, heavily penalized
                    composite = ability * 0.4

                return (-composite, -skill, -ability)

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

    def analyze_injury_risk(self, player: pd.Series) -> Dict:
        """
        Analyze player's injury risk based on FM26 Unity engine factors.

        Based on lineup-depth-strategy.md:
        - "Condition Floor" has risen in FM26 - 85% condition now risky
        - Exponential injury probability at low condition
        - Natural Fitness and Injury Proneness are critical indicators

        Args:
            player: Player row with condition/fitness data

        Returns:
            Dict with injury_risk_score, urgency_multiplier, and warnings
        """
        condition = player.get('Condition (%)', 100)
        natural_fitness = player.get('Natural Fitness', 15)
        injury_proneness = player.get('Injury Proneness', 10)

        warnings = []
        risk_score = 0.0

        # Condition below 90% is risky in FM26 Unity engine
        if pd.notna(condition):
            if condition < 85:
                risk_score += 0.4
                warnings.append(f"Low condition ({condition}%) - high injury risk")
            elif condition < 90:
                risk_score += 0.2
                warnings.append(f"Condition ({condition}%) below ideal")

        # Natural Fitness < 12 means slower recovery and higher injury risk
        if pd.notna(natural_fitness):
            if natural_fitness < 10:
                risk_score += 0.3
                warnings.append(f"Very low Natural Fitness ({natural_fitness}) - injury prone")
            elif natural_fitness < 12:
                risk_score += 0.15
                warnings.append(f"Low Natural Fitness ({natural_fitness})")

        # Injury Proneness > 15 is a red flag
        if pd.notna(injury_proneness):
            if injury_proneness > 17:
                risk_score += 0.3
                warnings.append(f"Very injury prone ({injury_proneness})")
            elif injury_proneness > 15:
                risk_score += 0.15
                warnings.append(f"Injury prone ({injury_proneness})")

        # Calculate urgency multiplier (increases backup priority)
        if risk_score >= 0.5:
            urgency_multiplier = 2.0  # Double the gap severity for this position
        elif risk_score >= 0.3:
            urgency_multiplier = 1.5
        elif risk_score >= 0.15:
            urgency_multiplier = 1.2
        else:
            urgency_multiplier = 1.0

        return {
            'risk_score': risk_score,
            'urgency_multiplier': urgency_multiplier,
            'warnings': warnings,
            'high_risk': risk_score >= 0.3
        }

    def assess_positional_variety(self, position: str) -> Dict:
        """
        Assess whether squad has tactical variety at a given position.

        Based on lineup-depth-strategy.md:
        - Strikers need BOTH pace striker AND target man for different approaches
        - "When 4-2-3-1 struggles against low block, swap runner for physical presence"
        - DM pivot should have BOTH destroyer AND progressor

        Args:
            position: Position to assess

        Returns:
            Dict with variety analysis and recommendations
        """
        if position == 'ST':
            # Analyze striker profiles
            pace_strikers = []
            target_men = []
            technical_strikers = []

            for idx, row in self.df.iterrows():
                st_skill = row.get('Striker', 0)
                if pd.notna(st_skill) and st_skill >= 10:  # At least Competent
                    name = row['Name']
                    pace = row.get('Pace', 10)
                    acceleration = row.get('Acceleration', 10)
                    strength = row.get('Strength', 10)
                    jumping = row.get('Jumping Reach', 10)
                    heading = row.get('Heading', 10)
                    technique = row.get('Technique', 10)
                    dribbling = row.get('Dribbling', 10)

                    # Pace striker: High pace/acceleration
                    if pd.notna(pace) and pd.notna(acceleration) and pace >= 14 and acceleration >= 14:
                        pace_strikers.append(name)

                    # Target man: High strength/jumping/heading
                    if pd.notna(strength) and pd.notna(jumping) and pd.notna(heading):
                        if strength >= 14 and jumping >= 13 and heading >= 13:
                            target_men.append(name)

                    # Technical striker: High technique/dribbling
                    if pd.notna(technique) and pd.notna(dribbling):
                        if technique >= 14 and dribbling >= 13:
                            technical_strikers.append(name)

            variety_score = len(set(pace_strikers)) + len(set(target_men)) + len(set(technical_strikers))
            has_variety = len(pace_strikers) >= 1 and len(target_men) >= 1

            return {
                'has_variety': has_variety,
                'variety_score': variety_score,
                'pace_strikers': pace_strikers,
                'target_men': target_men,
                'technical_strikers': technical_strikers,
                'needs': [] if has_variety else (['target man'] if pace_strikers else ['pace striker'])
            }

        elif position == 'DM':
            # Analyze DM profiles
            destroyers = []
            progressors = []

            for idx, row in self.df.iterrows():
                dm_skill = row.get('Defensive Midfielder', 0)
                if pd.notna(dm_skill) and dm_skill >= 10:  # At least Competent
                    name = row['Name']
                    tackling = row.get('Tackling', 10)
                    aggression = row.get('Aggression', 10)
                    vision = row.get('Vision', 10)
                    passing = row.get('Passing', 10)

                    # Destroyer: High tackling/aggression
                    if pd.notna(tackling) and pd.notna(aggression) and tackling >= 13 and aggression >= 13:
                        destroyers.append(name)

                    # Progressor: High vision/passing
                    if pd.notna(vision) and pd.notna(passing) and vision >= 13 and passing >= 13:
                        progressors.append(name)

            has_variety = len(destroyers) >= 1 and len(progressors) >= 1

            return {
                'has_variety': has_variety,
                'variety_score': len(set(destroyers)) + len(set(progressors)),
                'destroyers': destroyers,
                'progressors': progressors,
                'needs': [] if has_variety else (['destroyer'] if progressors else ['progressor'])
            }

        return {'has_variety': True, 'variety_score': 1, 'needs': []}

    def identify_universalist_candidates(self) -> List[Dict]:
        """
        Identify players who can/should be trained as utility players covering 3+ positions.

        Based on lineup-depth-strategy.md "Universalist Doctrine":
        - "A CB who can only play CB is a wasted bench slot"
        - 4th CB MUST cover DM/FB roles
        - Tier 3 players valued by FLEXIBILITY not raw output
        - Target: Cover 3+ positions at Competent level or higher

        Returns:
            List of universalist candidates with their coverage analysis
        """
        candidates = []

        for idx, row in self.df.iterrows():
            name = row['Name']
            age = row.get('Age', 99)
            versatility = row.get('Versatility', 10)

            # Count positions where player is at least Competent (10+)
            competent_positions = []
            accomplished_positions = []

            for pos_name, (skill_col, ability_col) in self.position_mapping.items():
                skill_rating = row.get(skill_col, 0)

                if pd.notna(skill_rating) and skill_rating >= 13:  # Accomplished or better
                    accomplished_positions.append(pos_name)
                elif pd.notna(skill_rating) and skill_rating >= 10:  # Competent
                    competent_positions.append(pos_name)

            total_coverage = len(accomplished_positions) + len(competent_positions)

            # Universalist candidates: either already cover 3+ OR high versatility for training
            is_current_universalist = total_coverage >= 3
            is_potential_universalist = (versatility >= 13 and total_coverage >= 2)

            # Special check: CB who can also play DM/FB (critical need)
            cb_skill = row.get('Defender Center', 0)
            dm_skill = row.get('Defensive Midfielder', 0)
            fb_right_skill = row.get('Defender Right', 0)
            fb_left_skill = row.get('Defender Left', 0)

            is_cb_universalist = (
                pd.notna(cb_skill) and cb_skill >= 13 and
                ((pd.notna(dm_skill) and dm_skill >= 10) or
                 (pd.notna(fb_right_skill) and fb_right_skill >= 10) or
                 (pd.notna(fb_left_skill) and fb_left_skill >= 10))
            )

            if is_current_universalist or is_potential_universalist or is_cb_universalist:
                candidates.append({
                    'name': name,
                    'age': age,
                    'versatility': versatility,
                    'accomplished_positions': accomplished_positions,
                    'competent_positions': competent_positions,
                    'total_coverage': total_coverage,
                    'is_cb_universalist': is_cb_universalist,
                    'universalist_score': total_coverage + (versatility / 20),
                    'tier3_candidate': total_coverage >= 3 or (versatility >= 15 and total_coverage >= 2)
                })

        # Sort by universalist score
        candidates.sort(key=lambda x: x['universalist_score'], reverse=True)

        return candidates

    def calculate_age_factor_strategic(self, age: float, target_pos: str, row: pd.Series) -> Tuple[float, str]:
        """
        Calculate age factor using step function with special handling for strategic aging conversions.

        Based on lineup-depth-strategy.md research:
        - Under 24: Peak developmental years for position retraining
        - 24-27: Still viable for retraining
        - 28+: Generally avoid EXCEPT strategic aging conversions (AMC → DM)

        Args:
            age: Player age
            target_pos: Position being trained for
            row: Full player data for attribute analysis

        Returns:
            Tuple of (age_factor_score, explanation_string)
        """
        if pd.isna(age):
            return (0.5, "unknown age")

        # SPECIAL CASE: Aging Playmaker → Deep DM Conversion (strategy doc line 108-112)
        # "31-year-old No. 10 who can no longer press in advanced strata... train as Deep Lying Playmaker"
        if age >= 28 and target_pos == 'DM':
            # Check if player is a playmaker (natural in AMC positions)
            amc_skill = row.get('Attacking Mid. Center', 0)
            aml_skill = row.get('Attacking Mid. Left', 0)
            amr_skill = row.get('Attacking Mid. Right', 0)

            is_playmaker = (amc_skill >= 15 or aml_skill >= 15 or amr_skill >= 15)

            if is_playmaker:
                # Check for elite mental/technical attributes
                vision = row.get('Vision', 10)
                passing = row.get('Passing', 10)
                decisions = row.get('Decisions', 10)

                # Check for pace decline (key indicator)
                pace = row.get('Pace', 10)
                acceleration = row.get('Acceleration', 10)

                has_elite_mentals = (vision >= 15 and passing >= 15 and decisions >= 14)
                has_pace_decline = (pace <= 12 or acceleration <= 12)

                if has_elite_mentals and has_pace_decline:
                    # Perfect candidate for aging playmaker conversion!
                    return (0.75, f"STRATEGIC: Aging playmaker ({age}) with elite mentals, declining pace - ideal DM conversion")
                elif has_elite_mentals:
                    return (0.60, f"aging playmaker ({age}) with elite mentals - good DM candidate")

        # STRATEGIC CASE: Young winger → Wing-Back conversion (strategy doc line 173-178)
        # "Young winger with acceptable Work Rate (12+)" is IDEAL candidate
        if age < 26 and target_pos in ['D(R)', 'D(L)']:
            amr_skill = row.get('Attacking Mid. Right', 0)
            aml_skill = row.get('Attacking Mid. Left', 0)

            is_winger = (amr_skill >= 13 or aml_skill >= 13)
            work_rate = row.get('Work Rate', 10)

            if is_winger and work_rate >= 12:
                return (0.95, f"STRATEGIC: Young winger ({age}) with good work rate - ideal WB conversion (most efficient pathway)")
            elif is_winger:
                return (0.75, f"young winger ({age}) - good WB conversion candidate (needs work rate development)")

        # General age-based retraining factor (step function, not linear)
        if age < 21:
            return (1.0, f"very young ({age}) - peak developmental years")
        elif age < 24:
            return (0.95, f"young ({age}) - peak developmental years")
        elif age < 26:
            return (0.70, f"young ({age}) - still good for retraining")
        elif age < 28:
            return (0.40, f"age {age} - retraining viable but slower")
        elif age < 30:
            return (0.15, f"age {age} - only for strategic conversions")
        else:
            return (0.05, f"age {age} - avoid unless exceptional strategic case")

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

                # Calculate training potential using strategic model
                # Age factor with strategic conversion logic (winger→WB, aging AMC→DM)
                age_factor, age_reason = self.calculate_age_factor_strategic(age, pos_name, row)

                # Versatility is PRIMARY factor (research shows it's most critical for retraining speed)
                # Increased from 30% to 45% based on lineup-depth-strategy.md findings
                versatility_factor = versatility / 20 if pd.notna(versatility) else 0.5

                # Apply heavy penalty for low versatility (may take 18+ months or never adapt)
                if pd.notna(versatility) and versatility < 10:
                    versatility_factor *= 0.3  # Heavy penalty

                professionalism_factor = professionalism / 20 if pd.notna(professionalism) else 0.5
                growth_potential = (pa - ca) if pd.notna(pa) and pd.notna(ca) else 10

                # Updated weighting: Versatility 45%, Age 25%, Professionalism 20%, Growth 10%
                training_score = (
                    versatility_factor * 0.45 +      # PRIMARY factor (up from 0.3)
                    age_factor * 0.25 +               # Important but secondary
                    professionalism_factor * 0.20 +   # Helps training effectiveness
                    min(growth_potential / 30, 1.0) * 0.10  # Nice to have
                )

                # Categorize the candidate using squad-relative quality tiers
                if skill_rating >= 18:  # Already Natural
                    if pd.notna(ability_rating):
                        if ability_tier not in ['Good', 'Excellent']:
                            # Natural but not top 25% quality - train to improve
                            candidates['improve_natural'].append({
                                'name': name,
                                'row': row,
                                'age': age,
                                'skill_rating': skill_rating,
                                'skill_tier': skill_tier,
                                'ability_rating': ability_rating,
                                'ability_tier': ability_tier,
                                'training_score': training_score,
                                'age_reason': age_reason,
                                'reason': 'Already natural, train to improve ability'
                            })

                elif skill_rating >= 10:  # Competent/Accomplished but not Natural
                    if pd.notna(ability_rating) and ability_tier in ['Adequate', 'Good', 'Excellent']:
                        # Above median ability, should become natural
                        # But check if retraining makes sense given opportunity cost
                        if self._should_retrain(row, pos_name, skill_rating, gaps):
                            candidates['become_natural'].append({
                                'name': name,
                                'row': row,
                                'age': age,
                                'skill_rating': skill_rating,
                                'skill_tier': skill_tier,
                                'ability_rating': ability_rating,
                                'ability_tier': ability_tier,
                                'training_score': training_score,
                                'age_reason': age_reason,
                                'reason': 'Good ability, train to become natural'
                            })

                else:  # Below Competent
                    # Only recommend learning new positions for Good/Excellent candidates
                    if pd.notna(ability_rating) and ability_tier in ['Good', 'Excellent']:
                        # Special handling for GK - don't recommend unless already somewhat familiar or Excellent
                        if pos_name == 'GK' and skill_rating < 8 and ability_tier != 'Excellent':
                            continue  # Skip GK recommendations for unfamiliar outfield players

                        # Has potential but needs to learn position
                        # Check if player is natural in similar position
                        has_similar = self._check_similar_positions(row, pos_name)

                        if age < 24 or has_similar or training_score > 0.6:
                            # Check if retraining makes sense given opportunity cost
                            if self._should_retrain(row, pos_name, skill_rating, gaps):
                                candidates['learn_position'].append({
                                    'name': name,
                                    'row': row,
                                    'age': age,
                                    'skill_rating': skill_rating,
                                    'skill_tier': skill_tier,
                                    'ability_rating': ability_rating,
                                    'ability_tier': ability_tier,
                                    'training_score': training_score,
                                    'age_reason': age_reason,
                                    'has_similar': has_similar,
                                    'reason': 'Has potential, train new position'
                                })

            # Sort each category by training score
            for category in candidates.values():
                category.sort(key=lambda x: x['training_score'], reverse=True)

            # Calculate gap severity for this position
            gap_severity = (
                gap_info.get('quality_shortage', 0) * 3 +
                gap_info.get('total_shortage', 0) * 2
            )

            # Generate recommendations prioritized by category
            priority_order = ['become_natural', 'improve_natural', 'learn_position']

            for category_name in priority_order:
                category = candidates[category_name]

                # Determine how many from this category we need
                if category_name == 'become_natural':
                    # These address quality gap most directly
                    needed = gap_info['quality_shortage']
                    priority = 'High'
                    priority_score = 3
                elif category_name == 'improve_natural':
                    # These improve existing players
                    needed = min(2, gap_info['quality_shortage'])
                    priority = 'Medium'
                    priority_score = 2
                else:  # learn_position
                    # These are longer-term investments
                    needed = min(1, gap_info['total_shortage'])
                    priority = 'Low'
                    priority_score = 1

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
                        'priority_score': priority_score,
                        'gap_severity': gap_severity,
                        'reason': self._generate_detailed_reason(candidate, pos_name)
                    }
                    recommendations.append(rec)

        # CRITICAL: Deduplicate by player - each player can only train ONE position
        # Keep the best recommendation per player based on gap severity and priority
        player_best_rec = {}
        for rec in recommendations:
            player_name = rec['player']

            if player_name not in player_best_rec:
                player_best_rec[player_name] = rec
            else:
                # Compare: higher priority score wins, then higher gap severity, then higher training score
                current = player_best_rec[player_name]
                if (rec['priority_score'] > current['priority_score'] or
                    (rec['priority_score'] == current['priority_score'] and rec['gap_severity'] > current['gap_severity']) or
                    (rec['priority_score'] == current['priority_score'] and rec['gap_severity'] == current['gap_severity'] and rec['training_score'] > current['training_score'])):
                    player_best_rec[player_name] = rec

        # Return deduplicated recommendations
        return list(player_best_rec.values())

    def _get_player_current_positions(self, row: pd.Series) -> List[Tuple[str, float]]:
        """
        Get positions where player is already Natural or Accomplished (13+).
        Returns list of (position_name, skill_rating) tuples.
        """
        current_positions = []

        for pos_name, (skill_col, ability_col) in self.position_mapping.items():
            skill_rating = row.get(skill_col, 0)
            if pd.notna(skill_rating) and skill_rating >= 13:  # Accomplished or better
                current_positions.append((pos_name, skill_rating))

        return current_positions

    def _should_retrain(self, row: pd.Series, target_pos: str, target_skill: float, gaps: Dict) -> bool:
        """
        Determine if retraining a player makes sense given opportunity cost.

        Args:
            row: Player data
            target_pos: Position we're considering training them for
            target_skill: Current skill rating at target position
            gaps: Gap analysis for all positions

        Returns:
            True if retraining makes sense, False if player should stay at current position
        """
        # If already Natural at target position, always allow (just improving)
        if target_skill >= 18:
            return True

        # If already Accomplished at target, usually allow
        if target_skill >= 13:
            return True

        # For retraining (below Accomplished at target), check opportunity cost
        current_positions = self._get_player_current_positions(row)

        # If player isn't Natural/Accomplished anywhere, retraining is fine
        if not current_positions:
            return True

        # Calculate gap severity for target position
        target_gap = gaps.get(target_pos, {})
        target_severity = (
            target_gap.get('quality_shortage', 0) * 3 +  # Quality shortage is most important
            target_gap.get('total_shortage', 0) * 2      # Competent shortage is important too
        )

        # Calculate worst gap severity at player's current positions
        current_max_severity = 0
        player_is_critical = False

        for curr_pos, curr_skill in current_positions:
            curr_gap = gaps.get(curr_pos, {})
            curr_severity = (
                curr_gap.get('quality_shortage', 0) * 3 +
                curr_gap.get('total_shortage', 0) * 2
            )
            current_max_severity = max(current_max_severity, curr_severity)

            # Check if player is critical at current position
            # (one of the only competent players there)
            if curr_skill >= 18 and curr_gap.get('total_shortage', 0) >= 1:
                player_is_critical = True

        # Don't retrain if:
        # 1. Player is critical at current position
        # 2. Target position has equal or less severe gap than current position
        if player_is_critical:
            return False

        if target_severity <= current_max_severity:
            return False

        return True

    def _check_similar_positions(self, row: pd.Series, target_pos: str) -> bool:
        """
        Check if player is natural in similar positions, including STRATEGIC retraining pathways.

        Strategic pathways based on lineup-depth-strategy.md:
        - Winger → Wing-Back: "Most efficient retraining pathway in modern FM"
        - Aging AMC → DM: Extends utility of playmakers losing pace
        - Winger → Channel Forward (ST): Ideal for inside forwards lacking top speed
        - Full-Back → Wide CB: For 3-at-back hybrid formations
        """
        similarity_groups = {
            'D(R)': [
                'Defender Right', 'Defender Left',
                # STRATEGIC: Winger → Wing-Back pipeline (line 173-178 of strategy doc)
                'Attacking Mid. Right',  # Young wingers with Work Rate 12+ are IDEAL WB candidates
                'Defender Center'  # Wide CB role for hybrid systems
            ],
            'D(L)': [
                'Defender Left', 'Defender Right',
                # STRATEGIC: Winger → Wing-Back pipeline
                'Attacking Mid. Left',  # Young wingers with Work Rate 12+ are IDEAL WB candidates
                'Defender Center'  # Wide CB role for hybrid systems
            ],
            'D(C)': [
                'Defender Center',
                # STRATEGIC: Full-Back → Wide CB (line 94)
                'Defender Right', 'Defender Left',  # Robust full-backs can retrain to CB
                'Defensive Midfielder'  # DMs can drop to CB for universalist role
            ],
            'DM': [
                'Defensive Midfielder',
                'Defender Center',  # CBs can move up to DM
                # STRATEGIC: Aging Playmaker → Deep DM (line 108-112)
                'Attacking Mid. Center',  # 28+ AMCs with elite Vision/Passing, declining pace
                'Attacking Mid. Left', 'Attacking Mid. Right'  # Wide playmakers can also transition
            ],
            'AM(R)': [
                'Attacking Mid. Right', 'Attacking Mid. Left', 'Attacking Mid. Center',
                'Striker'  # Strikers can drop to winger role
            ],
            'AM(L)': [
                'Attacking Mid. Left', 'Attacking Mid. Right', 'Attacking Mid. Center',
                'Striker'  # Strikers can drop to winger role
            ],
            'AM(C)': [
                'Attacking Mid. Center', 'Attacking Mid. Left', 'Attacking Mid. Right',
                'Striker',  # Strikers can drop deep
                'Defensive Midfielder'  # Deep playmakers can push forward
            ],
            'ST': [
                'Striker',
                'Attacking Mid. Center',
                # STRATEGIC: Winger → Channel Forward (line 147-152)
                'Attacking Mid. Right', 'Attacking Mid. Left'  # Inside forwards lacking pace make ideal Channel Forwards
            ],
            'GK': []  # GK is specialist position, no strategic retraining pathways
        }

        similar_cols = similarity_groups.get(target_pos, [])

        for col in similar_cols:
            if col in row and pd.notna(row[col]) and row[col] >= 18:
                return True

        return False

    def _generate_detailed_reason(self, candidate: Dict, position: str) -> str:
        """Generate comprehensive reason with strategic context."""
        reasons = []

        # Check current positions for retraining context
        row = candidate.get('row')
        current_positions = []
        if row is not None:
            current_positions = self._get_player_current_positions(row)

        # Category-specific reason with context
        if candidate['reason']:
            base_reason = candidate['reason']
            # Add context about what position they're leaving if retraining
            if current_positions and candidate['skill_rating'] < 13:
                current_pos_names = [pos for pos, _ in current_positions]
                if current_pos_names:
                    base_reason += f" (currently Natural at {', '.join(current_pos_names)})"
            reasons.append(base_reason)

        # Strategic age reason (includes winger→WB, aging AMC→DM special cases)
        age_reason = candidate.get('age_reason', '')
        if age_reason:
            reasons.append(age_reason)

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

        # Low versatility warning
        if row is not None:
            versatility = row.get('Versatility', 10)
            if pd.notna(versatility) and versatility < 10:
                reasons.append("WARNING: Low versatility - may take 18+ months")

        return " | ".join(reasons)

    def print_depth_analysis(self):
        """Print comprehensive depth analysis with quality assessment, injury risk, and universalists."""
        depth_analysis = self.analyze_squad_depth_quality()
        gaps = self.identify_quality_gaps(depth_analysis)
        universalists = self.identify_universalist_candidates()

        print("=" * 120)
        print("SQUAD DEPTH & QUALITY ANALYSIS FOR 4-2-3-1 FORMATION (FM26 Unity Engine)")
        print("=" * 120)
        print()

        has_abilities = any(pd.notna(players[0][2]) for players in depth_analysis.values() if players)

        # Analyze each position
        for pos_name in ['GK', 'D(L)', 'D(C)', 'D(R)', 'DM', 'AM(L)', 'AM(C)', 'AM(R)', 'ST']:
            players_data = depth_analysis.get(pos_name, [])
            target_info = self.formation_depth_targets.get(pos_name, {})
            total_target = target_info.get('total_target', 1)
            is_high_attrition = target_info.get('high_attrition', False)

            # Header with strategic context
            attrition_flag = " [HIGH ATTRITION]" if is_high_attrition else ""
            print(f"{pos_name:8} (Target: {total_target} total){attrition_flag}:")
            if target_info.get('notes'):
                print(f"         Strategy: {target_info['notes']}")

            if not players_data:
                print(f"  {'NO PLAYERS AVAILABLE':50} - CRITICAL GAP!")
            else:
                for i, (name, skill_rating, ability_rating, skill_tier, ability_tier) in enumerate(players_data[:6], 1):
                    # Get player row for injury analysis
                    player_row = self.df[self.df['Name'] == name].iloc[0]
                    injury_analysis = self.analyze_injury_risk(player_row)

                    # Status indicator
                    status = "OK" if skill_rating >= 10 else "!!"

                    # Quality indicator based on ability tier
                    if ability_tier == 'Excellent':
                        quality_icon = "**"
                    elif ability_tier == 'Good':
                        quality_icon = "++"
                    elif ability_tier == 'Adequate':
                        quality_icon = "=="
                    elif ability_tier in ['Poor', 'Inadequate']:
                        quality_icon = "--"
                    else:
                        quality_icon = "??"

                    # Injury risk indicator
                    injury_icon = ""
                    if injury_analysis['high_risk']:
                        injury_icon = " [INJ]"
                        status = "!!"  # Override status if high injury risk

                    # Universalist indicator
                    is_universalist = any(u['name'] == name and u['total_coverage'] >= 3 for u in universalists)
                    universalist_icon = " [UTIL]" if is_universalist else ""

                    # Format output
                    if has_abilities and pd.notna(ability_rating):
                        print(f"  {status} {quality_icon} {name:28}{injury_icon}{universalist_icon} "
                              f"{skill_tier:15} ({skill_rating:4.1f}/20) | "
                              f"{ability_tier:10} ability ({ability_rating:5.1f}/200)")
                    else:
                        print(f"  {status} {name:30}{injury_icon}{universalist_icon} "
                              f"{skill_tier:15} ({skill_rating:4.1f}/20)")

                    # Show injury warnings
                    if injury_analysis['warnings']:
                        for warning in injury_analysis['warnings']:
                            print(f"       WARNING: {warning}")

            # Show gaps
            if pos_name in gaps:
                gap_info = gaps[pos_name]
                if gap_info['total_shortage'] > 0:
                    print(f"  >>> DEPTH GAP: Need {gap_info['total_shortage']} more competent player(s)")
                if gap_info['quality_shortage'] > 0:
                    print(f"  >>> QUALITY GAP: Need {gap_info['quality_shortage']} more good-quality player(s)")

            print()

        # Universalist summary
        if universalists:
            print("\n" + "=" * 120)
            print("UNIVERSALIST PLAYERS (Multi-Position Coverage):")
            print("=" * 120)
            for u in universalists[:5]:  # Show top 5
                accomplished = ', '.join(u['accomplished_positions'])
                competent = ', '.join(u['competent_positions'])
                tier3_marker = " [TIER 3 CANDIDATE]" if u['tier3_candidate'] else ""
                cb_marker = " [CRITICAL: CB/DM/FB coverage]" if u['is_cb_universalist'] else ""

                print(f"  [UTIL] {u['name']:28} (Versatility: {u['versatility']:2.0f}) | Coverage: {u['total_coverage']} positions{tier3_marker}{cb_marker}")
                if accomplished:
                    print(f"         Accomplished: {accomplished}")
                if competent:
                    print(f"         Competent: {competent}")
                print()

        if has_abilities:
            print("\nICON LEGEND:")
            print("  QUALITY: ** = Excellent | ++ = Good | == = Adequate | -- = Below standard")
            print("  STATUS:  [INJ] = Injury risk | [UTIL] = Universalist (3+ positions)")
            print("  ZONES:   [HIGH ATTRITION] = Needs extra depth due to Unity engine fatigue")

        print("=" * 120)

    def print_training_recommendations(self):
        """Print formatted training recommendations."""
        recommendations = self.recommend_training()

        if not recommendations:
            print("\n" + "=" * 110)
            print("TRAINING RECOMMENDATIONS")
            print("=" * 110)

            if not self.has_abilities:
                print("\nWARNING: Cannot provide training recommendations without role ability data.")
                print("\nTo get intelligent training recommendations:")
                print("  1. Export player role ability ratings from FM26 (Squad view with Striker, AM(L), etc. columns)")
                print("  2. Save as players.csv")
                print("  3. Run: python fm_training_advisor.py players-current.csv players.csv")
                print("\nRole ability ratings show how GOOD each player is at each position based on their attributes.")
                print("This is different from positional skill ratings (1-20 familiarity scale) already in players-current.csv.")
            else:
                print("\nSUCCESS: No training recommendations needed - squad depth and quality are adequate at all positions!")

            print("=" * 110)
            return

        print("\n" + "=" * 110)
        print("INTELLIGENT TRAINING RECOMMENDATIONS")
        print("=" * 110)
        print("\nRecommendations based on positional skill ratings, role abilities, and training attributes:")
        print("NOTE: Each player appears only once - assigned to the position where training provides greatest squad benefit.")
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
                print(f"  Player: {rec['player']:28} -> Train as: {rec['position']:8} [{rec['category']}]")

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
        print("  * Become Natural: Players with good ability who should train to reach Natural (18+) familiarity")
        print("  * Improve Natural: Players already Natural but need to improve their ability through training")
        print("  * Learn Position: Players with potential who should train into a new position")
        print()
        print("TRAINING TIMELINE EXPECTATIONS:")
        print("  * Competent level (10/20):  6-9 months of training + match experience")
        print("  * Accomplished level (13+): 12 months of training + regular playing time")
        print("  * Natural level (18+):      12-24 months (requires consistent matches)")
        print()
        print("KEY FACTORS FOR FASTER TRAINING:")
        print("  * Age under 24 (younger players learn faster)")
        print("  * High Versatility attribute (accelerates position learning)")
        print("  * High Professionalism (trains harder and more effectively)")
        print("  * Natural in similar positions (easier to adapt)")
        print("  * Both individual training AND match experience needed")
        print("=" * 110)

    def export_training_recommendations_to_csv(self, output_file: str = 'training_recommendations.csv') -> str:
        """
        Export training recommendations to CSV file with strategic context.

        Args:
            output_file: Path to output CSV file

        Returns:
            Path to created file
        """
        recommendations = self.recommend_training()

        if not recommendations:
            print(f"\nNo training recommendations to export.")
            return None

        # Get universalists and tactical variety info for export
        universalists = self.identify_universalist_candidates()
        universalist_names = {u['name']: u['total_coverage'] for u in universalists}

        # Convert recommendations to DataFrame with strategic columns
        export_data = []
        for rec in recommendations:
            player_name = rec['player']
            position = rec['position']

            # Determine strategic category
            strategic_category = rec.get('category', 'Standard')
            if 'winger' in rec['reason'].lower() and position in ['D(R)', 'D(L)']:
                strategic_category += ' | Winger→WB Pipeline'
            elif 'aging' in rec['reason'].lower() and 'playmaker' in rec['reason'].lower():
                strategic_category += ' | Aging AMC→DM'

            # Check if universalist
            is_universalist = player_name in universalist_names
            universalist_positions = universalist_names.get(player_name, 0)

            # Estimate timeline based on current skill
            current_skill = rec['current_skill_rating']
            if current_skill >= 13:
                timeline = '2-4 months to Natural'
            elif current_skill >= 10:
                timeline = '6-9 months to Natural'
            elif current_skill >= 8:
                timeline = '12+ months to Competent'
            else:
                timeline = '18+ months (high versatility needed)'

            # Check for tactical variety fill
            variety_info = self.assess_positional_variety(position)
            fills_variety_gap = len(variety_info.get('needs', [])) > 0

            export_data.append({
                'Player': player_name,
                'Position': position,
                'Priority': rec['priority'],
                'Strategic_Category': strategic_category,
                'Current_Skill_Rating': rec['current_skill_rating'],
                'Current_Skill_Tier': rec['current_skill'],
                'Ability_Tier': rec['ability_tier'],
                'Ability_Rating': rec.get('ability_rating', ''),
                'Age': rec['age'],
                'Training_Score': round(rec['training_score'], 2),
                'Estimated_Timeline': timeline,
                'Is_Universalist': 'Yes' if is_universalist else 'No',
                'Universalist_Coverage': universalist_positions if is_universalist else 0,
                'Fills_Variety_Gap': 'Yes' if fills_variety_gap else 'No',
                'Reason': rec['reason']
            })

        df = pd.DataFrame(export_data)

        # Export to CSV
        df.to_csv(output_file, index=False, encoding='utf-8')

        return output_file


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

        # Export training recommendations to CSV
        output_file = advisor.export_training_recommendations_to_csv()
        if output_file:
            print(f"\n[SUCCESS] Training recommendations exported to: {output_file}")

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
