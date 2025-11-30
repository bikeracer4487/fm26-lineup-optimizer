#!/usr/bin/env python3
"""
Football Manager Rotation Squad Selector
Selects optimal First XI and Rotation XI for squad rotation and cup matches
"""

import pandas as pd
import numpy as np
from scipy.optimize import linear_sum_assignment
from typing import Dict, List, Tuple

class RotationSelector:
    def __init__(self, filepath: str):
        """
        Initialize the rotation selector with player data
        
        Args:
            filepath: Path to the Excel or CSV file containing player data
        """
        # Read the spreadsheet
        if filepath.endswith('.csv'):
            self.df = pd.read_csv(filepath)
        else:
            self.df = pd.read_excel(filepath)
        
        # Ensure numeric columns are properly typed
        numeric_columns = ['Striker', 'AM(L)', 'AM(C)', 'AM(R)', 
                          'DM(L)', 'DM(R)', 'D(C)', 'D(R/L)', 'GK']
        for col in numeric_columns:
            if col in self.df.columns:
                self.df[col] = pd.to_numeric(self.df[col], errors='coerce')
        
        self.first_xi = {}
        self.rotation_xi = {}
    
    def select_optimal_xi(self, formation: List[Tuple[str, str]], 
                         exclude_players: set = None) -> Dict[str, Tuple[str, float]]:
        """
        Select optimal XI using Hungarian algorithm, optionally excluding certain players
        
        Args:
            formation: List of tuples (position_name, column_name)
            exclude_players: Set of player names to exclude from selection
        
        Returns:
            Dictionary mapping position names to (player_name, rating) tuples
        """
        # Filter out excluded players
        if exclude_players:
            available_df = self.df[~self.df['Name'].isin(exclude_players)].copy()
        else:
            available_df = self.df.copy()
        
        if available_df.empty:
            return {}
        
        # Reset index for the available dataframe
        available_df = available_df.reset_index(drop=True)
        
        # Create position columns list
        position_columns = [col for _, col in formation]
        position_names = [name for name, _ in formation]
        
        # Create a cost matrix (negative because we want to maximize ratings)
        n_positions = len(formation)
        n_players = len(available_df)
        
        # Initialize with very low values
        cost_matrix = np.full((n_players, n_positions), -999.0)
        
        # Fill in actual ratings
        for i in range(n_players):
            for j, (pos_name, col_name) in enumerate(formation):
                rating = available_df.loc[i, col_name]
                if pd.notna(rating):
                    cost_matrix[i, j] = -rating
        
        # Solve the assignment problem
        row_indices, col_indices = linear_sum_assignment(cost_matrix)
        
        # Build the XI from the optimal assignment
        selected_xi = {}
        for player_idx, pos_idx in zip(row_indices, col_indices):
            if player_idx < n_players and pos_idx < n_positions:
                pos_name, col_name = formation[pos_idx]
                player_name = available_df.loc[player_idx, 'Name']
                rating = available_df.loc[player_idx, col_name]
                
                if pd.notna(rating) and rating > 0:
                    selected_xi[pos_name] = (player_name, rating)
        
        return selected_xi
    
    def select_both_squads(self, formation: List[Tuple[str, str]]) -> Tuple[Dict, Dict]:
        """
        Select both First XI and Rotation XI
        
        Args:
            formation: List of tuples (position_name, column_name)
        
        Returns:
            Tuple of (first_xi, rotation_xi) dictionaries
        """
        # Select First XI
        print("Selecting First XI...")
        self.first_xi = self.select_optimal_xi(formation)
        
        # Get players in First XI
        first_xi_players = set(player for player, _ in self.first_xi.values() if player)
        
        # Select Rotation XI (excluding First XI players)
        print("Selecting Rotation XI...")
        self.rotation_xi = self.select_optimal_xi(formation, exclude_players=first_xi_players)
        
        return self.first_xi, self.rotation_xi
    
    def print_both_squads(self, show_natural_position: bool = True):
        """
        Print both squads side by side
        
        Args:
            show_natural_position: Whether to show player's natural position
        """
        print("\n" + "="*120)
        print(f"{'FIRST XI (Starting Lineup)':^60}{'ROTATION XI (Backup Squad)':^60}")
        print("="*120)
        
        # Define formation structure for display
        formation_display = {
            'Attack': ['STC'],
            'Attacking Midfield': ['AML', 'AMC', 'AMR'],
            'Defensive Midfield': ['DM1', 'DM2'],
            'Defense': ['DL', 'DC1', 'DC2', 'DR'],
            'Goalkeeper': ['GK']
        }
        
        first_total = 0
        rotation_total = 0
        
        for section, positions in formation_display.items():
            print(f"\n{section}:")
            print("-" * 120)
            
            for pos in positions:
                # First XI
                first_player = first_rating = ""
                if pos in self.first_xi:
                    player, rating = self.first_xi[pos]
                    if player:
                        natural_pos = ""
                        if show_natural_position:
                            player_row = self.df[self.df['Name'] == player]
                            if not player_row.empty:
                                natural_pos = f" [{player_row.iloc[0]['Best Position']}]"
                        first_player = f"{player:20s}{natural_pos:10s}"
                        first_rating = f"({rating:.1f})"
                        first_total += rating
                
                # Rotation XI
                rotation_player = rotation_rating = ""
                if pos in self.rotation_xi:
                    player, rating = self.rotation_xi[pos]
                    if player:
                        natural_pos = ""
                        if show_natural_position:
                            player_row = self.df[self.df['Name'] == player]
                            if not player_row.empty:
                                natural_pos = f" [{player_row.iloc[0]['Best Position']}]"
                        rotation_player = f"{player:20s}{natural_pos:10s}"
                        rotation_rating = f"({rating:.1f})"
                        rotation_total += rating
                
                print(f"  {pos:6s}: {first_player:32s} {first_rating:8s} | "
                      f"{pos:6s}: {rotation_player:32s} {rotation_rating:8s}")
        
        print("\n" + "="*120)
        first_avg = first_total / 11 if self.first_xi else 0
        rotation_avg = rotation_total / 11 if self.rotation_xi else 0
        
        print(f"{'Total: ' + f'{first_total:.2f}':^60}{'Total: ' + f'{rotation_total:.2f}':^60}")
        print(f"{'Average: ' + f'{first_avg:.2f}':^60}{'Average: ' + f'{rotation_avg:.2f}':^60}")
        print(f"{' ':^60}{'Difference: ' + f'{first_avg - rotation_avg:.2f}':^60}")
        print("="*120 + "\n")
    
    def export_both_squads(self, first_output: str = 'first_xi.csv', 
                          rotation_output: str = 'rotation_xi.csv'):
        """
        Export both squads to CSV files
        
        Args:
            first_output: Filename for First XI
            rotation_output: Filename for Rotation XI
        """
        def create_squad_data(squad_dict):
            data = []
            for position, (player, rating) in squad_dict.items():
                player_row = self.df[self.df['Name'] == player]
                if not player_row.empty:
                    age = player_row.iloc[0]['Age']
                    ca = player_row.iloc[0]['CA']
                    pa = player_row.iloc[0]['PA']
                    natural_pos = player_row.iloc[0]['Best Position']
                else:
                    age = ca = pa = natural_pos = 'N/A'
                
                data.append({
                    'Position': position,
                    'Player': player,
                    'Rating': rating,
                    'Natural Position': natural_pos,
                    'Age': age,
                    'CA': ca,
                    'PA': pa
                })
            return pd.DataFrame(data)
        
        # Export First XI
        first_df = create_squad_data(self.first_xi)
        first_df.to_csv(first_output, index=False)
        print(f"First XI exported to {first_output}")
        
        # Export Rotation XI
        rotation_df = create_squad_data(self.rotation_xi)
        rotation_df.to_csv(rotation_output, index=False)
        print(f"Rotation XI exported to {rotation_output}")
    
    def compare_depth_by_position(self):
        """
        Show squad depth comparison for each position
        """
        print("\nSQUAD DEPTH ANALYSIS:")
        print("="*100)
        
        formation_display = {
            'Attack': ['STC'],
            'Attacking Midfield': ['AML', 'AMC', 'AMR'],
            'Defensive Midfield': ['DM1', 'DM2'],
            'Defense': ['DL', 'DC1', 'DC2', 'DR'],
            'Goalkeeper': ['GK']
        }
        
        for section, positions in formation_display.items():
            print(f"\n{section}:")
            for pos in positions:
                first_rating = 0
                rotation_rating = 0
                
                if pos in self.first_xi:
                    _, first_rating = self.first_xi[pos]
                if pos in self.rotation_xi:
                    _, rotation_rating = self.rotation_xi[pos]
                
                if first_rating > 0 and rotation_rating > 0:
                    difference = first_rating - rotation_rating
                    percentage = (rotation_rating / first_rating) * 100
                    
                    # Visual representation
                    bars = int(percentage / 5)  # 20 bars = 100%
                    bar_graph = "█" * bars + "░" * (20 - bars)
                    
                    status = "✓ Strong" if difference < 5 else "⚠ Significant drop" if difference < 10 else "✗ Weak"
                    
                    print(f"  {pos:6s}: {first_rating:5.1f} → {rotation_rating:5.1f} "
                          f"({difference:+5.1f}) [{bar_graph}] {percentage:5.1f}% {status}")
        
        print("="*100 + "\n")
    
    def suggest_additional_subs(self, n_subs: int = 5) -> pd.DataFrame:
        """
        Suggest additional substitutes beyond the rotation XI
        
        Args:
            n_subs: Number of additional subs to suggest
            
        Returns:
            DataFrame with substitute suggestions
        """
        # Get all selected players (First XI + Rotation XI)
        all_selected = set()
        all_selected.update(player for player, _ in self.first_xi.values() if player)
        all_selected.update(player for player, _ in self.rotation_xi.values() if player)
        
        # Filter available players
        available = self.df[~self.df['Name'].isin(all_selected)].copy()
        
        if available.empty:
            return pd.DataFrame()
        
        # Calculate average rating
        position_cols = ['Striker', 'AM(L)', 'AM(C)', 'AM(R)', 
                        'DM(L)', 'DM(R)', 'D(C)', 'D(R/L)', 'GK']
        available['avg_rating'] = available[position_cols].mean(axis=1, skipna=True)
        
        # Sort and take top N
        subs = available.nlargest(n_subs, 'avg_rating')[
            ['Name', 'Best Position', 'Age', 'CA', 'PA', 'avg_rating']
        ]
        
        return subs


