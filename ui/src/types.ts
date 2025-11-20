export interface Player {
  name: string;
  position: string;
  // Add other fields as needed from the CSV or API
}

export interface Match {
  id: string; // Generated UUID or index
  date: string; // YYYY-MM-DD
  opponent: string;
  importance: 'Low' | 'Medium' | 'High';
}

export interface AppState {
  currentDate: string;
  matches: Match[];
  rejectedPlayers: Record<string, string[]>; // matchIndex -> [playerNames]
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
  date: string;
  importance: string;
  selection: MatchSelection;
}

export interface TrainingRecommendation {
  player: string;
  position: string;
  category: string;
  current_skill: string;
  ability_tier: string;
  age: number;
  training_score: number;
  priority: string;
  priority_score: number;
  gap_severity: number;
  reason: string;
}

export interface TrainingResponse {
  success: boolean;
  recommendations?: TrainingRecommendation[];
  error?: string;
}

export interface MatchPlanResponse {
  success: boolean;
  plan?: MatchPlanItem[];
  error?: string;
}

