import sys
import os
import json
import contextlib
import pandas as pd
import numpy as np
import re

# Add root directory to sys.path to allow importing from root scripts
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../')))

import data_manager
from fm_match_ready_selector import MatchReadySelector

@contextlib.contextmanager
def suppress_stdout():
    """Context manager to suppress stdout during initialization."""
    with open(os.devnull, 'w') as devnull:
        old_stdout = sys.stdout
        sys.stdout = devnull
        try:
            yield
        finally:
            sys.stdout = old_stdout


class PlayerRemovalAdvisor:
    """
    Analyzes squad to recommend players for removal based on:
    - Skill level vs team and position competitors
    - Wage efficiency
    - Contract situation
    - Hidden attributes (consistency, injury proneness, etc.)

    Based on research from player-management-and-sales.md
    """

    # Position groups for skill comparison
    POSITION_GROUPS = {
        'GK': ['GK'],
        'DEF': ['D(C)', 'D(R/L)'],
        'MID': ['DM(L)', 'DM(R)', 'AM(C)', 'AM(L)', 'AM(R)'],
        'ATT': ['Striker', 'AM(L)', 'AM(R)', 'AM(C)']
    }

    # Map positions from player data to skill columns
    POSITION_TO_SKILL = {
        'GK': 'GK',
        'D (C)': 'D(C)',
        'D (L)': 'D(R/L)',
        'D (R)': 'D(R/L)',
        'D (RC)': 'D(C)',
        'D (LC)': 'D(C)',
        'D/WB (L)': 'D(R/L)',
        'D/WB (R)': 'D(R/L)',
        'WB (L)': 'D(R/L)',
        'WB (R)': 'D(R/L)',
        'DM': 'DM(L)',
        'DM (C)': 'DM(L)',
        'M (C)': 'AM(C)',
        'M (L)': 'AM(L)',
        'M (R)': 'AM(R)',
        'AM (C)': 'AM(C)',
        'AM (L)': 'AM(L)',
        'AM (R)': 'AM(R)',
        'ST (C)': 'Striker',
    }

    def __init__(self, csv_filepath):
        """Load player data from CSV."""
        self.df = pd.read_csv(csv_filepath)

        # Ensure numeric columns (including new hidden attributes from retention strategy research)
        numeric_cols = ['CA', 'PA', 'Age', 'Consistency', 'Important Matches',
                       'Injury Proneness', 'Adaptability', 'Ambition', 'Loyalty',
                       'Professional', 'Controversy', 'Temperament', 'Determination',
                       'Natural Fitness', 'Pressure',  # Added for retention strategy analysis
                       'GK', 'D(C)', 'D(R/L)', 'DM(L)', 'DM(R)',
                       'AM(L)', 'AM(C)', 'AM(R)', 'Striker', 'Months Left (Contract)']

        for col in numeric_cols:
            if col in self.df.columns:
                self.df[col] = pd.to_numeric(self.df[col], errors='coerce')

        # Parse wage strings to numeric (remove $ and , and convert)
        if 'Wages' in self.df.columns:
            self.df['Wages_Numeric'] = self.df['Wages'].apply(self._parse_currency)
        else:
            self.df['Wages_Numeric'] = 0

        # Parse asking price similarly
        if 'Asking Price' in self.df.columns:
            self.df['Asking_Price_Numeric'] = self.df['Asking Price'].apply(self._parse_currency)
        else:
            self.df['Asking_Price_Numeric'] = 0

        # Initialize match selector for hierarchy-based analysis
        # This provides Starting XI / Second XI rankings per position
        try:
            with suppress_stdout():
                self.match_selector = MatchReadySelector(csv_filepath, csv_filepath)
            self.player_hierarchy = self.match_selector._calculate_player_hierarchy()
        except Exception as e:
            print(f"Warning: Could not initialize hierarchy analysis: {e}")
            self.match_selector = None
            self.player_hierarchy = {}

    def _get_best_hierarchy_tier(self, player_name):
        """
        Get the player's best (lowest) hierarchy tier across all positions.

        The hierarchy system ranks players per position:
        - Tier 1: Starting XI (best player at position)
        - Tier 2: Second XI (second best at position)
        - Tier 3: Backup (all others)

        A player might be Tier 1 at one position but Tier 3 at another.
        This method returns their BEST tier (lowest number = more important).

        Returns:
            tuple: (best_tier, positions_dict)
                - best_tier: 1, 2, or 3 (lowest tier across all positions)
                - positions_dict: {position: tier} for all positions where player has a tier
        """
        if not self.player_hierarchy:
            return 3, {}

        positions_dict = {}
        best_tier = 3

        for pos_name, tiers in self.player_hierarchy.items():
            if tiers['starting'][0] == player_name:
                positions_dict[pos_name] = 1
                best_tier = min(best_tier, 1)
            elif tiers['second'][0] == player_name:
                positions_dict[pos_name] = 2
                best_tier = min(best_tier, 2)

        return best_tier, positions_dict

    def _parse_currency(self, val):
        """Convert currency string like '$1,234' to numeric 1234."""
        if pd.isna(val):
            return 0
        if isinstance(val, (int, float)):
            return float(val)
        # Remove $ and commas
        cleaned = re.sub(r'[$,]', '', str(val))
        try:
            return float(cleaned)
        except:
            return 0

    def _get_best_position_skill(self, row):
        """Get player's best position skill rating."""
        positions_str = row.get('Positions', '')

        # Try to find skill column for player's position
        if pd.notna(positions_str):
            # Positions can be comma-separated
            positions = str(positions_str).split(',')
            best_skill = 0
            best_col = None

            for pos in positions:
                pos = pos.strip()
                skill_col = self.POSITION_TO_SKILL.get(pos)
                if skill_col and skill_col in self.df.columns:
                    val = row.get(skill_col, 0)
                    if pd.notna(val) and val > best_skill:
                        best_skill = val
                        best_col = skill_col

            if best_col:
                return best_skill, best_col

        # Fallback: find their highest skill
        skill_cols = ['GK', 'D(C)', 'D(R/L)', 'DM(L)', 'DM(R)', 'AM(L)', 'AM(C)', 'AM(R)', 'Striker']
        best_skill = 0
        best_col = None

        for col in skill_cols:
            if col in self.df.columns:
                val = row.get(col, 0)
                if pd.notna(val) and val > best_skill:
                    best_skill = val
                    best_col = col

        return best_skill, best_col

    def _calculate_termination_cost(self, row):
        """
        Calculate contract termination cost.
        Per research: Release on a Free = entire remaining contract value upfront
        Mutual termination typically 50-60% of remaining value.

        Returns (release_cost, mutual_termination_estimate)
        """
        wages_weekly = row.get('Wages_Numeric', 0)
        months_left = row.get('Months Left (Contract)', 0)
        contract_type = row.get('Contract Type', '')
        loan_status = row.get('LoanStatus', 'Own')

        # Loaned-in players: no termination cost (we don't own them)
        if loan_status == 'LoanedIn':
            return 0, 0

        # Non-contract (type 4) has no termination cost
        if str(contract_type) == '4' or months_left < 0:
            return 0, 0

        # Calculate total remaining wages
        # Weekly wage * 4.33 weeks/month * months remaining
        weekly_to_monthly = 4.33
        total_remaining = wages_weekly * weekly_to_monthly * max(0, months_left)

        # Mutual termination estimate (55% average of 50-60%)
        mutual_estimate = total_remaining * 0.55

        return total_remaining, mutual_estimate

    def _get_position_rank(self, player_name, skill_col):
        """Get player's rank among position competitors (1 = best)."""
        if skill_col not in self.df.columns:
            return 0, 0

        # Sort by this skill descending
        sorted_df = self.df.sort_values(by=skill_col, ascending=False)

        # Find player's rank
        rank = 1
        for idx, row in sorted_df.iterrows():
            if row['Name'] == player_name:
                return rank, len(sorted_df)
            rank += 1

        return 0, len(sorted_df)

    def _get_position_role(self, skill_col):
        """
        Classify player's primary role for position-specific thresholds.
        Based on retention strategy research which defines different standards by role.
        """
        if skill_col == 'GK':
            return 'goalkeeper'
        elif skill_col in ['D(C)', 'D(R/L)']:
            return 'defender'
        elif skill_col in ['DM(L)', 'DM(R)', 'AM(C)']:
            return 'playmaker'
        elif skill_col in ['AM(L)', 'AM(R)', 'Striker']:
            return 'attacker'
        return 'general'

    def _calculate_growth_velocity(self, ca, pa, age):
        """
        Calculate Required Growth Velocity (RGV) to reach PA by peak age (24).
        Research formula: RGV = (PA - CA) / (24 - Current Age)

        If RGV > 15 CA/year and low professionalism, player is unlikely to reach PA.
        These are "False Wonderkids" - valued highly by market but structurally
        incapable of reaching their theoretical ceiling.
        """
        if age >= 24 or pa <= ca:
            return 0  # Past peak or at ceiling

        years_to_peak = 24 - age
        if years_to_peak <= 0:
            return 0

        required_ca_per_year = (pa - ca) / years_to_peak
        return required_ca_per_year

    def _classify_removal_priority(self, row, skill, skill_col, position_rank, total_players,
                                   squad_avg_ca, release_cost, hierarchy_tier=3, hierarchy_positions=None):
        """
        Classify player removal priority based on research criteria.

        Args:
            hierarchy_tier: Player's best tier across all positions (1=Starting XI, 2=Second XI, 3=Backup)
            hierarchy_positions: Dict of {position: tier} for positions where player is Tier 1 or 2

        Returns dict with priority, reasons, action, scores, and metadata
        """
        if hierarchy_positions is None:
            hierarchy_positions = {}
        reasons = []
        ca = row.get('CA', 0)
        pa = row.get('PA', 0)
        age = row.get('Age', 30)  # Default to older if unknown
        wages = row.get('Wages_Numeric', 0)
        contract_type = row.get('Contract Type', '')
        months_left = row.get('Months Left (Contract)', 0)
        asking_price = row.get('Asking_Price_Numeric', 0)
        loan_status = row.get('LoanStatus', 'Own')

        # Hidden attributes (from research - impact squad stability and development)
        consistency = row.get('Consistency', 10)
        important_matches = row.get('Important Matches', 10)
        injury_proneness = row.get('Injury Proneness', 10)
        ambition = row.get('Ambition', 10)
        loyalty = row.get('Loyalty', 10)
        professional = row.get('Professional', 10)
        # New hidden attributes from retention strategy research
        controversy = row.get('Controversy', 10)
        temperament = row.get('Temperament', 10)
        determination = row.get('Determination', 10)
        natural_fitness = row.get('Natural Fitness', 10)
        pressure = row.get('Pressure', 10)

        # Calculate development headroom
        development_headroom = (pa - ca) if (pa > 0 and ca > 0) else 0
        headroom_percentage = (development_headroom / ca * 100) if ca > 0 else 0

        # Check if loaned in
        is_loaned_in = (loan_status == 'LoanedIn')

        # Calculate wage efficiency (CA per wage)
        wage_efficiency = ca / wages if wages > 0 else float('inf')

        # Calculate Required Growth Velocity (RGV) for young players
        required_growth_velocity = self._calculate_growth_velocity(ca, pa, age)

        # Get position role for position-specific thresholds
        position_role = self._get_position_role(skill_col)

        # Track if player is a mentor candidate
        is_mentor_candidate = False

        priority_score = 0  # Higher = more need to remove

        # ============================================
        # LOAN PLAYERS: Use loan-specific logic
        # ============================================
        if is_loaned_in:
            # Loan players get simplified scoring based on performance/utility
            # Skip: termination cost, wage deadwood (not our wages), contract expiry

            # Position depth analysis still applies
            if total_players > 0:
                position_percentile = position_rank / total_players
                if position_percentile > 0.7:  # Bottom 30%
                    priority_score += 30
                    reasons.append(f"Bottom {int((1-position_percentile)*100)}% at position (rank #{position_rank})")

            # Hierarchy-based analysis for loans
            if hierarchy_tier == 1:
                tier1_positions = [p for p, t in hierarchy_positions.items() if t == 1]
                priority_score -= 30  # Moderate protection for loans
                reasons.append(f"🏆 Starting XI quality at: {', '.join(tier1_positions)}")
            elif hierarchy_tier == 2:
                tier2_positions = [p for p, t in hierarchy_positions.items() if t == 2]
                priority_score -= 15
                reasons.append(f"📋 Second XI quality at: {', '.join(tier2_positions)}")
            elif hierarchy_tier == 3 and not hierarchy_positions:
                priority_score += 20
                reasons.append("⚠️ Not competitive for Starting/Second XI")

            # Below squad average CA
            if ca < squad_avg_ca * 0.85:
                priority_score += 25
                reasons.append(f"CA ({ca}) significantly below squad average ({squad_avg_ca:.0f})")
            elif ca < squad_avg_ca:
                priority_score += 10
                reasons.append(f"CA ({ca}) below squad average ({squad_avg_ca:.0f})")

            # Hidden attribute red flags still apply
            if pd.notna(consistency) and consistency < 8:
                priority_score += 20
                reasons.append(f"Low consistency ({consistency}) - unreliable over season")

            if pd.notna(important_matches) and important_matches < 8:
                priority_score += 15
                reasons.append(f"Low big match performance ({important_matches})")

            if pd.notna(injury_proneness) and injury_proneness > 14:
                priority_score += 25
                reasons.append(f"High injury proneness ({injury_proneness}) - frequent disruptions")

            # Loan-specific actions based on priority
            if priority_score >= 50:
                priority = "End Early"
                action = "End loan early - not contributing"
            elif priority_score >= 25:
                priority = "Monitor"
                action = "Do not extend/make permanent"
            else:
                priority = "Keep"
                if ca >= squad_avg_ca and position_rank <= 3:
                    action = "Consider making permanent"
                else:
                    action = "Keep until loan expires"

            # Return dictionary format for consistency
            return {
                'priority': priority,
                'reasons': reasons,
                'action': action,
                'priority_score': priority_score,
                'is_loaned_in': is_loaned_in,
                'development_headroom': development_headroom,
                'headroom_percentage': headroom_percentage,
                # Hierarchy-based analysis
                'hierarchy_tier': hierarchy_tier,
                'hierarchy_positions': hierarchy_positions,
                # New fields (may not all apply to loans, but include for consistency)
                'required_growth_velocity': required_growth_velocity,
                'position_role': position_role,
                'is_mentor_candidate': False,  # Loans can't be mentors
                'ambition': int(ambition) if pd.notna(ambition) else None,
                'controversy': int(controversy) if pd.notna(controversy) else None,
                'temperament': int(temperament) if pd.notna(temperament) else None,
                'determination': int(determination) if pd.notna(determination) else None,
                'professional': int(professional) if pd.notna(professional) else None,
            }

        # ============================================
        # OWNED PLAYERS: Full scoring logic
        # Based on retention strategy research document
        # ============================================

        # 1. Non-Contract Players (Contract Type = 4)
        if str(contract_type) == '4':
            priority_score += 50
            reasons.append("Non-contract player - can be released freely")

        # 2. Position depth analysis
        if total_players > 0:
            position_percentile = position_rank / total_players
            if position_percentile > 0.7:  # Bottom 30%
                priority_score += 30
                reasons.append(f"Bottom {int((1-position_percentile)*100)}% at position (rank #{position_rank})")
            elif position_rank <= 2:  # Top 2 at position = STARTER, strong protection
                priority_score -= 30
                reasons.append(f"Key player: Ranked #{position_rank} at {skill_col} - starter/first backup")

        # 2b. HIERARCHY-BASED ANALYSIS (Starting XI / Second XI rankings)
        # This uses optimal lineup selection to identify truly essential players
        if hierarchy_tier == 1:
            # Player is the BEST at some position - critical to keep
            tier1_positions = [p for p, t in hierarchy_positions.items() if t == 1]
            priority_score -= 40  # Strong protection
            reasons.append(f"🏆 Starting XI player at: {', '.join(tier1_positions)}")
        elif hierarchy_tier == 2:
            # Player is second-best at some position - important backup
            tier2_positions = [p for p, t in hierarchy_positions.items() if t == 2]
            priority_score -= 20  # Moderate protection
            reasons.append(f"📋 Second XI player at: {', '.join(tier2_positions)}")
        elif hierarchy_tier == 3 and not hierarchy_positions:
            # Player is NOT in Starting XI or Second XI at ANY position
            # This is a deep backup with limited squad value
            priority_score += 15
            reasons.append("⚠️ Not in Starting XI or Second XI at any position")

        # 3. Below squad average CA
        if ca < squad_avg_ca * 0.85:
            priority_score += 25
            reasons.append(f"CA ({ca}) significantly below squad average ({squad_avg_ca:.0f})")
        elif ca < squad_avg_ca:
            priority_score += 10
            reasons.append(f"CA ({ca}) below squad average ({squad_avg_ca:.0f})")

        # 4. Wage deadwood (high wages, low ability)
        if wages > 500 and wage_efficiency < 0.1:
            priority_score += 35
            reasons.append(f"Poor wage efficiency: ${wages:.0f}/week for {ca} CA")
        elif wages > 300 and wage_efficiency < 0.15:
            priority_score += 20
            reasons.append(f"Below average wage efficiency")

        # 5. Contract running down (loss of leverage)
        if 0 < months_left <= 6:
            priority_score += 25
            reasons.append(f"Contract expires in {months_left} months - sell now or lose value")
        elif 0 < months_left <= 12:
            priority_score += 15
            reasons.append(f"Contract expires in {months_left} months - consider selling")

        # ============================================
        # 6. HIDDEN ATTRIBUTE RED FLAGS (Research-based thresholds)
        # ============================================

        # Consistency: Research says < 9 = Sell Zone (adjusted from < 8)
        if pd.notna(consistency) and consistency < 9:
            if consistency < 8:
                priority_score += 25
                reasons.append(f"Critical: Low consistency ({consistency}) - unreliable performer")
            else:
                priority_score += 15
                reasons.append(f"Low consistency ({consistency}) - variance risk")

        # Big Match Performance (Important Matches): < 8 = Hard Sell
        if pd.notna(important_matches) and important_matches < 8:
            priority_score += 20
            reasons.append(f"Low big match performance ({important_matches}) - chokes under pressure")

        # Injury Proneness: > 14 = Hard Sell (matches research)
        if pd.notna(injury_proneness) and injury_proneness > 14:
            priority_score += 25
            reasons.append(f"High injury proneness ({injury_proneness}) - frequent disruptions")

        # Professionalism: Research says < 10 = Hard Sell (adjusted from < 8)
        if pd.notna(professional) and professional < 10:
            if professional < 8:
                priority_score += 25
                reasons.append(f"Critical: Low professionalism ({professional}) - will not reach potential")
            else:
                priority_score += 15
                reasons.append(f"Low professionalism ({professional}) - development/longevity risk")

        # NEW: Ambition < 6 = Hard Sell (unambitious, stunted development)
        if pd.notna(ambition) and ambition < 6:
            priority_score += 25
            reasons.append(f"Low ambition ({ambition}) - lacks drive to improve")

        # NEW: Controversy > 16 = Toxic (destabilizes squad dynamics)
        if pd.notna(controversy) and controversy > 16:
            priority_score += 25
            reasons.append(f"High controversy ({controversy}) - destabilizes team dynamics")

        # NEW: Temperament < 8 = Indiscipline risk
        if pd.notna(temperament) and temperament < 8:
            priority_score += 15
            reasons.append(f"Low temperament ({temperament}) - prone to indiscipline")

        # ============================================
        # 7. POSITION-SPECIFIC RETENTION THRESHOLDS
        # Research: Different positions have different critical traits
        # ============================================

        if position_role == 'goalkeeper' or position_role == 'defender':
            # Defensive spine needs high consistency and pressure handling
            if pd.notna(consistency) and consistency < 13:
                priority_score += 15
                reasons.append(f"Below defensive spine threshold (Consistency {consistency} < 13)")
            if pd.notna(important_matches) and important_matches < 12:
                priority_score += 10
                reasons.append(f"Below defensive spine threshold (Big Matches {important_matches} < 12)")

        elif position_role == 'playmaker':
            # Playmakers need ambition and professionalism to unlock potential
            if pd.notna(ambition) and ambition < 14:
                priority_score += 10
                reasons.append(f"Below playmaker threshold (Ambition {ambition} < 14)")
            if pd.notna(professional) and professional < 14:
                priority_score += 10
                reasons.append(f"Below playmaker threshold (Pro {professional} < 14)")

        elif position_role == 'attacker':
            # Strikers need to handle pressure and have killer instinct
            if pd.notna(important_matches) and important_matches < 14:
                priority_score += 15
                reasons.append(f"Below striker threshold (Big Matches {important_matches} < 14)")
            if pd.notna(ambition) and ambition < 15:
                priority_score += 10
                reasons.append(f"Below striker threshold (Ambition {ambition} < 15)")

        # ============================================
        # 8. FALSE WONDERKID DETECTION (RGV Analysis)
        # Research: If RGV > 15 CA/year and low professionalism, unlikely to reach PA
        # NOTE: Only applies to YOUNG players (≤20) - the formula breaks down near age 24
        # ============================================

        if age <= 20 and required_growth_velocity > 15:
            if professional < 14:  # Not Model Professional level
                priority_score += 35
                reasons.append(f"False Wonderkid: Needs {required_growth_velocity:.0f} CA/year to reach PA, unlikely with Pro {professional}")

        # ============================================
        # 9. DEVELOPMENT CHECKPOINT SYSTEM (18-21-24)
        # Research-based age checkpoints for release/sell decisions
        # ============================================

        # Age 18 checkpoint: Release if Professionalism < 8
        if age == 18 and pd.notna(professional) and professional < 8:
            priority_score += 25
            reasons.append("Age 18 checkpoint: Low professionalism - release candidate")

        # Age 21 checkpoint (False Wonderkid window): Sell if large CA gap and low Pro
        if 19 <= age <= 21:
            ca_gap = pa - ca
            if ca_gap > 50 and professional < 12:
                priority_score += 30
                reasons.append(f"Age 21 window: Large CA gap ({ca_gap}) with low Pro ({professional}) - sell while PA looks high")

        # Age 24 checkpoint (Final verdict): Last chance to sell on potential
        if 23 <= age <= 24:
            if ca < squad_avg_ca and headroom_percentage < 10:
                priority_score += 20
                reasons.append("Age 24 checkpoint: Below average and near ceiling - last chance to sell on potential")

        # ============================================
        # 10. U21 DEVELOPMENT PROTECTION
        # (moderate - reduces but doesn't eliminate flags)
        # ============================================

        if age <= 21:
            if headroom_percentage >= 30:  # PA is 30%+ higher than CA
                priority_score -= 30  # Moderate protection
                reasons.append(f"U21 prospect with high potential ({headroom_percentage:.0f}% room to grow)")
            elif headroom_percentage >= 15:
                priority_score -= 15
                reasons.append(f"U21 with development potential ({headroom_percentage:.0f}% room to grow)")

        # ============================================
        # 11. MENTOR RETENTION VALUE
        # Research: Keep high-Pro veterans as mentors for youth development
        # ============================================

        if age >= 30 and pd.notna(professional) and professional >= 16:
            # Check if truly valuable mentor (Model Citizen/Professional level)
            if pd.notna(determination) and determination >= 15:
                priority_score -= 40  # Strong protection
                is_mentor_candidate = True
                reasons.append(f"Mentor value: High Pro ({professional}) + Det ({determination}) - valuable for youth development")
            else:
                priority_score -= 20
                is_mentor_candidate = True
                reasons.append(f"Mentor value: High professionalism ({professional}) - consider keeping for mentoring")

        # ============================================
        # 12. PEAK VALUE DIVESTMENT WINDOWS & AGE PENALTIES
        # Research: Sell physical-dependent players before decline
        # ============================================

        # Physical position decline warning (Age 29+ attackers with low Natural Fitness)
        if age >= 29 and position_role == 'attacker':
            if pd.notna(natural_fitness) and natural_fitness < 12:
                priority_score += 20
                reasons.append(f"Approaching decline: Physical attacker age {age} with low Natural Fitness ({natural_fitness})")

        # General age penalties (reduced weight to avoid double-counting with mentor logic)
        if age >= 30 and headroom_percentage < 5 and not is_mentor_candidate:
            priority_score += 10
            reasons.append(f"Veteran with limited development potential")
        if age >= 32 and not is_mentor_candidate:
            priority_score += 5
            reasons.append(f"Age {age} - approaching career end")

        # Determine priority category and recommended action
        if priority_score >= 80:
            priority = "Critical"
            if str(contract_type) == '4':
                action = "Release immediately (no cost)"
            elif asking_price > release_cost * 0.5:
                action = "Transfer List - high priority sale"
            else:
                action = "Mutual Termination"
        elif priority_score >= 50:
            priority = "High"
            if asking_price > 0:
                action = "Transfer List or Loan with Option"
            else:
                action = "Loan out or Mutual Termination"
        elif priority_score >= 30:
            priority = "Medium"
            action = "Monitor - consider for rotation/development"
        else:
            priority = "Low"
            action = "Keep - squad member"

        # Package all new fields for return
        return {
            'priority': priority,
            'reasons': reasons,
            'action': action,
            'priority_score': priority_score,
            'is_loaned_in': is_loaned_in,
            'development_headroom': development_headroom,
            'headroom_percentage': headroom_percentage,
            # Hierarchy-based analysis
            'hierarchy_tier': hierarchy_tier,
            'hierarchy_positions': hierarchy_positions,
            # New fields from retention strategy research
            'required_growth_velocity': required_growth_velocity,
            'position_role': position_role,
            'is_mentor_candidate': is_mentor_candidate,
            'ambition': int(ambition) if pd.notna(ambition) else None,
            'controversy': int(controversy) if pd.notna(controversy) else None,
            'temperament': int(temperament) if pd.notna(temperament) else None,
            'determination': int(determination) if pd.notna(determination) else None,
            'professional': int(professional) if pd.notna(professional) else None,
        }

    def get_removal_recommendations(self):
        """
        Generate player removal recommendations for the entire squad.

        Returns list of recommendations sorted by removal priority.
        """
        recommendations = []

        # Calculate squad average CA
        squad_avg_ca = self.df['CA'].mean() if 'CA' in self.df.columns else 80

        for idx, row in self.df.iterrows():
            name = row.get('Name', 'Unknown')
            ca = row.get('CA', 0)
            pa = row.get('PA', 0)
            age = row.get('Age', 0)
            positions = row.get('Positions', '')
            contract_type = row.get('Contract Type', '')
            wages = row.get('Wages_Numeric', 0)
            months_left = row.get('Months Left (Contract)', 0)
            asking_price = row.get('Asking_Price_Numeric', 0)
            loan_status = row.get('LoanStatus', 'Own')

            # Skip if CA is NaN or zero (likely invalid entry)
            if pd.isna(ca) or ca == 0:
                continue

            # Get best skill and position
            best_skill, skill_col = self._get_best_position_skill(row)

            # Get position rank
            position_rank, total_at_position = self._get_position_rank(name, skill_col)

            # Calculate termination costs
            release_cost, mutual_cost = self._calculate_termination_cost(row)

            # Get hierarchy tier (Starting XI = 1, Second XI = 2, Backup = 3)
            hierarchy_tier, hierarchy_positions = self._get_best_hierarchy_tier(name)

            # Classify removal priority (now returns a dictionary)
            result = self._classify_removal_priority(
                row, best_skill, skill_col, position_rank, total_at_position,
                squad_avg_ca, release_cost, hierarchy_tier, hierarchy_positions
            )

            # Format contract type display
            contract_type_display = contract_type
            if str(contract_type) == '4':
                contract_type_display = "Non-Contract"

            recommendations.append({
                "name": name,
                "age": int(age) if pd.notna(age) else 0,
                "positions": str(positions) if pd.notna(positions) else "",
                "ca": int(ca) if pd.notna(ca) else 0,
                "pa": int(pa) if pd.notna(pa) else 0,
                "squad_avg_ca": round(squad_avg_ca, 1),
                "best_skill": round(best_skill, 1) if pd.notna(best_skill) else 0,
                "skill_position": skill_col or "",
                "position_rank": position_rank,
                "total_at_position": total_at_position,
                "contract_type": contract_type_display,
                "wages_weekly": round(wages, 0),
                "months_remaining": int(months_left) if pd.notna(months_left) and months_left > 0 else 0,
                "asking_price": round(asking_price, 0),
                "release_cost": round(release_cost, 0),
                "mutual_termination_cost": round(mutual_cost, 0),
                "loan_status": loan_status,
                "is_loaned_in": result['is_loaned_in'],
                "priority": result['priority'],
                "priority_score": result['priority_score'],
                "reasons": result['reasons'],
                "recommended_action": result['action'],
                # Development potential fields
                "development_headroom": int(result['development_headroom']),
                "headroom_percentage": round(result['headroom_percentage'], 1),
                # Hidden attributes for display (existing)
                "consistency": int(row.get('Consistency', 0)) if pd.notna(row.get('Consistency')) else None,
                "important_matches": int(row.get('Important Matches', 0)) if pd.notna(row.get('Important Matches')) else None,
                "injury_proneness": int(row.get('Injury Proneness', 0)) if pd.notna(row.get('Injury Proneness')) else None,
                # NEW: Additional hidden attributes and analysis from retention strategy
                "required_growth_velocity": round(result['required_growth_velocity'], 1) if result['required_growth_velocity'] else None,
                "position_role": result['position_role'],
                "is_mentor_candidate": result['is_mentor_candidate'],
                "ambition": result['ambition'],
                "controversy": result['controversy'],
                "temperament": result['temperament'],
                "determination": result['determination'],
                "professional": result['professional'],
                # Hierarchy-based analysis (Starting XI / Second XI rankings)
                "hierarchy_tier": result['hierarchy_tier'],
                "hierarchy_positions": result['hierarchy_positions'],
            })

        # Sort by priority score descending (highest = most need to remove)
        recommendations.sort(key=lambda x: -x['priority_score'])

        return recommendations


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
        # Read JSON from stdin (not needed for this endpoint)
        input_str = sys.stdin.read()

        # 1. UPDATE DATA FROM EXCEL
        with suppress_stdout():
            data_manager.update_player_data()

        csv_file = 'players-current.csv'

        advisor = PlayerRemovalAdvisor(csv_file)
        recommendations = advisor.get_removal_recommendations()

        print(json.dumps({"success": True, "recommendations": recommendations}, cls=NumpyEncoder))

    except Exception as e:
        import traceback
        print(json.dumps({"success": False, "error": str(e), "traceback": traceback.format_exc()}))


if __name__ == '__main__':
    main()
