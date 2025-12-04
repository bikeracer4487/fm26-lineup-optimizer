import React, { useState, useEffect } from 'react';
import type { AppState, PlayerRemovalRecommendation } from '../types';
import { api } from '../api';
import { Button, Badge } from '../components/UI';
import { RefreshCw, UserMinus, AlertTriangle, TrendingDown, DollarSign, FileText, AlertCircle, Users, Clock, Target, Trash2 } from 'lucide-react';
import { motion } from 'framer-motion';

interface PlayerRemovalTabProps {
  state: AppState;
}

export function PlayerRemovalTab({ state }: PlayerRemovalTabProps) {
  const [recommendations, setRecommendations] = useState<PlayerRemovalRecommendation[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [filterPriority, setFilterPriority] = useState<string>('all');

  const loadRecommendations = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await api.runPlayerRemovalAdvisor(state.files);

      if (response.success && response.recommendations) {
        setRecommendations(response.recommendations);
      } else {
        setError(response.error || "Failed to load recommendations");
      }
    } catch (err) {
      setError(String(err));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadRecommendations();
  }, [state.files]);

  // Separate loaned players from owned players
  const loanedPlayers = recommendations.filter(r => r.is_loaned_in);
  const ownedPlayers = recommendations.filter(r => !r.is_loaned_in);

  // Filter by priority (for owned players only)
  const filteredRecs = filterPriority === 'all'
    ? ownedPlayers
    : ownedPlayers.filter(r => r.priority === filterPriority);

  // Group by priority for display (owned players only)
  const grouped = {
    Critical: filteredRecs.filter(r => r.priority === 'Critical'),
    High: filteredRecs.filter(r => r.priority === 'High'),
    Medium: filteredRecs.filter(r => r.priority === 'Medium'),
    Low: filteredRecs.filter(r => r.priority === 'Low'),
  };

  // Stats summary (owned players only)
  const criticalCount = ownedPlayers.filter(r => r.priority === 'Critical').length;
  const highCount = ownedPlayers.filter(r => r.priority === 'High').length;
  const totalWageSavings = ownedPlayers
    .filter(r => r.priority === 'Critical' || r.priority === 'High')
    .reduce((sum, r) => sum + r.wages_weekly, 0);

  // Count protected prospects (U21 with 15%+ headroom)
  const protectedProspects = ownedPlayers.filter(r => r.age <= 21 && r.headroom_percentage >= 15).length;

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-white flex items-center gap-2">
            <UserMinus className="text-fm-teal" /> Player Removal Recommendations
          </h2>
          <p className="text-fm-light/50 text-sm mt-1">
            Identify players to sell, loan, or release based on skill, wages, and contract situation
          </p>
        </div>
        <Button onClick={loadRecommendations} disabled={loading} size="sm" className="flex items-center whitespace-nowrap">
          <RefreshCw size={16} className={loading ? "animate-spin mr-2" : "mr-2"} />
          Refresh
        </Button>
      </div>

      {/* Summary Stats */}
      <div className="grid grid-cols-5 gap-4">
        <div className="bg-fm-surface/50 border border-fm-danger/20 rounded-lg p-4">
          <div className="text-xs text-fm-light/50 uppercase font-bold mb-1 flex items-center gap-1">
            <AlertTriangle size={12} /> Critical
          </div>
          <div className="text-2xl font-bold text-fm-danger">{criticalCount}</div>
          <div className="text-xs text-fm-light/50">players to remove</div>
        </div>
        <div className="bg-fm-surface/50 border border-orange-500/20 rounded-lg p-4">
          <div className="text-xs text-fm-light/50 uppercase font-bold mb-1 flex items-center gap-1">
            <TrendingDown size={12} /> High Priority
          </div>
          <div className="text-2xl font-bold text-orange-400">{highCount}</div>
          <div className="text-xs text-fm-light/50">consider moving on</div>
        </div>
        <div className="bg-fm-surface/50 border border-fm-teal/20 rounded-lg p-4">
          <div className="text-xs text-fm-light/50 uppercase font-bold mb-1 flex items-center gap-1">
            <DollarSign size={12} /> Potential Savings
          </div>
          <div className="text-2xl font-bold text-fm-teal">${totalWageSavings.toLocaleString()}</div>
          <div className="text-xs text-fm-light/50">per week (Critical + High)</div>
        </div>
        <div className="bg-fm-surface/50 border border-green-500/20 rounded-lg p-4">
          <div className="text-xs text-fm-light/50 uppercase font-bold mb-1 flex items-center gap-1">
            <Target size={12} /> Prospects
          </div>
          <div className="text-2xl font-bold text-green-400">{protectedProspects}</div>
          <div className="text-xs text-fm-light/50">U21 with potential</div>
        </div>
        <div className="bg-fm-surface/50 border border-blue-500/20 rounded-lg p-4">
          <div className="text-xs text-fm-light/50 uppercase font-bold mb-1 flex items-center gap-1">
            <Users size={12} /> Squad
          </div>
          <div className="text-2xl font-bold text-white">{ownedPlayers.length}</div>
          <div className="text-xs text-fm-light/50">owned + {loanedPlayers.length} on loan</div>
        </div>
      </div>

      {/* Filter Bar */}
      <div className="flex gap-2">
        <Button
          variant={filterPriority === 'all' ? 'primary' : 'secondary'}
          size="sm"
          onClick={() => setFilterPriority('all')}
        >
          All ({ownedPlayers.length})
        </Button>
        <Button
          variant={filterPriority === 'Critical' ? 'primary' : 'secondary'}
          size="sm"
          onClick={() => setFilterPriority('Critical')}
          className="border-fm-danger/30"
        >
          Critical ({grouped.Critical.length})
        </Button>
        <Button
          variant={filterPriority === 'High' ? 'primary' : 'secondary'}
          size="sm"
          onClick={() => setFilterPriority('High')}
          className="border-orange-500/30"
        >
          High ({grouped.High.length})
        </Button>
        <Button
          variant={filterPriority === 'Medium' ? 'primary' : 'secondary'}
          size="sm"
          onClick={() => setFilterPriority('Medium')}
          className="border-yellow-500/30"
        >
          Medium ({grouped.Medium.length})
        </Button>
        <Button
          variant={filterPriority === 'Low' ? 'primary' : 'secondary'}
          size="sm"
          onClick={() => setFilterPriority('Low')}
          className="border-fm-success/30"
        >
          Low ({grouped.Low.length})
        </Button>
      </div>

      {error && (
        <div className="bg-fm-danger/10 border border-fm-danger text-fm-danger p-4 rounded-md">
          {error}
        </div>
      )}

      {loading && !recommendations.length && (
        <div className="flex justify-center py-20">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-fm-teal"></div>
        </div>
      )}

      <div className="space-y-8">
        {/* LOAN REVIEW SECTION */}
        {loanedPlayers.length > 0 && (
          <div className="space-y-3">
            <div>
              <h3 className="text-lg font-bold text-blue-400 flex items-center gap-2 uppercase tracking-wider">
                <Users size={20} /> Loan Review ({loanedPlayers.length} Players)
              </h3>
              <p className="text-fm-light/50 text-sm mt-1">
                Loaned-in players - evaluate performance and decide on future
              </p>
            </div>
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
              {loanedPlayers.map((rec) => (
                <LoanPlayerCard key={rec.name} rec={rec} />
              ))}
            </div>
          </div>
        )}

        {/* OWNED PLAYERS SECTIONS */}
        {filterPriority === 'all' ? (
          <>
            {grouped.Critical.length > 0 && (
              <RemovalGroup
                title="CRITICAL - Remove Immediately"
                subtitle="Non-contract players or severe deadwood - release or sell ASAP"
                items={grouped.Critical}
                color="text-fm-danger"
                icon={<Trash2 size={20} />}
              />
            )}
            {grouped.High.length > 0 && (
              <RemovalGroup
                title="High Priority - Sell/Loan"
                subtitle="Poor fit, low contribution, or running down contract"
                items={grouped.High}
                color="text-orange-500"
                icon={<AlertTriangle size={20} />}
              />
            )}
            {grouped.Medium.length > 0 && (
              <RemovalGroup
                title="Medium - Monitor"
                subtitle="Consider for rotation, development loan, or future sale"
                items={grouped.Medium}
                color="text-yellow-500"
                icon={<AlertCircle size={20} />}
              />
            )}
            {grouped.Low.length > 0 && (
              <RemovalGroup
                title="Keep - Squad Members"
                subtitle="Valuable squad contributors - no action needed"
                items={grouped.Low}
                color="text-fm-success"
                icon={<Users size={20} />}
              />
            )}
          </>
        ) : (
          filteredRecs.length > 0 && (
            <RemovalGroup
              title={`${filterPriority} Priority Players`}
              subtitle=""
              items={filteredRecs}
              color={
                filterPriority === 'Critical' ? 'text-fm-danger' :
                filterPriority === 'High' ? 'text-orange-500' :
                filterPriority === 'Medium' ? 'text-yellow-500' :
                'text-fm-success'
              }
              icon={<Users size={20} />}
            />
          )
        )}

        {!loading && recommendations.length === 0 && !error && (
          <div className="text-center text-fm-light/50 py-12">
            <Users size={48} className="mx-auto mb-4 text-fm-teal" />
            <div className="text-lg font-medium text-white mb-2">No Players Found</div>
            <div>Unable to load player data. Check your data sources.</div>
          </div>
        )}
      </div>
    </div>
  );
}

