import { useState, useEffect, useMemo } from 'react';
import type { AppState, MatchPlanItem, MatchSelectionPlayer, Match, ConfirmedLineup } from '../types';
import { api } from '../api';
import { Button, Badge } from '../components/UI';
import { RefreshCw, UserX, AlertTriangle, Activity, Battery, Zap, ChevronDown, ChevronRight, Calendar, Edit3, RotateCcw, CheckCircle, Lock, Unlock } from 'lucide-react';
import { motion } from 'framer-motion';
import { PlayerSelectModal } from '../components/PlayerSelectModal';
import { ConfirmDialog } from '../components/ConfirmDialog';

// Maximum number of matches to calculate lineups for
const MAX_LINEUP_MATCHES = 5;

// Helper to normalize player names for comparison (handles Unicode accents)
const normalizePlayerName = (name: string): string => {
  // Remove accents by decomposing and stripping combining characters
  return name.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
};

interface MatchSelectionTabProps {
  state: AppState;
  onRejectPlayer: (matchIndex: string, players: string[]) => void;
  onResetRejections: () => void;
  onConfirmMatch: (matchId: string) => void;
  onUndoConfirmation: (matchId: string) => void;
  onUpdateManualOverrides: (matchId: string, overrides: Record<string, string>) => void;
  onClearManualOverrides: (matchId: string) => void;
}

