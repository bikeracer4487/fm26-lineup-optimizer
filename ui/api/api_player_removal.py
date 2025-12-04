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

        # Ensure numeric columns
        numeric_cols = ['CA', 'PA', 'Age', 'Consistency', 'Important Matches',
                       'Injury Proneness', 'Adaptability', 'Ambition', 'Loyalty',
                       'Professional', 'GK', 'D(C)', 'D(R/L)', 'DM(L)', 'DM(R)',
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

    def _classify_removal_priority(self, row, skill, position_rank, total_players,
                                   squad_avg_ca, release_cost):
        """
        Classify player removal priority based on research criteria.

        Returns (priority, reasons, recommended_action, priority_score, is_loaned_in, development_headroom, headroom_percentage)
        """
        reasons = []
        ca = row.get('CA', 0)
        pa = row.get('PA', 0)
        age = row.get('Age', 30)  # Default to older if unknown
        wages = row.get('Wages_Numeric', 0)
        contract_type = row.get('Contract Type', '')
        months_left = row.get('Months Left (Contract)', 0)
        asking_price = row.get('Asking_Price_Numeric', 0)
        loan_status = row.get('LoanStatus', 'Own')

        # Hidden attributes (from research - impact squad stability)
        consistency = row.get('Consistency', 10)
        important_matches = row.get('Important Matches', 10)
        injury_proneness = row.get('Injury Proneness', 10)
        ambition = row.get('Ambition', 10)
        loyalty = row.get('Loyalty', 10)
        professional = row.get('Professional', 10)

        # Calculate development headroom
        development_headroom = (pa - ca) if (pa > 0 and ca > 0) else 0
        headroom_percentage = (development_headroom / ca * 100) if ca > 0 else 0

        # Check if loaned in
        is_loaned_in = (loan_status == 'LoanedIn')

        # Calculate wage efficiency (CA per wage)
        wage_efficiency = ca / wages if wages > 0 else float('inf')

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

            return priority, reasons, action, priority_score, is_loaned_in, development_headroom, headroom_percentage

        # ============================================
        # OWNED PLAYERS: Full scoring logic
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

        # 6. Hidden attribute red flags (from research Table 1)
        if pd.notna(consistency) and consistency < 8:
            priority_score += 20
            reasons.append(f"Low consistency ({consistency}) - unreliable over season")

        if pd.notna(important_matches) and important_matches < 8:
            priority_score += 15
            reasons.append(f"Low big match performance ({important_matches})")

        if pd.notna(injury_proneness) and injury_proneness > 14:
            priority_score += 25
            reasons.append(f"High injury proneness ({injury_proneness}) - frequent disruptions")

        if pd.notna(professional) and professional < 8:
            priority_score += 15
            reasons.append(f"Low professionalism ({professional}) - development risk")

        # 7. U21 DEVELOPMENT PROTECTION (moderate - reduces but doesn't eliminate flags)
        if age <= 21:
            if headroom_percentage >= 30:  # PA is 30%+ higher than CA
                priority_score -= 30  # Moderate protection
                reasons.append(f"U21 prospect with high potential ({headroom_percentage:.0f}% room to grow)")
            elif headroom_percentage >= 15:
                priority_score -= 15
                reasons.append(f"U21 with development potential ({headroom_percentage:.0f}% room to grow)")

        # 8. Older players with no upside get slight priority increase
        if age >= 30 and headroom_percentage < 5:
            priority_score += 10
            reasons.append(f"Veteran with limited development potential")
        if age >= 32:
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

        return priority, reasons, action, priority_score, is_loaned_in, development_headroom, headroom_percentage

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

            # Classify removal priority
            priority, reasons, action, priority_score, is_loaned_in, development_headroom, headroom_percentage = self._classify_removal_priority(
                row, best_skill, position_rank, total_at_position,
                squad_avg_ca, release_cost
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
                "is_loaned_in": is_loaned_in,
                "priority": priority,
                "priority_score": priority_score,
                "reasons": reasons,
                "recommended_action": action,
                # Development potential fields
                "development_headroom": int(development_headroom),
                "headroom_percentage": round(headroom_percentage, 1),
                # Hidden attributes for display
                "consistency": int(row.get('Consistency', 0)) if pd.notna(row.get('Consistency')) else None,
                "important_matches": int(row.get('Important Matches', 0)) if pd.notna(row.get('Important Matches')) else None,
                "injury_proneness": int(row.get('Injury Proneness', 0)) if pd.notna(row.get('Injury Proneness')) else None,
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
