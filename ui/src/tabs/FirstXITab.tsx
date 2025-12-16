import { useState, useEffect } from 'react';
import type { AppState, RotationPlayer, RotationResponse } from '../types';
import { api } from '../api';
import { Button, Badge } from '../components/UI';
import { RefreshCw, Users, Star, TrendingUp } from 'lucide-react';
import { motion } from 'framer-motion';

interface FirstXITabProps {
  state: AppState;
}

// Formation display order (R > C > L)
const FORMATION_GROUPS = {
  'Goalkeeper': ['GK'],
  'Defense': ['DR', 'DC1', 'DC2', 'DL'],
  'Defensive Midfield': ['DM(R)', 'DM(L)'],
  'Attacking Midfield': ['AMR', 'AMC', 'AML'],
  'Attack': ['STC']
};

export function FirstXITab({ state }: FirstXITabProps) {
  const [data, setData] = useState<RotationResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadData = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await api.runRotationSelector(state.files);

      if (response.success) {
        setData(response);
      } else {
        setError(response.error || "Failed to load squad data");
      }
    } catch (err) {
      setError(String(err));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [state.files]);

  const firstXI = data?.firstXI || {};
  const teamRating = data?.teamRatings?.firstXIAverage || 0;

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-white flex items-center gap-2">
            <Star className="text-fm-teal" /> First XI
          </h2>
          <p className="text-fm-light/50 text-sm mt-1">
            Optimal starting lineup based on position ratings (Hungarian algorithm)
          </p>
        </div>
        <Button onClick={loadData} disabled={loading} size="sm" className="flex items-center whitespace-nowrap">
          <RefreshCw size={16} className={loading ? "animate-spin mr-2" : "mr-2"} />
          Refresh
        </Button>
      </div>

      {/* Team Rating Summary */}
      {teamRating > 0 && (
        <div className="bg-fm-surface/50 border border-fm-teal/20 rounded-lg p-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-12 h-12 bg-fm-teal/20 rounded-full flex items-center justify-center">
                <TrendingUp className="text-fm-teal" size={24} />
              </div>
              <div>
                <div className="text-sm text-fm-light/50">Team Average Rating</div>
                <div className="text-3xl font-bold text-white">{teamRating.toFixed(1)}</div>
              </div>
            </div>
            <div className="text-right">
              <div className="text-sm text-fm-light/50">Players Selected</div>
              <div className="text-2xl font-bold text-fm-teal">{Object.keys(firstXI).length}/11</div>
            </div>
          </div>
        </div>
      )}

      {error && (
        <div className="bg-fm-danger/10 border border-fm-danger text-fm-danger p-4 rounded-md">
          {error}
        </div>
      )}

      {loading && Object.keys(firstXI).length === 0 && (
        <div className="flex justify-center py-20">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-fm-teal"></div>
        </div>
      )}

      {/* Squad Display */}
      <div className="space-y-6">
        {Object.entries(FORMATION_GROUPS).map(([groupName, positions]) => {
          const groupPlayers = positions
            .map(pos => ({ position: pos, player: firstXI[pos] }))
            .filter(p => p.player);

          if (groupPlayers.length === 0) return null;

          return (
            <PositionGroup
              key={groupName}
              title={groupName}
              players={groupPlayers}
            />
          );
        })}

        {!loading && Object.keys(firstXI).length === 0 && !error && (
          <div className="text-center text-fm-light/50 py-12">
            <Users size={48} className="mx-auto mb-4 text-fm-light/30" />
            <div className="text-lg font-medium text-white mb-2">No Squad Data</div>
            <div>Click Refresh to load the optimal First XI</div>
          </div>
        )}
      </div>
    </div>
  );
}

function PositionGroup({ title, players }: {
  title: string,
  players: { position: string, player: RotationPlayer }[]
}) {
  return (
    <div className="space-y-3">
      <h3 className="text-sm font-bold text-fm-teal uppercase tracking-wider flex items-center gap-2">
        {title}
      </h3>

      {/* Header Row */}
      <div className="hidden md:grid md:grid-cols-[80px_1fr_80px_100px_60px_80px_80px_80px] gap-2 px-4 text-xs text-fm-light/50 uppercase font-bold">
        <div>Pos</div>
        <div>Player</div>
        <div className="text-center">Rating</div>
        <div className="text-center">CA/PA</div>
        <div className="text-center">Age</div>
        <div className="text-center">Cond</div>
        <div className="text-center">Sharp</div>
        <div className="text-center">Fatigue</div>
      </div>

      <div className="space-y-2">
        {players.map(({ position, player }) => (
          <PlayerRow key={position} position={position} player={player} />
        ))}
      </div>
    </div>
  );
}