export function MatchSelectionTab({
  state,
  onRejectPlayer,
  onResetRejections,
  onConfirmMatch,
  onUndoConfirmation,
  onUpdateManualOverrides,
  onClearManualOverrides
}: MatchSelectionTabProps) {
  const [plan, setPlan] = useState<MatchPlanItem[] | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showPast, setShowPast] = useState(false);
  const [showFuture, setShowFuture] = useState(false);

  // Override modal state
  const [overrideModal, setOverrideModal] = useState<{
    isOpen: boolean;
    matchId: string;
    position: string;
    excludedPlayers: string[];
    playersInPositions: Record<string, string>;  // playerName -> position (for visual indicator)
  }>({ isOpen: false, matchId: '', position: '', excludedPlayers: [], playersInPositions: {} });

  // Confirm dialog state
  const [confirmDialog, setConfirmDialog] = useState<{
    isOpen: boolean;
    matchId: string;
    opponent: string;
    date: string;
    action: 'confirm' | 'undo';
  }>({ isOpen: false, matchId: '', opponent: '', date: '', action: 'confirm' });

  // Confirmed lineups from storage (for displaying confirmed matches)
  const [confirmedLineups, setConfirmedLineups] = useState<ConfirmedLineup[]>([]);

  // Load confirmed lineups on mount and when matches change
  useEffect(() => {
    const loadConfirmedLineups = async () => {
      try {
        const data = await api.getConfirmedLineups();
        setConfirmedLineups(data.lineups || []);
      } catch (err) {
        console.error('Failed to load confirmed lineups:', err);
      }
    };
    loadConfirmedLineups();
  }, [state.matches]);

  // Categorize matches: past, next 5, and future (6+)
  const { upcomingMatches, futureMatches, pastMatches, matchesForBackend } = useMemo(() => {
    const sorted = [...state.matches].sort((a, b) => a.date.localeCompare(b.date));
    const upcoming = sorted.filter(m => m.date >= state.currentDate);
    const past = sorted.filter(m => m.date < state.currentDate).reverse();

    // Only first 5 upcoming get lineups calculated
    const forBackend = upcoming.slice(0, MAX_LINEUP_MATCHES);
    // Matches 6+ shown as display-only
    const future = upcoming.slice(MAX_LINEUP_MATCHES);

    return {
      upcomingMatches: forBackend,
      futureMatches: future,
      pastMatches: past,
      matchesForBackend: forBackend
    };
  }, [state.matches, state.currentDate]);

  const generatePlan = async () => {
    if (matchesForBackend.length === 0) {
      setError("No upcoming matches to generate lineups for.");
      return;
    }

    setLoading(true);
    setError(null);

    try {
      // Only send the first 5 upcoming matches, excluding confirmed ones
      const unconfirmedMatches = matchesForBackend.filter(m => !m.confirmed);

      if (unconfirmedMatches.length === 0) {
        // All matches are confirmed, no need to call backend
        setLoading(false);
        return;
      }

      const response = await api.runMatchSelector(
        unconfirmedMatches,
        state.rejectedPlayers,
        state.files
      );

      if (response.success && response.plan) {
        setPlan(response.plan);
      } else {
        setError(response.error || "Failed to generate plan");
      }
    } catch (err) {
      setError(String(err));
    } finally {
      setLoading(false);
    }
  };

  // Auto-run when dependencies change
  useEffect(() => {
    if (matchesForBackend.length > 0) {
      const timer = setTimeout(generatePlan, 100);
      return () => clearTimeout(timer);
    }
  }, [state.matches, state.rejectedPlayers, state.files, state.currentDate]);

  const handleReject = (matchId: string, playerName: string, nameNormalized?: string) => {
    const currentRejected = state.rejectedPlayers[matchId] || [];
    // Use the backend-provided normalized name if available, otherwise fall back to frontend normalization
    const normalizedName = nameNormalized || normalizePlayerName(playerName);
    const alreadyRejected = currentRejected.some(
      r => normalizePlayerName(r) === normalizedName
    );
    if (!alreadyRejected) {
      // Store the normalized name to ensure consistent matching with backend
      // This prevents encoding mismatches between app_state.json and CSV data
      onRejectPlayer(matchId, [...currentRejected, normalizedName]);
    }
  };

  // Handle override modal
  const openOverrideModal = (matchId: string, position: string, currentSelection: Record<string, MatchSelectionPlayer>, manualOverrides?: Record<string, string>) => {
    // Only exclude rejected players (truly unavailable)
    const rejectedPlayers = state.rejectedPlayers[matchId] || [];

    // Build map of players already in positions (for visual indicator)
    // Include both auto-selected and manually overridden players
    const playersInPositions: Record<string, string> = {}; // playerName -> position

    // Add auto-selected players
    for (const [pos, player] of Object.entries(currentSelection)) {
      if (player && pos !== position) {
        playersInPositions[player.name] = pos;
      }
    }

    // Add/override with manually overridden players
    if (manualOverrides) {
      for (const [pos, playerName] of Object.entries(manualOverrides)) {
        if (pos !== position) {
          playersInPositions[playerName] = pos;
        }
      }
    }

    setOverrideModal({
      isOpen: true,
      matchId,
      position,
      excludedPlayers: rejectedPlayers,
      playersInPositions
    });
  };

  const handleOverrideSelect = (playerName: string) => {
    const match = state.matches.find(m => m.id === overrideModal.matchId);
    if (match) {
      const currentOverrides = { ...(match.manualOverrides || {}) };

      // If this player is already overriding another position, remove that override
      for (const [pos, name] of Object.entries(currentOverrides)) {
        if (name === playerName && pos !== overrideModal.position) {
          delete currentOverrides[pos];
          break; // A player can only be in one position, so we can stop after finding them
        }
      }

      // Add the new override
      currentOverrides[overrideModal.position] = playerName;

      onUpdateManualOverrides(match.id, currentOverrides);
    }
    setOverrideModal({ ...overrideModal, isOpen: false });
  };

  const handleClearOverride = (matchId: string, position: string) => {
    const match = state.matches.find(m => m.id === matchId);
    if (match && match.manualOverrides) {
      const newOverrides = { ...match.manualOverrides };
      delete newOverrides[position];
      if (Object.keys(newOverrides).length === 0) {
        onClearManualOverrides(matchId);
      } else {
        onUpdateManualOverrides(matchId, newOverrides);
      }
    }
  };

  // Handle confirm dialog
  const openConfirmDialog = (matchId: string, opponent: string, date: string, action: 'confirm' | 'undo') => {
    setConfirmDialog({ isOpen: true, matchId, opponent, date, action });
  };

  // Helper to reload confirmed lineups from storage
  const reloadConfirmedLineups = async () => {
    try {
      const data = await api.getConfirmedLineups();
      setConfirmedLineups(data.lineups || []);
    } catch (err) {
      console.error('Failed to reload confirmed lineups:', err);
    }
  };

  const handleConfirmAction = async () => {
    if (confirmDialog.action === 'confirm') {
      // Get the plan item for this match
      const match = state.matches.find(m => m.id === confirmDialog.matchId);
      const planItem = plan?.find(p => p.date === match?.date);

      if (match && planItem) {
        // Save confirmed lineup to history
        const confirmedLineup: ConfirmedLineup = {
          matchId: match.id,
          date: match.date,
          opponent: match.opponent,
          importance: match.importance,
          confirmedAt: new Date().toISOString(),
          selection: Object.entries(planItem.selection).reduce((acc, [pos, player]) => {
            if (player) acc[pos] = player.name;
            return acc;
          }, {} as Record<string, string>)
        };

        await api.saveConfirmedLineup(confirmedLineup);
      }

      onConfirmMatch(confirmDialog.matchId);
    } else {
      // Undo confirmation: remove from history and clear confirmed flag
      await api.removeConfirmedLineup(confirmDialog.matchId);
      onUndoConfirmation(confirmDialog.matchId);
    }

    // Refresh confirmed lineups state after confirm/unlock
    await reloadConfirmedLineups();

    setConfirmDialog({ ...confirmDialog, isOpen: false });
  };

  // Sort plan items by date
  const sortedPlan = plan
    ? [...plan].sort((a, b) => {
        if (a.date && b.date) {
          const compare = a.date.localeCompare(b.date);
          if (compare !== 0) return compare;
        } else if (a.date) {
          return -1;
        } else if (b.date) {
          return 1;
        }
        return a.matchIndex - b.matchIndex;
      })
    : [];

  // Filter plan items based on current date (these are lineup results from backend)
  const backendPlanItems = sortedPlan.filter(item => item.date >= state.currentDate);

  // Create plan items for confirmed matches from stored lineups
  const confirmedPlanItems = useMemo(() => {
    // Get confirmed matches that are upcoming (within first 5)
    const upcomingConfirmedMatches = upcomingMatches
      .filter(m => m.confirmed)
      .slice(0, MAX_LINEUP_MATCHES);

    return upcomingConfirmedMatches.map(match => {
      // Find the saved lineup for this match
      const savedLineup = confirmedLineups.find(l => l.matchId === match.id);

      // Convert saved selection (player names only) to MatchSelectionPlayer objects
      // Create a partial selection object
      const selection: Partial<Record<string, MatchSelectionPlayer>> = {};
      if (savedLineup?.selection) {
        Object.entries(savedLineup.selection).forEach(([position, playerName]) => {
          selection[position] = {
            name: playerName,
            rating: 0,      // Placeholder - stats hidden for confirmed
            condition: 1,   // Placeholder
            sharpness: 1,   // Placeholder
            fatigue: 0,     // Placeholder
            age: 0,         // Placeholder
            status: []      // Empty statuses
          };
        });
      }

      return {
        matchIndex: 0, // Not used for display
        matchId: match.id,
        date: match.date,
        importance: match.importance,
        selection: selection as MatchPlanItem['selection']
      } as MatchPlanItem;
    });
  }, [upcomingMatches, confirmedLineups]);

  // Merge backend results with confirmed lineups (avoid duplicates by matchId/date)
  const upcomingPlanItems = useMemo(() => {
    const backendDates = new Set(backendPlanItems.map(item => item.date));
    const backendMatchIds = new Set(backendPlanItems.map(item => item.matchId));

    // Add confirmed items that aren't already in backend results
    const additionalConfirmed = confirmedPlanItems.filter(
      item => !backendDates.has(item.date) && !backendMatchIds.has(item.matchId)
    );

    // Combine and sort by date
    return [...backendPlanItems, ...additionalConfirmed].sort((a, b) =>
      a.date.localeCompare(b.date)
    );
  }, [backendPlanItems, confirmedPlanItems]);

  // Find match data by date for display purposes
  const getMatchByDate = (date: string): Match | undefined => {
    return state.matches.find(m => m.date === date);
  };

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-white">Match Selection</h2>
        <div className="flex gap-2">
          <Button variant="secondary" size="sm" onClick={onResetRejections} title="Clear all manual rejections">
            Reset Rejections
          </Button>
          <Button onClick={generatePlan} disabled={loading} size="sm" className="flex items-center whitespace-nowrap">
            <RefreshCw size={16} className={loading ? "animate-spin mr-2" : "mr-2"} />
            Refresh
          </Button>
        </div>
      </div>

      {error && (
        <div className="bg-fm-danger/10 border border-fm-danger text-fm-danger p-4 rounded-md flex items-center gap-2">
          <AlertTriangle size={20} />
          {error}
        </div>
      )}

      {loading && !plan && (
        <div className="flex justify-center py-20">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-fm-teal"></div>
        </div>
      )}

      <div className="space-y-8">
        {/* Upcoming matches with lineups (first 5) */}
        {upcomingPlanItems.length > 0 && (
          <div className="space-y-8">
            {upcomingPlanItems.map((item) => {
              const match = getMatchByDate(item.date);
              return (
                <MatchCard
                  key={item.matchId || item.matchIndex}
                  item={item}
                  match={match}
                  onReject={(name, nameNormalized) => handleReject(item.matchId, name, nameNormalized)}
                  onOverride={(pos) => match && openOverrideModal(match.id, pos, item.selection, match.manualOverrides)}
                  onClearOverride={(pos) => match && handleClearOverride(match.id, pos)}
                  onConfirm={() => match && openConfirmDialog(match.id, match.opponent, match.date, 'confirm')}
                  onUndoConfirm={() => match && openConfirmDialog(match.id, match.opponent, match.date, 'undo')}
                  onClearAllOverrides={() => match && onClearManualOverrides(match.id)}
                />
              );
            })}
          </div>
        )}

        {/* Future matches (6+) - display only, no lineup calculation */}
        {futureMatches.length > 0 && (
          <div className="pt-6 border-t border-white/5">
            <button
              onClick={() => setShowFuture(!showFuture)}
              className="flex items-center gap-2 text-fm-light/50 hover:text-white transition-colors text-sm font-bold uppercase tracking-wider mb-4 w-full text-left"
            >
              {showFuture ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
              <Calendar size={16} />
              Future Fixtures ({futureMatches.length})
            </button>

            {showFuture && (
              <div className="space-y-2">
                {futureMatches.map((match) => (
                  <FutureMatchCard key={match.id} match={match} />
                ))}
              </div>
            )}
          </div>
        )}

        {/* Past matches archive */}
        {pastMatches.length > 0 && (
          <div className="pt-6 border-t border-white/5">
            <button
              onClick={() => setShowPast(!showPast)}
              className="flex items-center gap-2 text-fm-light/50 hover:text-white transition-colors text-sm font-bold uppercase tracking-wider mb-4 w-full text-left"
            >
              {showPast ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
              Past Matches Archive ({pastMatches.length})
            </button>

            {showPast && (
              <div className="space-y-2 opacity-75">
                {pastMatches.map((match) => (
                  <PastMatchCard key={match.id} match={match} />
                ))}
              </div>
            )}
          </div>
        )}

        {!loading && (!plan || plan.length === 0) && upcomingMatches.length === 0 && !error && (
          <div className="text-center text-fm-light/50 py-12">
            Add matches to the fixture list to generate a plan.
          </div>
        )}
      </div>

      {/* Override Modal */}
      <PlayerSelectModal
        isOpen={overrideModal.isOpen}
        onClose={() => setOverrideModal({ ...overrideModal, isOpen: false })}
        onSelect={handleOverrideSelect}
        position={overrideModal.position}
        excludedPlayers={overrideModal.excludedPlayers}
        playersInPositions={overrideModal.playersInPositions}
        statusFile={state.files.status}
      />

      {/* Confirm Dialog */}
      <ConfirmDialog
        isOpen={confirmDialog.isOpen}
        onClose={() => setConfirmDialog({ ...confirmDialog, isOpen: false })}
        onConfirm={handleConfirmAction}
        title={confirmDialog.action === 'confirm' ? 'Confirm Lineup' : 'Undo Confirmation'}
        message={
          confirmDialog.action === 'confirm'
            ? `Lock the lineup for ${confirmDialog.opponent} on ${confirmDialog.date}? This will prevent automatic recalculation.`
            : `Unlock the lineup for ${confirmDialog.opponent} on ${confirmDialog.date}? This will allow automatic recalculation.`
        }
        confirmText={confirmDialog.action === 'confirm' ? 'Lock Lineup' : 'Unlock'}
        variant={confirmDialog.action === 'confirm' ? 'success' : 'warning'}
      />
    </div>
  );
}

