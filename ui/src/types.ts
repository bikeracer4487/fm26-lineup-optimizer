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
  nameNormalized?: string;  // ASCII-normalized name for rejection matching (from backend)
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
  // New fatigue-focused fields
  recovery_days: number;           // Estimated days to recover to safe zone
  recovery_method: string;         // "vacation", "rest", "rotation", "monitor"
  fatigue_percentage: number;      // Fatigue as percentage of personal threshold
  warning_threshold: number;       // 80% of personal threshold
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

// Player removal recommendation
export interface PlayerRemovalRecommendation {
  name: string;
  age: number;
  positions: string;
  ca: number;
  pa: number;
  squad_avg_ca: number;
  best_skill: number;
  skill_position: string;
  position_rank: number;
  total_at_position: number;
  contract_type: string;
  wages_weekly: number;
  months_remaining: number;
  asking_price: number;
  release_cost: number;
  mutual_termination_cost: number;
  loan_status: string;
  is_loaned_in: boolean;
  priority: string; // "Critical", "High", "Medium", "Low" for owned; "End Early", "Monitor", "Keep" for loans
  priority_score: number;
  reasons: string[];
  recommended_action: string;
  // Development potential
  development_headroom: number;
  headroom_percentage: number;
  // Hidden attributes (existing)
  consistency: number | null;
  important_matches: number | null;
  injury_proneness: number | null;
  // NEW: Additional hidden attributes and analysis from retention strategy research
  required_growth_velocity: number | null; // CA/year needed to reach PA by age 24
  position_role: string; // 'goalkeeper', 'defender', 'playmaker', 'attacker', 'general'
  is_mentor_candidate: boolean; // Veterans with high Pro/Det suitable for mentoring
  ambition: number | null;
  controversy: number | null;
  temperament: number | null;
  determination: number | null;
  professional: number | null;
  // Hierarchy-based analysis (Starting XI / Second XI rankings)
  hierarchy_tier: number; // 1 = Starting XI, 2 = Second XI, 3 = Backup
  hierarchy_positions: Record<string, number>; // Position -> tier mapping for positions where player is Tier 1 or 2
}

export interface PlayerRemovalResponse {
  success: boolean;
  recommendations?: PlayerRemovalRecommendation[];
  error?: string;
}