function PlayerRow({ position, player }: { position: string, player: RotationPlayer }) {
  // Determine condition color
  const getConditionColor = (cond: number) => {
    if (cond < 85) return 'text-yellow-500';
    if (cond < 95) return 'text-fm-light/70';
    return 'text-fm-success';
  };

  // Determine sharpness color
  const getSharpnessColor = (sharp: number) => {
    if (sharp < 75) return 'text-blue-400';
    if (sharp < 85) return 'text-fm-light/70';
    return 'text-fm-success';
  };

  // Determine fatigue color
  const getFatigueColor = (fatigue: number) => {
    if (fatigue > 350) return 'text-fm-danger';
    if (fatigue > 250) return 'text-orange-500';
    if (fatigue > 150) return 'text-yellow-500';
    return 'text-fm-success';
  };

  // Check if playing out of position
  const isOutOfPosition = player.naturalPosition &&
    !position.includes(player.naturalPosition) &&
    player.naturalPosition !== position;

  return (
    <motion.div
      initial={{ opacity: 0, x: -10 }}
      animate={{ opacity: 1, x: 0 }}
      className="bg-fm-surface p-3 md:p-4 rounded-lg border border-white/5 hover:border-fm-teal/30 transition-all"
    >
      {/* Mobile Layout */}
      <div className="md:hidden space-y-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Badge className="bg-fm-teal/20 text-fm-teal border-fm-teal/30 font-mono">
              {position}
            </Badge>
            <div>
              <div className="font-bold text-white">{player.name}</div>
              {player.naturalPosition && (
                <div className={`text-xs ${isOutOfPosition ? 'text-yellow-500' : 'text-fm-light/50'}`}>
                  Natural: {player.naturalPosition}
                </div>
              )}
            </div>
          </div>
          <div className="text-right">
            <div className="text-xl font-bold text-fm-teal">{player.rating.toFixed(1)}</div>
          </div>
        </div>

        <div className="grid grid-cols-4 gap-2 text-center">
          <div className="bg-fm-dark/30 p-2 rounded">
            <div className="text-[10px] text-fm-light/50 uppercase">CA/PA</div>
            <div className="text-sm font-mono font-bold text-white">{player.ca}/{player.pa}</div>
          </div>
          <div className="bg-fm-dark/30 p-2 rounded">
            <div className="text-[10px] text-fm-light/50 uppercase">Age</div>
            <div className="text-sm font-mono font-bold text-white">{player.age}</div>
          </div>
          <div className="bg-fm-dark/30 p-2 rounded">
            <div className="text-[10px] text-fm-light/50 uppercase">Cond</div>
            <div className={`text-sm font-mono font-bold ${getConditionColor(player.condition)}`}>
              {player.condition.toFixed(0)}%
            </div>
          </div>
          <div className="bg-fm-dark/30 p-2 rounded">
            <div className="text-[10px] text-fm-light/50 uppercase">Sharp</div>
            <div className={`text-sm font-mono font-bold ${getSharpnessColor(player.sharpness)}`}>
              {player.sharpness.toFixed(0)}%
            </div>
          </div>
        </div>
      </div>

      {/* Desktop Layout */}
      <div className="hidden md:grid md:grid-cols-[80px_1fr_80px_100px_60px_80px_80px_80px] gap-2 items-center">
        <Badge className="bg-fm-teal/20 text-fm-teal border-fm-teal/30 font-mono justify-center">
          {position}
        </Badge>

        <div>
          <div className="font-bold text-white">{player.name}</div>
          {player.naturalPosition && (
            <div className={`text-xs ${isOutOfPosition ? 'text-yellow-500' : 'text-fm-light/50'}`}>
              {player.naturalPosition}
            </div>
          )}
        </div>

        <div className="text-center">
          <div className="text-xl font-bold text-fm-teal">{player.rating.toFixed(1)}</div>
        </div>

        <div className="text-center font-mono">
          <span className="text-white">{player.ca}</span>
          <span className="text-fm-light/30">/</span>
          <span className="text-fm-light/70">{player.pa}</span>
        </div>

        <div className="text-center font-mono text-white">
          {player.age}
        </div>

        <div className={`text-center font-mono font-bold ${getConditionColor(player.condition)}`}>
          {player.condition.toFixed(0)}%
        </div>

        <div className={`text-center font-mono font-bold ${getSharpnessColor(player.sharpness)}`}>
          {player.sharpness.toFixed(0)}%
        </div>

        <div className={`text-center font-mono font-bold ${getFatigueColor(player.fatigue)}`}>
          {player.fatigue.toFixed(0)}
        </div>
      </div>
    </motion.div>
  );
}
