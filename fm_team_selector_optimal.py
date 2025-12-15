#!/usr/bin/env python3
"""
Football Manager Optimal Starting XI Selector - Optimized Version
Uses the Hungarian algorithm to find the truly optimal player-position assignment
"""

import pandas as pd
import numpy as np
from scipy.optimize import linear_sum_assignment
from typing import Dict, List, Tuple
from unidecode import unidecode


def normalize_name(name):
    """Normalize player names for consistent string comparison.

    Uses ASCII transliteration to handle accented characters (e.g., Jose -> Jose).
    """
    if not name:
        return ''
    return unidecode(str(name)).lower().strip()

class OptimalTeamSelector:
    def __init__(self, filepath: str):
        """
        Initialize the team selector with player data from a spreadsheet
        
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

        # Add normalized name column for Unicode-safe comparisons
        self.df['Name_Normalized'] = self.df['Name'].apply(normalize_name)

        self.starting_xi = {}
    
    def select_optimal_xi(self, formation: List[Tuple[str, str]]) -> Dict[str, Tuple[str, float]]:
        """
        Select the truly optimal Starting XI using the Hungarian algorithm
        
        Args:
            formation: List of tuples (position_name, column_name)
        
        Returns:
            Dictionary mapping position names to (player_name, rating) tuples
        """
        # Create position columns list
        position_columns = [col for _, col in formation]
        position_names = [name for name, _ in formation]
        
        # Create a cost matrix (negative because we want to maximize ratings)
        # Rows = players, Columns = positions
        n_positions = len(formation)
        n_players = len(self.df)
        
        # Initialize with very low values (players can't play multiple positions)
        cost_matrix = np.full((n_players, n_positions), -999.0)
        
        # Fill in actual ratings
        for i, player_idx in enumerate(self.df.index):
            for j, (pos_name, col_name) in enumerate(formation):
                rating = self.df.loc[player_idx, col_name]
                if pd.notna(rating):
                    # Use negative rating because linear_sum_assignment minimizes cost
                    cost_matrix[i, j] = -rating
        
        # Solve the assignment problem
        row_indices, col_indices = linear_sum_assignment(cost_matrix)
        
        # Build the starting XI from the optimal assignment
        self.starting_xi = {}
        for player_idx, pos_idx in zip(row_indices, col_indices):
            if player_idx < n_players and pos_idx < n_positions:
                pos_name, col_name = formation[pos_idx]
                player_name = self.df.loc[player_idx, 'Name']
                rating = self.df.loc[player_idx, col_name]
                
                if pd.notna(rating) and rating > 0:
                    self.starting_xi[pos_name] = (player_name, rating)
        
        return self.starting_xi
    
    def print_starting_xi(self, show_ratings: bool = True, show_natural_position: bool = True):
        """
        Print the Starting XI in a readable format
        
        Args:
            show_ratings: Whether to display player ratings
            show_natural_position: Whether to show player's natural position
        """
        print("\n" + "="*70)
        print("OPTIMAL STARTING XI")
        print("="*70)
        
        # Define formation structure for display
        formation_display = {
            'Attack': ['STC'],
            'Attacking Midfield': ['AML', 'AMC', 'AMR'],
            'Defensive Midfield': ['DM1', 'DM2'],
            'Defense': ['DL', 'DC1', 'DC2', 'DR'],
            'Goalkeeper': ['GK']
        }
        
        total_rating = 0
        player_count = 0
        
        for section, positions in formation_display.items():
            print(f"\n{section}:")
            for pos in positions:
                if pos in self.starting_xi:
                    player, rating = self.starting_xi[pos]
                    if player:
                        # Get player's natural position
                        natural_pos = ""
                        if show_natural_position:
                            player_row = self.df[self.df['Name_Normalized'] == normalize_name(player)]
                            if not player_row.empty:
                                natural_pos = f" [{player_row.iloc[0]['Best Position']}]"
                        
                        if show_ratings:
                            print(f"  {pos:6s}: {player:20s}{natural_pos:10s} ({rating:.1f})")
                        else:
                            print(f"  {pos:6s}: {player}{natural_pos}")
                        
                        total_rating += rating
                        player_count += 1
                    else:
                        print(f"  {pos:6s}: NO PLAYER FOUND")
        
        print("\n" + "="*70)
        if player_count > 0:
            avg_rating = total_rating / player_count
            print(f"Total Team Rating: {total_rating:.2f}")
            print(f"Average Team Rating: {avg_rating:.2f}")
        print("="*70 + "\n")
    
    def export_to_csv(self, output_file: str = 'starting_xi.csv'):
        """
        Export the Starting XI to a CSV file
        
        Args:
            output_file: Path to the output CSV file
        """
        xi_data = []
        for position, (player, rating) in self.starting_xi.items():
            # Get additional player info
            player_row = self.df[self.df['Name_Normalized'] == normalize_name(player)]
            if not player_row.empty:
                age = player_row.iloc[0]['Age']
                ca = player_row.iloc[0]['CA']
                pa = player_row.iloc[0]['PA']
                natural_pos = player_row.iloc[0]['Best Position']
            else:
                age = ca = pa = natural_pos = 'N/A'
            
            xi_data.append({
                'Position': position,
                'Player': player if player else 'N/A',
                'Rating': rating if player else 0.0,
                'Natural Position': natural_pos,
                'Age': age,
                'CA': ca,
                'PA': pa
            })
        
        xi_df = pd.DataFrame(xi_data)
        xi_df.to_csv(output_file, index=False)
        print(f"Starting XI exported to {output_file}")
    
    def suggest_substitutes(self, n_subs: int = 7) -> pd.DataFrame:
        """
        Suggest the best substitutes from remaining players
        
        Args:
            n_subs: Number of substitutes to suggest
            
        Returns:
            DataFrame with substitute suggestions
        """
        # Get players already in starting XI
        selected_players = set(player for player, _ in self.starting_xi.values())
        
        # Filter out selected players
        available = self.df[~self.df['Name'].isin(selected_players)].copy()
        
        # Calculate average rating across all positions for each player
        position_cols = ['Striker', 'AM(L)', 'AM(C)', 'AM(R)', 
                        'DM(L)', 'DM(R)', 'D(C)', 'D(R/L)', 'GK']
        available['avg_rating'] = available[position_cols].mean(axis=1, skipna=True)
        
        # Sort by average rating and take top N
        subs = available.nlargest(n_subs, 'avg_rating')[
            ['Name', 'Best Position', 'Age', 'CA', 'PA', 'avg_rating']
        ]
        
        return subs


def main():
    """
    Main function to run the optimal team selector
    """
    import sys
    
    # Get file path from command line or use default
    if len(sys.argv) > 1:
        filepath = sys.argv[1]
    else:
        filepath = 'players-current.csv'  # Default filename
    
    try:
        # Initialize the selector
        print("Calculating optimal Starting XI...")
        selector = OptimalTeamSelector(filepath)
        
        # Define the formation
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
        
        # Select the optimal Starting XI using Hungarian algorithm
        selector.select_optimal_xi(formation)
        
        # Display the results
        selector.print_starting_xi(show_ratings=True, show_natural_position=True)
        
        # Show suggested substitutes
        print("\nSUGGESTED SUBSTITUTES:")
        print("="*70)
        subs = selector.suggest_substitutes(n_subs=7)
        for idx, row in subs.iterrows():
            print(f"  {row['Name']:20s} [{row['Best Position']:6s}] "
                  f"CA: {row['CA']:3.0f}  Avg: {row['avg_rating']:.1f}")
        print("="*70 + "\n")
        
        # Export to CSV
        selector.export_to_csv('starting_xi.csv')
        
    except FileNotFoundError:
        print(f"Error: Could not find file '{filepath}'")
        print("\nUsage: python fm_team_selector_optimal.py [path_to_spreadsheet]")
        print("Supported formats: .xlsx, .csv")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
