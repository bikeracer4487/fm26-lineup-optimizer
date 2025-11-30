#!/usr/bin/env python3
"""
Football Manager Optimal Starting XI Selector
Automatically selects the best Starting XI based on position-specific ratings
"""

import pandas as pd
from typing import Dict, List, Tuple, Optional

class TeamSelector:
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
        
        self.selected_players = set()
        self.starting_xi = {}
    
    def get_best_player(self, position_column: str, position_name: str, 
                       exclude_players: set = None) -> Optional[Tuple[str, float]]:
        """
        Get the best available player for a specific position
        
        Args:
            position_column: Column name to evaluate (e.g., 'GK', 'D(C)')
            position_name: Display name for the position (e.g., 'GK', 'DC1')
            exclude_players: Set of player names already selected
            
        Returns:
            Tuple of (player_name, rating) or None if no player available
        """
        if exclude_players is None:
            exclude_players = set()
        
        # Filter out already selected players
        available_players = self.df[~self.df['Name'].isin(exclude_players)]
        
        if available_players.empty or position_column not in available_players.columns:
            return None
        
        # Remove players with NaN ratings for this position
        available_players = available_players.dropna(subset=[position_column])
        
        if available_players.empty:
            return None
        
        # Get the player with the highest rating
        best_player_idx = available_players[position_column].idxmax()
        best_player = available_players.loc[best_player_idx]
        
        return (best_player['Name'], best_player[position_column])
    
    def select_starting_xi(self, formation: List[Tuple[str, str]]) -> Dict[str, Tuple[str, float]]:
        """
        Select the optimal Starting XI based on the formation
        
        Args:
            formation: List of tuples (position_name, column_name)
                      e.g., [('GK', 'GK'), ('DL', 'D(R/L)'), ...]
        
        Returns:
            Dictionary mapping position names to (player_name, rating) tuples
        """
        self.starting_xi = {}
        self.selected_players = set()
        
        for position_name, column_name in formation:
            result = self.get_best_player(column_name, position_name, self.selected_players)
            
            if result:
                player_name, rating = result
                self.starting_xi[position_name] = (player_name, rating)
                self.selected_players.add(player_name)
            else:
                self.starting_xi[position_name] = (None, 0.0)
                print(f"Warning: Could not find player for {position_name}")
        
        return self.starting_xi
    
    def print_starting_xi(self, show_ratings: bool = True):
        """
        Print the Starting XI in a readable format
        
        Args:
            show_ratings: Whether to display player ratings
        """
        print("\n" + "="*60)
        print("OPTIMAL STARTING XI")
        print("="*60)
        
        # Define formation structure for display
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
                if pos in self.starting_xi:
                    player, rating = self.starting_xi[pos]
                    if player:
                        if show_ratings:
                            print(f"  {pos:6s}: {player:20s} ({rating:.1f})")
                        else:
                            print(f"  {pos:6s}: {player}")
                    else:
                        print(f"  {pos:6s}: NO PLAYER FOUND")
        
        print("\n" + "="*60)
        
        # Calculate average rating
        ratings = [rating for _, rating in self.starting_xi.values() if rating > 0]
        if ratings:
            avg_rating = sum(ratings) / len(ratings)
            print(f"Average Team Rating: {avg_rating:.2f}")
        print("="*60 + "\n")
    
    def export_to_csv(self, output_file: str = 'starting_xi.csv'):
        """
        Export the Starting XI to a CSV file
        
        Args:
            output_file: Path to the output CSV file
        """
        xi_data = []
        for position, (player, rating) in self.starting_xi.items():
            xi_data.append({
                'Position': position,
                'Player': player if player else 'N/A',
                'Rating': rating if player else 0.0
            })
        
        xi_df = pd.DataFrame(xi_data)
        xi_df.to_csv(output_file, index=False)
        print(f"Starting XI exported to {output_file}")


def main():
    """
    Main function to run the team selector
    """
    import sys
    
    # Get file path from command line or use default
    if len(sys.argv) > 1:
        filepath = sys.argv[1]
    else:
        filepath = 'players.xlsx'  # Default filename
    
    try:
        # Initialize the selector
        selector = TeamSelector(filepath)
        
        # Define the formation
        # Format: (position_display_name, column_name_in_spreadsheet)
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
        
        # Select the optimal Starting XI
        selector.select_starting_xi(formation)
        
        # Display the results
        selector.print_starting_xi(show_ratings=True)
        
        # Export to CSV
        selector.export_to_csv('starting_xi.csv')
        
    except FileNotFoundError:
        print(f"Error: Could not find file '{filepath}'")
        print("\nUsage: python fm_team_selector.py [path_to_spreadsheet]")
        print("Supported formats: .xlsx, .csv")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
