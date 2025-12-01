import React, { useState, useEffect } from 'react';
import type { AppState, RestRecommendation } from '../types';
import { api } from '../api';
import { Button, Badge } from '../components/UI';
import { RefreshCw, BatteryCharging, BatteryWarning, Zap, Activity, AlertTriangle, Plane, Clock, TrendingUp, Shield } from 'lucide-react';
import { motion } from 'framer-motion';

interface RestTabProps {
  state: AppState;
}

export function RestTab({ state }: RestTabProps) {
  const [recommendations, setRecommendations] = useState<RestRecommendation[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadRecommendations = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await api.runRestAdvisor(state.files);

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

  const grouped = {
    Urgent: recommendations.filter(r => r.priority === 'Urgent'),
    High: recommendations.filter(r => r.priority === 'High'),
    Medium: recommendations.filter(r => r.priority === 'Medium'),
    Low: recommendations.filter(r => r.priority === 'Low'),
  };

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-white flex items-center gap-2">
            <Zap className="text-fm-teal" /> Fatigue Management
          </h2>
          <p className="text-fm-light/50 text-sm mt-1">
            Long-term load tracking - Condition recovers quickly, but fatigue requires intentional rest
          </p>
        </div>
        <Button onClick={loadRecommendations} disabled={loading} size="sm" className="flex items-center whitespace-nowrap">
          <RefreshCw size={16} className={loading ? "animate-spin mr-2" : "mr-2"} />
          Refresh
        </Button>
      </div>

      {/* Info banner about fatigue vs condition */}
      <div className="bg-fm-surface/50 border border-fm-teal/20 rounded-lg p-4">
        <div className="flex items-start gap-3">
          <Shield className="text-fm-teal mt-0.5" size={20} />
          <div className="text-sm text-fm-light/70">
            <span className="text-fm-teal font-semibold">Why fatigue matters:</span> Unlike condition (which recovers in 1-2 days),
            fatigue is a hidden long-term metric that accumulates over weeks. High fatigue suppresses mental attributes,
            increases injury risk, and slows condition recovery. <span className="text-white">Vacation is the only effective reset.</span>
          </div>
        </div>
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
        {grouped.Urgent.length > 0 && (
          <RestGroup
            title="VACATION REQUIRED"
            subtitle="Performance severely impacted - send on holiday immediately"
            items={grouped.Urgent}
            color="text-fm-danger"
            icon={<AlertTriangle size={20} />}
          />
        )}
        {grouped.High.length > 0 && (
          <RestGroup
            title="Rest Needed"
            subtitle="Approaching or at fatigue threshold - action required"
            items={grouped.High}
            color="text-orange-500"
            icon={<BatteryWarning size={20} />}
          />
        )}
        {grouped.Medium.length > 0 && (
          <RestGroup
            title="Watch List"
            subtitle="Fatigue accumulating - consider rotation in upcoming fixtures"
            items={grouped.Medium}
            color="text-yellow-500"
            icon={<TrendingUp size={20} />}
          />
        )}
        {grouped.Low.length > 0 && (
          <RestGroup
            title="Monitoring"
            subtitle="Early fatigue build-up - no action needed yet"
            items={grouped.Low}
            color="text-fm-success"
            icon={<Activity size={20} />}
          />
        )}

        {!loading && recommendations.length === 0 && !error && (
            <div className="text-center text-fm-light/50 py-12">
                <BatteryCharging size={48} className="mx-auto mb-4 text-fm-success" />
                <div className="text-lg font-medium text-white mb-2">Squad Fatigue is Low</div>
                <div>All players have healthy fatigue levels. No action needed.</div>
            </div>
        )}
      </div>
    </div>
  );
}

function RestGroup({ title, subtitle, items, color, icon }: {
  title: string,
  subtitle: string,
  items: RestRecommendation[],
  color: string,
  icon: React.ReactNode
}) {
  return (
    <div className="space-y-3">
      <div>
        <h3 className={`text-lg font-bold ${color} flex items-center gap-2 uppercase tracking-wider`}>
          {icon} {title}
        </h3>
        <p className="text-fm-light/50 text-sm mt-1">{subtitle}</p>
      </div>
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {items.map((rec) => (
          <FatigueCard key={rec.name} rec={rec} />
        ))}
      </div>
    </div>
  );
}