def main():
    """
    Main function to run the rotation squad selector
    """
    import sys
    
    # Get file path from command line or use default
    if len(sys.argv) > 1:
        filepath = sys.argv[1]
    else:
        filepath = 'players-current.csv'
    
    try:
        # Initialize selector
        selector = RotationSelector(filepath)
        
        # Define formation
        formation = [
            ('GK', 'GK'),
            ('DL', 'D(R/L)'),
            ('DC1', 'D(C)'),
            ('DC2', 'D(C)'),
            ('DR', 'D(R/L)'),
            ('DM1', 'DM(L)'),
            ('DM2', 'DM(R)'),
            ('AML', 'AM(L)'),
            ('AMC', 'AM(C)'),
            ('AMR', 'AM(R)'),
            ('STC', 'Striker')
        ]
        
        # Select both squads
        selector.select_both_squads(formation)
        
        # Display results
        selector.print_both_squads(show_natural_position=True)
        
        # Show depth analysis
        selector.compare_depth_by_position()
        
        # Show additional subs
        print("\nADDITIONAL SUBSTITUTES (Beyond Rotation XI):")
        print("="*70)
        subs = selector.suggest_additional_subs(n_subs=5)
        if not subs.empty:
            for idx, row in subs.iterrows():
                print(f"  {row['Name']:20s} [{row['Best Position']:6s}] "
                      f"Age: {row['Age']:2.0f}  CA: {row['CA']:3.0f}  Avg: {row['avg_rating']:.1f}")
        else:
            print("  No additional players available")
        print("="*70 + "\n")
        
        # Export both squads
        selector.export_both_squads('first_xi.csv', 'rotation_xi.csv')
        
    except FileNotFoundError:
        print(f"Error: Could not find file '{filepath}'")
        print("\nUsage: python fm_rotation_selector.py [path_to_spreadsheet]")
        print("Supported formats: .xlsx, .csv")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