function RemovalGroup({ title, subtitle, items, color, icon }: {
  title: string,
  subtitle: string,
  items: PlayerRemovalRecommendation[],
  color: string,
  icon: React.ReactNode
}) {
  return (
    <div className="space-y-3">
      <div>
        <h3 className={`text-lg font-bold ${color} flex items-center gap-2 uppercase tracking-wider`}>
          {icon} {title}
        </h3>
        {subtitle && <p className="text-fm-light/50 text-sm mt-1">{subtitle}</p>}
      </div>
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {items.map((rec) => (
          <PlayerRemovalCard key={rec.name} rec={rec} />
        ))}
      </div>
    </div>
  );
}

function PlayerRemovalCard({ rec }: { rec: PlayerRemovalRecommendation }) {
  const getPriorityStyle = (priority: string) => {
    switch (priority) {
      case 'Critical':
        return 'bg-fm-danger/20 text-fm-danger border-fm-danger/30';
      case 'High':
        return 'bg-orange-500/20 text-orange-400 border-orange-500/30';
      case 'Medium':
        return 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30';
      case 'Low':
        return 'bg-fm-success/20 text-fm-success border-fm-success/30';
      default:
        return 'bg-fm-dark/50 text-white border-white/10';
    }
  };

  const getCAColor = (ca: number, avgCa: number) => {
    if (ca >= avgCa * 1.1) return 'text-fm-success';
    if (ca >= avgCa * 0.9) return 'text-white';
    if (ca >= avgCa * 0.8) return 'text-yellow-400';
    return 'text-fm-danger';
  };

  // Format currency for display
  const formatCurrency = (val: number) => {
    if (val >= 1000000) return `$${(val / 1000000).toFixed(1)}M`;
    if (val >= 1000) return `$${(val / 1000).toFixed(0)}K`;
    return `$${val.toFixed(0)}`;
  };

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      className="bg-fm-surface p-4 rounded-lg border border-white/5 hover:border-fm-teal/30 transition-all group"
    >
      {/* Header */}
      <div className="flex justify-between items-start mb-3">
        <div className="flex-1">
          <div className="flex items-center gap-2 flex-wrap">
            <div className="text-lg font-bold text-white">{rec.name}</div>
            <Badge className={getPriorityStyle(rec.priority)}>
              {rec.priority}
            </Badge>
            {/* Prospect badge for U21 with development potential */}
            {rec.age <= 21 && rec.headroom_percentage >= 15 && (
              <Badge className="bg-green-500/20 text-green-400 border-green-500/30">
                Prospect
              </Badge>
            )}
          </div>
          <div className="text-sm text-fm-light/50 mt-1">
            {rec.positions || 'Unknown'} | Age {rec.age}
          </div>
        </div>
      </div>

      {/* Skill Comparison */}
      <div className="grid grid-cols-4 gap-2 mb-3">
        <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
          <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1 flex items-center gap-1">
            <Target size={10} /> CA
          </div>
          <div className={`text-lg font-mono font-bold ${getCAColor(rec.ca, rec.squad_avg_ca)}`}>
            {rec.ca}
          </div>
          <div className="text-[10px] text-fm-light/40">
            Avg: {rec.squad_avg_ca}
          </div>
        </div>

        <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
          <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1 flex items-center gap-1">
            <TrendingDown size={10} /> PA
          </div>
          <div className={`text-lg font-mono font-bold ${rec.headroom_percentage >= 30 ? 'text-green-400' : rec.headroom_percentage >= 15 ? 'text-yellow-400' : 'text-fm-light/50'}`}>
            {rec.pa}
          </div>
          <div className="text-[10px] text-fm-light/40">
            {rec.headroom_percentage > 0 ? `+${rec.headroom_percentage.toFixed(0)}%` : 'Maxed'}
          </div>
        </div>

        <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
          <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1 flex items-center gap-1">
            <Users size={10} /> Position Rank
          </div>
          <div className={`text-lg font-mono font-bold ${rec.position_rank <= 2 ? 'text-fm-success' : rec.position_rank <= 4 ? 'text-yellow-400' : 'text-fm-danger'}`}>
            #{rec.position_rank}
          </div>
          <div className="text-[10px] text-fm-light/40">
            of {rec.total_at_position} at {rec.skill_position}
          </div>
        </div>

        <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
          <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1 flex items-center gap-1">
            <Target size={10} /> Skill
          </div>
          <div className="text-lg font-mono font-bold text-white">
            {rec.best_skill.toFixed(0)}
          </div>
          <div className="text-[10px] text-fm-light/40">
            at {rec.skill_position}
          </div>
        </div>
      </div>

      {/* Contract Info */}
      <div className="grid grid-cols-2 gap-2 mb-3">
        <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
          <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1 flex items-center gap-1">
            <FileText size={10} /> Contract
          </div>
          <div className="text-sm font-bold text-white">
            {rec.contract_type}
          </div>
          <div className="text-[10px] text-fm-light/40 flex items-center gap-1">
            <Clock size={8} />
            {rec.months_remaining > 0 ? `${rec.months_remaining} months left` : 'Expired/None'}
          </div>
        </div>

        <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
          <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1 flex items-center gap-1">
            <DollarSign size={10} /> Wages
          </div>
          <div className="text-sm font-bold text-white">
            ${rec.wages_weekly.toLocaleString()}/wk
          </div>
          <div className="text-[10px] text-fm-light/40">
            {rec.ca > 0 && rec.wages_weekly > 0
              ? `${(rec.ca / rec.wages_weekly * 100).toFixed(1)} CA/$100`
              : 'N/A'}
          </div>
        </div>
      </div>

      {/* Financial Info */}
      <div className="grid grid-cols-3 gap-2 mb-3">
        <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
          <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1">
            Transfer Value
          </div>
          <div className={`text-sm font-bold ${rec.asking_price > 0 ? 'text-fm-success' : 'text-fm-light/50'}`}>
            {rec.asking_price > 0 ? formatCurrency(rec.asking_price) : 'None'}
          </div>
        </div>

        <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
          <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1">
            Release Cost
          </div>
          <div className={`text-sm font-bold ${rec.release_cost > 0 ? 'text-fm-danger' : 'text-fm-success'}`}>
            {rec.release_cost > 0 ? formatCurrency(rec.release_cost) : 'Free'}
          </div>
        </div>

        <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
          <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1">
            Mutual Term. Est.
          </div>
          <div className={`text-sm font-bold ${rec.mutual_termination_cost > 0 ? 'text-orange-400' : 'text-fm-success'}`}>
            {rec.mutual_termination_cost > 0 ? formatCurrency(rec.mutual_termination_cost) : 'Free'}
          </div>
        </div>
      </div>

      {/* Hidden Attributes (if available) */}
      {(rec.consistency !== null || rec.important_matches !== null || rec.injury_proneness !== null) && (
        <div className="grid grid-cols-3 gap-2 mb-3">
          {rec.consistency !== null && (
            <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
              <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1">
                Consistency
              </div>
              <div className={`text-sm font-bold ${rec.consistency >= 12 ? 'text-fm-success' : rec.consistency >= 8 ? 'text-white' : 'text-fm-danger'}`}>
                {rec.consistency}
              </div>
            </div>
          )}
          {rec.important_matches !== null && (
            <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
              <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1">
                Big Matches
              </div>
              <div className={`text-sm font-bold ${rec.important_matches >= 12 ? 'text-fm-success' : rec.important_matches >= 8 ? 'text-white' : 'text-fm-danger'}`}>
                {rec.important_matches}
              </div>
            </div>
          )}
          {rec.injury_proneness !== null && (
            <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
              <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1">
                Injury Prone
              </div>
              <div className={`text-sm font-bold ${rec.injury_proneness <= 8 ? 'text-fm-success' : rec.injury_proneness <= 12 ? 'text-white' : 'text-fm-danger'}`}>
                {rec.injury_proneness}
              </div>
            </div>
          )}
        </div>
      )}

      {/* Recommended Action */}
      <div className="mb-3">
        <Badge className="bg-fm-teal/20 text-fm-teal border-fm-teal/30">
          {rec.recommended_action}
        </Badge>
      </div>

      {/* Reasons */}
      {rec.reasons.length > 0 && (
        <div className="pt-3 border-t border-white/5 space-y-1">
          {rec.reasons.map((reason, idx) => (
            <div key={idx} className="text-xs text-fm-light/70 flex items-start gap-2">
              <span className="text-fm-teal mt-0.5">→</span>
              {reason}
            </div>
          ))}
        </div>
      )}
    </motion.div>
  );
}