function FatigueCard({ rec }: { rec: RestRecommendation }) {
  const isVacation = rec.recovery_method === 'vacation';
  const fatiguePercent = Math.min(100, rec.fatigue_percentage || (rec.fatigue / rec.threshold) * 100);

  // Determine fatigue bar color based on percentage
  const getBarColor = (percent: number) => {
    if (percent >= 100) return 'bg-fm-danger';
    if (percent >= 80) return 'bg-orange-500';
    if (percent >= 60) return 'bg-yellow-500';
    return 'bg-fm-success';
  };

  // Get status badge styling
  const getStatusStyle = (status: string) => {
    switch (status) {
      case 'Exhausted':
        return 'bg-fm-danger/20 text-fm-danger border-fm-danger/30';
      case 'Jaded':
        return 'bg-orange-500/20 text-orange-400 border-orange-500/30';
      case 'Approaching Limit':
        return 'bg-orange-500/20 text-orange-400 border-orange-500/30';
      case 'Accumulating':
        return 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30';
      case 'Heavy Usage':
        return 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30';
      case 'Building':
        return 'bg-fm-success/20 text-fm-success border-fm-success/30';
      default:
        return 'bg-fm-dark/50 text-white border-white/10';
    }
  };

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      className="bg-fm-surface p-4 rounded-lg border border-white/5 hover:border-fm-teal/30 transition-all group relative overflow-hidden"
    >
      {/* Background indicators for vacation */}
      {isVacation && (
        <div className="absolute -right-8 -top-8 w-24 h-24 bg-blue-500/10 rotate-45 blur-xl pointer-events-none"></div>
      )}

      <div className="flex justify-between items-start relative z-10">
        <div className="flex-1">
          <div className="flex items-center gap-2 flex-wrap">
            <div className="text-lg font-bold text-white">{rec.name}</div>
            <Badge className={getStatusStyle(rec.status)}>
              {rec.status}
            </Badge>
          </div>

          {/* Fatigue Progress Bar */}
          <div className="mt-3">
            <div className="flex justify-between text-xs mb-1">
              <span className="text-fm-light/50">Fatigue Level</span>
              <span className={`font-mono font-bold ${fatiguePercent >= 100 ? 'text-fm-danger' : fatiguePercent >= 80 ? 'text-orange-400' : 'text-fm-light/70'}`}>
                {rec.fatigue.toFixed(0)} / {rec.threshold.toFixed(0)}
              </span>
            </div>
            <div className="h-2 bg-fm-dark/50 rounded-full overflow-hidden">
              <div
                className={`h-full ${getBarColor(fatiguePercent)} transition-all duration-500`}
                style={{ width: `${Math.min(100, fatiguePercent)}%` }}
              />
            </div>
            <div className="flex justify-between text-[10px] text-fm-light/40 mt-1">
              <span>0</span>
              <span className="text-orange-400">Warning ({rec.warning_threshold?.toFixed(0) || (rec.threshold * 0.8).toFixed(0)})</span>
              <span className="text-fm-danger">Limit</span>
            </div>
          </div>
        </div>
      </div>

      {/* Action and Recovery Time */}
      <div className="mt-4 flex items-center gap-3 relative z-10">
        <Badge className={`flex items-center gap-1 ${isVacation ? 'bg-blue-500/20 text-blue-400 border-blue-500/30' : 'bg-fm-dark/50 text-white border-white/10'}`}>
          {isVacation && <Plane size={12} />}
          {rec.action}
        </Badge>
        {rec.recovery_days > 0 && (
          <div className="flex items-center gap-1 text-sm text-fm-light/70">
            <Clock size={14} />
            <span>~{rec.recovery_days} days to recover</span>
          </div>
        )}
      </div>

      {/* Stats Row - Sharpness only (condition removed) */}
      <div className="mt-4 grid grid-cols-2 gap-2 relative z-10">
        <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
          <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1 flex items-center gap-1">
            <Activity size={10} /> Match Sharpness
          </div>
          <div className={`text-lg font-mono font-bold ${rec.sharpness < 0.8 ? 'text-yellow-500' : 'text-white'}`}>
            {(rec.sharpness * 100).toFixed(0)}%
          </div>
        </div>

        <div className="bg-fm-dark/30 p-2 rounded border border-white/5">
          <div className="text-[10px] text-fm-light/50 uppercase font-bold mb-1 flex items-center gap-1">
            <Zap size={10} /> Fatigue %
          </div>
          <div className={`text-lg font-mono font-bold ${fatiguePercent >= 100 ? 'text-fm-danger' : fatiguePercent >= 80 ? 'text-orange-400' : 'text-white'}`}>
            {fatiguePercent.toFixed(0)}%
          </div>
        </div>
      </div>

      {/* Reasons */}
      <div className="mt-3 pt-3 border-t border-white/5 space-y-1 relative z-10">
        {rec.reasons.map((reason, idx) => (
          <div key={idx} className="text-xs text-fm-light/70 flex items-start gap-2">
            <span className="text-fm-teal mt-0.5">→</span>
            {reason}
          </div>
        ))}
      </div>
    </motion.div>
  );
}