interface MatchCardProps {
  item: MatchPlanItem;
  match?: Match;
  onReject: (name: string, nameNormalized?: string) => void;
  onOverride: (position: string) => void;
  onClearOverride: (position: string) => void;
  onConfirm: () => void;
  onUndoConfirm: () => void;
  onClearAllOverrides: () => void;
}

function MatchCard({ item, match, onReject, onOverride, onClearOverride, onConfirm, onUndoConfirm, onClearAllOverrides }: MatchCardProps) {
  const positions = [
    'GK',
    'DR', 'DC1', 'DC2', 'DL',
    'DM(R)', 'DM(L)',
    'AMR', 'AMC', 'AML',
    'STC'
  ];

  const opponent = match?.opponent || 'Unknown';
  const isConfirmed = match?.confirmed || false;
  const manualOverrides = match?.manualOverrides || {};
  const hasOverrides = Object.keys(manualOverrides).length > 0;

  // Helper to find player in selection by position key
  const getPlayer = (pos: string) => item.selection[pos];

  // Check if position has manual override
  const isOverridden = (pos: string) => pos in manualOverrides;

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      className={`bg-fm-surface rounded-xl overflow-hidden shadow-xl border ${isConfirmed ? 'border-fm-success/30' : 'border-white/5'}`}
    >
      <div className="bg-fm-dark/40 p-4 flex items-center justify-between border-b border-white/5">
        <div>
          <h3 className="text-lg font-bold text-white flex items-center gap-2">
            {item.date} vs {opponent}
            {isConfirmed && (
              <span className="text-fm-success flex items-center gap-1 text-sm font-normal">
                <CheckCircle size={16} />
                Confirmed
              </span>
            )}
          </h3>
          <div className="flex gap-2 mt-1">
            <Badge variant={item.importance === 'High' ? 'danger' : item.importance === 'Medium' ? 'warning' : item.importance === 'Sharpness' ? 'info' : 'success'}>
              {item.importance} Priority
            </Badge>
            {hasOverrides && (
              <Badge variant="warning">
                {Object.keys(manualOverrides).length} Override{Object.keys(manualOverrides).length > 1 ? 's' : ''}
              </Badge>
            )}
          </div>
        </div>

        <div className="flex gap-2">
          {hasOverrides && !isConfirmed && (
            <Button variant="ghost" size="sm" onClick={onClearAllOverrides} title="Clear all overrides">
              <RotateCcw size={16} className="mr-1" />
              Clear All
            </Button>
          )}

          {isConfirmed ? (
            <Button variant="outline" size="sm" onClick={onUndoConfirm} title="Unlock lineup for recalculation">
              <Unlock size={16} className="mr-1" />
              Unlock
            </Button>
          ) : (
            <Button variant="primary" size="sm" onClick={onConfirm} title="Lock this lineup">
              <Lock size={16} className="mr-1" />
              Confirm
            </Button>
          )}
        </div>
      </div>

      <div className="p-4 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3">
        {positions.map(pos => {
          let player = getPlayer(pos);
          const overridden = isOverridden(pos);
          const overriddenPlayerName = overridden ? manualOverrides[pos] : null;

          // Handle case where selection doesn't reflect override yet
          if (!player && overridden && overriddenPlayerName) {
            // Create minimal player object for display
            player = {
              name: overriddenPlayerName,
              rating: 0,
              condition: 1,
              sharpness: 1,
              fatigue: 0,
              age: 0,
              status: []
            };
          } else if (player && overridden && player.name !== overriddenPlayerName) {
            // Override exists but selection has different player - use override name
            player = { ...player, name: overriddenPlayerName! };
          }

          if (!player) return null;

          return (
            <PlayerCard
              key={pos}
              pos={pos}
              player={player}
              isOverridden={overridden}
              isConfirmed={isConfirmed}
              onReject={() => onReject(player.name, player.nameNormalized)}
              onOverride={() => onOverride(pos)}
              onClearOverride={() => onClearOverride(pos)}
            />
          );
        })}
      </div>
    </motion.div>
  );
}