// Loan Player Card - simplified view for loaned-in players
function LoanPlayerCard({ rec }: { rec: PlayerRemovalRecommendation }) {
  const getLoanPriorityStyle = (priority: string) => {
    switch (priority) {
      case 'End Early':
        return 'bg-fm-danger/20 text-fm-danger border-fm-danger/30';
      case 'Monitor':
        return 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30';
      case 'Keep':
        return 'bg-fm-success/20 text-fm-success border-fm-success/30';
      default:
        return 'bg-blue-500/20 text-blue-400 border-blue-500/30';
    }
  };

  const getCAColor = (ca: number, avgCa: number) => {
    if (ca >= avgCa * 1.1) return 'text-fm-success';
    if (ca >= avgCa * 0.9) return 'text-white';
    if (ca >= avgCa * 0.8) return 'text-yellow-400';
    return 'text-fm-danger';
  };

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      className="bg-fm-surface p-4 rounded-lg border border-blue-500/20 hover:border-blue-500/40 transition-all group"
    >
      {/* Header */}
      <div className="flex justify-between items-start mb-3">
        <div className="flex-1">
          <div className="flex items-center gap-2 flex-wrap">
            <div className="text-lg font-bold text-white">{rec.name}</div>
            <Badge className="bg-blue-500/20 text-blue-400 border-blue-500/30">
              On Loan
            </Badge>
            <Badge className={getLoanPriorityStyle(rec.priority)}>
              {rec.priority}
            </Badge>
          </div>
          <div className="text-sm text-fm-light/50 mt-1">
            {rec.positions || 'Unknown'} | Age {rec.age}
          </div>
        </div>
      </div>

      {/* Skill Comparison - Simplified for loans */}
      <div className="grid grid-cols-3 gap-2 mb-3">
        <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
          <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1 flex items-center gap-1">
            <Target size={10} /> CA
          </div>
          <div className={`text-lg font-mono font-bold ${getCAColor(rec.ca, rec.squad_avg_ca)}`}>
            {rec.ca}
          </div>
          <div className="text-[10px] text-fm-light/40">
            Avg: {rec.squad_avg_ca}
          </div>
        </div>

        <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
          <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1 flex items-center gap-1">
            <Users size={10} /> Position Rank
          </div>
          <div className={`text-lg font-mono font-bold ${rec.position_rank <= 2 ? 'text-fm-success' : rec.position_rank <= 4 ? 'text-yellow-400' : 'text-fm-danger'}`}>
            #{rec.position_rank}
          </div>
          <div className="text-[10px] text-fm-light/40">
            of {rec.total_at_position} at {rec.skill_position}
          </div>
        </div>

        <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
          <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1 flex items-center gap-1">
            <Target size={10} /> Skill
          </div>
          <div className="text-lg font-mono font-bold text-white">
            {rec.best_skill.toFixed(0)}
          </div>
          <div className="text-[10px] text-fm-light/40">
            at {rec.skill_position}
          </div>
        </div>
      </div>

      {/* Hidden Attributes (if available) */}
      {(rec.consistency !== null || rec.important_matches !== null || rec.injury_proneness !== null) && (
        <div className="grid grid-cols-3 gap-2 mb-3">
          {rec.consistency !== null && (
            <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
              <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1">
                Consistency
              </div>
              <div className={`text-sm font-bold ${rec.consistency >= 12 ? 'text-fm-success' : rec.consistency >= 8 ? 'text-white' : 'text-fm-danger'}`}>
                {rec.consistency}
              </div>
            </div>
          )}
          {rec.important_matches !== null && (
            <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
              <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1">
                Big Matches
              </div>
              <div className={`text-sm font-bold ${rec.important_matches >= 12 ? 'text-fm-success' : rec.important_matches >= 8 ? 'text-white' : 'text-fm-danger'}`}>
                {rec.important_matches}
              </div>
            </div>
          )}
          {rec.injury_proneness !== null && (
            <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
              <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1">
                Injury Prone
              </div>
              <div className={`text-sm font-bold ${rec.injury_proneness <= 8 ? 'text-fm-success' : rec.injury_proneness <= 12 ? 'text-white' : 'text-fm-danger'}`}>
                {rec.injury_proneness}
              </div>
            </div>
          )}
        </div>
      )}

      {/* Recommended Action */}
      <div className="mb-3">
        <Badge className="bg-blue-500/20 text-blue-400 border-blue-500/30">
          {rec.recommended_action}
        </Badge>
      </div>

      {/* Reasons */}
      {rec.reasons.length > 0 && (
        <div className="pt-3 border-t border-white/5 space-y-1">
          {rec.reasons.map((reason, idx) => (
            <div key={idx} className="text-xs text-fm-light/70 flex items-start gap-2">
              <span className="text-blue-400 mt-0.5">→</span>
              {reason}
            </div>
          ))}
        </div>
      )}
    </motion.div>
  );
}
