export interface Player {
  name: string;
  position: string;
  // Add other fields as needed from the CSV or API
}

export interface Match {
  id: string; // Generated UUID
  date: string; // YYYY-MM-DD
  opponent: string;
  importance: 'Low' | 'Medium' | 'High' | 'Sharpness';
  // Confirmation state
  confirmed?: boolean;
  confirmedAt?: string; // ISO timestamp
  // Manual overrides for this match only (position -> playerName)
  manualOverrides?: Record<string, string>;
}

export interface AppState {
  currentDate: string;
  matches: Match[];
  rejectedPlayers: Record<string, string[]>; // matchId (UUID) -> [playerNames] (per-match rejections)
  rejectedTraining: Record<string, string>; // playerName -> rejectedPosition
  files: {
    status: string;
    abilities: string;
  };
}

export interface MatchSelectionPlayer {
  name: string;
  rating: number;
  condition: number;
  fatigue: number;
  sharpness: number;
  age: number;
  status: string[];
}

export interface MatchSelection {
  GK: MatchSelectionPlayer;
  DL: MatchSelectionPlayer;
  DC1: MatchSelectionPlayer;
  DC2: MatchSelectionPlayer;
  DR: MatchSelectionPlayer;
  'DM(L)': MatchSelectionPlayer;
  'DM(R)': MatchSelectionPlayer;
  AML: MatchSelectionPlayer;
  AMC: MatchSelectionPlayer;
  AMR: MatchSelectionPlayer;
  STC: MatchSelectionPlayer;
  [key: string]: MatchSelectionPlayer;
}

export interface MatchPlanItem {
  matchIndex: number;
  matchId: string;  // Unique match ID for correlation with rejections
  date: string;
  importance: string;
  selection: MatchSelection;
}

export interface TrainingRecommendation {
  player: string;
  position: string;
  category: string;
  current_skill: string;
  current_skill_rating: number; // Added missing field
  ability_tier: string;
  ability_rating?: number; // Added missing field
  age: number;
  training_score: number;
  priority: string;
  priority_score: number;
  gap_severity: number;
  reason: string;
  
  // New fields
  strategic_category?: string;
  estimated_timeline?: string;
  is_universalist?: boolean;
  universalist_coverage?: number;
  fills_variety_gap?: boolean;
}

export interface RestRecommendation {
  name: string;
  fatigue: number;
  condition: number;
  sharpness: number;
  status: string;
  action: string;
  priority: string; // "Urgent", "High", "Medium", "Low"
  reasons: string[];
  threshold: number;
}

export interface TrainingResponse {
  success: boolean;
  recommendations?: TrainingRecommendation[];
  error?: string;
}

export interface RestResponse {
  success: boolean;
  recommendations?: RestRecommendation[];
  error?: string;
}

export interface MatchPlanResponse {
  success: boolean;
  plan?: MatchPlanItem[];
  error?: string;
}

// Confirmed lineup entry for history tracking
export interface ConfirmedLineup {
  matchId: string;
  date: string;
  opponent: string;
  importance: string;
  confirmedAt: string;
  selection: Record<string, string>; // position -> playerName (names only, not full player data)
}

// For player selection modal
export interface PlayerListItem {
  name: string;
  position: string; // Natural/best position
}

// Confirmed lineups file structure
export interface ConfirmedLineupsData {
  lineups: ConfirmedLineup[];
}