interface PlayerCardProps {
  pos: string;
  player: MatchSelectionPlayer;
  isOverridden?: boolean;
  isConfirmed?: boolean;
  onReject: () => void;
  onOverride: () => void;
  onClearOverride: () => void;
}

function PlayerCard({ pos, player, isOverridden, isConfirmed, onReject, onOverride, onClearOverride }: PlayerCardProps) {

  const getStatusColor = (status: string) => {
    const lowerStatus = status.toLowerCase();
    if (lowerStatus.includes('vacation') || lowerStatus.includes('fatigued') || lowerStatus.includes('injury') || lowerStatus.includes('low condition')) {
      return "bg-red-500/10 text-red-500 border-red-500/20";
    }
    if (lowerStatus.includes('risk') || lowerStatus.includes('sharpness') || lowerStatus.includes('low')) {
      return "bg-yellow-500/10 text-yellow-500 border-yellow-500/20";
    }
    if (lowerStatus.includes('peak') || lowerStatus.includes('form')) {
      return "bg-green-500/10 text-green-500 border-green-500/20";
    }
    return "bg-blue-500/10 text-blue-400 border-blue-500/20";
  };

  return (
    <div className={`bg-white/5 rounded-lg p-3 border transition-colors group relative ${
      isOverridden
        ? 'border-yellow-500/40 bg-yellow-500/5'
        : 'border-white/5 hover:border-fm-teal/30'
    }`}>
      <div className="flex justify-between items-start mb-2">
        <div className="flex items-center gap-1">
          <span className="text-xs font-bold text-fm-teal bg-fm-teal/10 px-1.5 py-0.5 rounded">{pos}</span>
          {isOverridden && (
            <span className="text-[10px] font-bold text-yellow-500 bg-yellow-500/10 px-1 py-0.5 rounded">
              MANUAL
            </span>
          )}
        </div>

        {!isConfirmed && (
          <div className="flex gap-1">
            {isOverridden ? (
              <button
                onClick={onClearOverride}
                className="text-yellow-500/70 hover:text-yellow-500 transition-colors"
                title="Clear override"
              >
                <RotateCcw size={14} />
              </button>
            ) : (
              <button
                onClick={onOverride}
                className="text-fm-light/30 hover:text-fm-teal transition-colors opacity-0 group-hover:opacity-100"
                title="Override with different player"
              >
                <Edit3 size={14} />
              </button>
            )}
            <button
              onClick={onReject}
              className="text-fm-light/30 hover:text-fm-danger transition-colors opacity-0 group-hover:opacity-100"
              title="Reject from lineup"
            >
              <UserX size={14} />
            </button>
          </div>
        )}
      </div>

      <div className="font-bold text-white truncate mb-1" title={player.name}>{player.name}</div>

      {/* Hide stats for confirmed lineups (we don't have live data for them) */}
      {!isConfirmed && (
        <div className="flex gap-3 text-xs text-fm-light/70 mb-2">
          <div className="flex items-center gap-1" title="Condition">
            <Battery size={12} className={player.condition < 0.9 ? "text-fm-danger" : "text-fm-success"} />
            {Math.round(player.condition * 100)}%
          </div>
          <div className="flex items-center gap-1" title="Match Sharpness">
            <Activity size={12} className={player.sharpness < 0.8 ? "text-yellow-500" : "text-fm-success"} />
            {Math.round(player.sharpness * 100)}%
          </div>
          {player.fatigue > 0 && (
            <div className="flex items-center gap-1" title="Fatigue">
              <Zap size={12} className={player.fatigue > 400 ? "text-fm-danger" : "text-fm-light"} />
              {player.fatigue}
            </div>
          )}
        </div>
      )}

      {!isConfirmed && player.status && player.status.length > 0 && (
        <div className="flex flex-wrap gap-1">
          {player.status.map((s, i) => (
            <span key={i} className={`text-[10px] px-1 rounded border ${getStatusColor(s)}`}>
              {s}
            </span>
          ))}
        </div>
      )}
    </div>
  );
}

// Display-only card for future matches (6+) - no lineup data
function FutureMatchCard({ match }: { match: Match }) {
  return (
    <div className="bg-fm-surface/50 rounded-lg p-3 border border-white/5 flex items-center justify-between">
      <div className="flex items-center gap-4">
        <span className="text-fm-light/50 text-sm font-mono">{match.date}</span>
        <span className="text-white font-medium">vs {match.opponent}</span>
        <Badge variant={match.importance === 'High' ? 'danger' : match.importance === 'Medium' ? 'warning' : match.importance === 'Sharpness' ? 'info' : 'success'}>
          {match.importance}
        </Badge>
      </div>
      <span className="text-fm-light/40 text-xs italic">
        Lineup calculated when closer
      </span>
    </div>
  );
}

// Display-only card for past matches - basic fixture info only
function PastMatchCard({ match }: { match: Match }) {
  return (
    <div className="bg-fm-surface/30 rounded-lg p-3 border border-white/5 flex items-center justify-between grayscale-[0.3]">
      <div className="flex items-center gap-4">
        <span className="text-fm-light/40 text-sm font-mono">{match.date}</span>
        <span className="text-fm-light/70 font-medium">vs {match.opponent}</span>
        <Badge variant={match.importance === 'High' ? 'danger' : match.importance === 'Medium' ? 'warning' : match.importance === 'Sharpness' ? 'info' : 'success'}>
          {match.importance}
        </Badge>
        {match.confirmed && (
          <span className="text-xs text-fm-success/70 flex items-center gap-1">
            ✓ Confirmed
          </span>
        )}
      </div>
    </div>
  );
}
