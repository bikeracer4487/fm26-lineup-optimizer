import React, { useState, useEffect } from 'react';
import { useAppState } from '../hooks/useAppState';
import { Button } from '../components/UI';
import { Save, AlertTriangle, ArrowRight, Shield, Activity } from 'lucide-react';
import rolesData from '../data/roles.json';
import type { TacticConfig } from '../types';

// Map visual grid slots to data keys in roles.json
// Note: JSON keys might have spaces e.g. "M (L/R)"
const SLOT_TO_DATA_KEY: Record<string, string> = {
  'GK': 'GK',
  'D_L': 'D(L/R)',
  'D_CL': 'D(C)',
  'D_C': 'D(C)',
  'D_CR': 'D(C)',
  'D_R': 'D(L/R)',
  'WB_L': 'WB(L/R)',
  'DM_L': 'DM',
  'DM_C': 'DM',
  'DM_R': 'DM',
  'WB_R': 'WB(L/R)',
  'M_L': 'M (L/R)',
  'M_CL': 'M(C)',
  'M_C': 'M(C)',
  'M_CR': 'M(C)',
  'M_R': 'M (L/R)',
  'AM_L': 'AM (L/R)',
  'AM_CL': 'AM (C)',
  'AM_C': 'AM (C)',
  'AM_CR': 'AM (C)',
  'AM_R': 'AM (L/R)',
  'ST_L': 'ST',
  'ST_C': 'ST',
  'ST_R': 'ST',
};

const SLOT_NAMES: Record<string, string> = {
  'GK': 'GK',
  'D_L': 'D(L)', 'D_CL': 'D(C) Left', 'D_C': 'D(C) Center', 'D_CR': 'D(C) Right', 'D_R': 'D(R)',
  'WB_L': 'WB(L)', 'DM_L': 'DM Left', 'DM_C': 'DM Center', 'DM_R': 'DM Right', 'WB_R': 'WB(R)',
  'M_L': 'M(L)', 'M_CL': 'M(C) Left', 'M_C': 'M(C) Center', 'M_CR': 'M(C) Right', 'M_R': 'M(R)',
  'AM_L': 'AM(L)', 'AM_CL': 'AM(C) Left', 'AM_C': 'AM(C) Center', 'AM_CR': 'AM(C) Right', 'AM_R': 'AM(R)',
  'ST_L': 'ST Left', 'ST_C': 'ST Center', 'ST_R': 'ST Right'
};

// Grid rows for rendering
const ROWS = [
  ['ST_L', 'ST_C', 'ST_R'],
  ['AM_L', 'AM_CL', 'AM_C', 'AM_CR', 'AM_R'],
  ['M_L', 'M_CL', 'M_C', 'M_CR', 'M_R'],
  ['WB_L', 'DM_L', 'DM_C', 'DM_R', 'WB_R'],
  ['D_L', 'D_CL', 'D_C', 'D_CR', 'D_R'],
  ['GK']
];

export function TacticsTab() {
  const { state, updateTacticConfig } = useAppState();
  const [activeSubTab, setActiveSubTab] = useState<'IP' | 'OOP' | 'Mapping'>('IP');
  
  // Local state for editing
  const [config, setConfig] = useState<TacticConfig>(state.tacticConfig || {
    ipPositions: {},
    oopPositions: {},
    mapping: {}
  });

  // Sync with global state on load (if not dirty? or always reset on mount?)
  // For now, init from state.
  useEffect(() => {
    if (state.tacticConfig) {
      setConfig(state.tacticConfig);
    }
  }, [state.tacticConfig]);

  const handleRoleSelect = (phase: 'IP' | 'OOP', slot: string, role: string | null) => {
    setConfig(prev => {
      const target = phase === 'IP' ? 'ipPositions' : 'oopPositions';
      const newPos = { ...prev[target], [slot]: role };
      
      // Auto-update mapping if slot matches?
      // If we select a role in IP, and that slot has a role in OOP, maybe default map them?
      // For now, just update the role.
      
      return { ...prev, [target]: newPos };
    });
  };

  const handleMapping = (ipSlot: string, oopSlot: string | null) => {
    setConfig(prev => ({
      ...prev,
      mapping: { ...prev.mapping, [ipSlot]: oopSlot }
    }));
  };

  const getActiveSlots = (phase: 'IP' | 'OOP') => {
    const positions = phase === 'IP' ? config.ipPositions : config.oopPositions;
    return Object.entries(positions)
      .filter(([_, role]) => role !== null && role !== '')
      .map(([slot]) => slot);
  };

  const validateConfig = () => {
    const ipSlots = getActiveSlots('IP');
    const oopSlots = getActiveSlots('OOP');
    
    const errors: string[] = [];
    
    if (ipSlots.length !== 11) errors.push(`IP Tactic must have exactly 11 players (Current: ${ipSlots.length})`);
    if (oopSlots.length !== 11) errors.push(`OOP Tactic must have exactly 11 players (Current: ${oopSlots.length})`);
    
    if (!config.ipPositions['GK']) errors.push("GK must be selected in IP Tactic");
    if (!config.oopPositions['GK']) errors.push("GK must be selected in OOP Tactic");
    
    // Check mapping
    const unmapped = ipSlots.filter(slot => !config.mapping[slot]);
    
    if (unmapped.length > 0) {
      errors.push(`All IP positions must be mapped to an OOP position. Unmapped: ${unmapped.map(s => SLOT_NAMES[s]).join(', ')}`);
    }
    
    // Check if mapping target is valid (is an active OOP slot)
    const invalidTargets = Object.entries(config.mapping)
      .filter(([ip, oop]) => ipSlots.includes(ip) && oop && !oopSlots.includes(oop));
      
    if (invalidTargets.length > 0) {
      errors.push("Some IP positions are mapped to inactive OOP positions.");
    }

    return errors;
  };

  const errors = validateConfig();
  const isValid = errors.length === 0;

  const handleSave = () => {
    if (isValid) {
      updateTacticConfig(config);
    }
  };

  const handleReset = () => {
    if (state.tacticConfig) {
      setConfig(state.tacticConfig);
    }
  };

  return (
    <div className="p-6 h-full flex flex-col">
      <div className="flex justify-between items-start mb-6">
        <div>
          <h2 className="text-2xl font-bold text-white mb-2">Tactics Configuration</h2>
          <p className="text-fm-light/70 text-sm max-w-2xl">
            Configure your In-Possession and Out-of-Possession formations. 
            Use the Mapping tab to link player roles between phases.
          </p>
        </div>
        
        <div className="flex gap-2">
          <Button variant="secondary" onClick={handleReset}>Reset Changes</Button>
          <Button 
            disabled={!isValid} 
            onClick={handleSave}
            className={isValid ? "bg-fm-teal text-fm-dark" : "opacity-50 cursor-not-allowed"}
          >
            <Save size={16} className="mr-2" />
            Save Configuration
          </Button>
        </div>
      </div>

      {!isValid && (
        <div className="mb-6 p-4 bg-red-500/10 border border-red-500/30 rounded-lg">
          <h3 className="text-red-400 font-bold flex items-center gap-2 mb-2">
            <AlertTriangle size={18} />
            Configuration Incomplete
          </h3>
          <ul className="list-disc list-inside text-sm text-red-300/80 space-y-1">
            {errors.map((err, i) => (
              <li key={i}>{err}</li>
            ))}
          </ul>
        </div>
      )}

      <div className="flex gap-4 border-b border-white/10 mb-6">
        <TabButton 
          active={activeSubTab === 'IP'} 
          onClick={() => setActiveSubTab('IP')}
          icon={<Activity size={16} />}
          label="In Possession"
        />
        <TabButton 
          active={activeSubTab === 'OOP'} 
          onClick={() => setActiveSubTab('OOP')}
          icon={<Shield size={16} />}
          label="Out of Possession"
        />
        <TabButton 
          active={activeSubTab === 'Mapping'} 
          onClick={() => setActiveSubTab('Mapping')}
          icon={<ArrowRight size={16} />}
          label="Role Mapping"
        />
      </div>

      <div className="flex-1 overflow-y-auto min-h-0 pb-10">
        {activeSubTab === 'IP' && (
          <TacticsGrid 
            phase="IP" 
            positions={config.ipPositions} 
            onSelect={(slot, role) => handleRoleSelect('IP', slot, role)} 
          />
        )}
        {activeSubTab === 'OOP' && (
          <TacticsGrid 
            phase="OOP" 
            positions={config.oopPositions} 
            onSelect={(slot, role) => handleRoleSelect('OOP', slot, role)} 
          />
        )}
        {activeSubTab === 'Mapping' && (
          <MappingView 
            ipPositions={config.ipPositions}
            oopPositions={config.oopPositions}
            mapping={config.mapping}
            onMap={handleMapping}
          />
        )}
      </div>
    </div>
  );
}

function TabButton({ active, onClick, icon, label }: { active: boolean, onClick: () => void, icon: React.ReactNode, label: string }) {
  return (
    <button
      onClick={onClick}
      className={`pb-3 px-4 flex items-center gap-2 transition-colors relative ${
        active ? 'text-fm-teal' : 'text-fm-light/50 hover:text-white'
      }`}
    >
      {icon}
      <span className="font-bold text-sm uppercase tracking-wider">{label}</span>
      {active && (
        <div className="absolute bottom-0 left-0 w-full h-0.5 bg-fm-teal" />
      )}
    </button>
  );
}

function TacticsGrid({ phase, positions, onSelect }: { phase: 'IP' | 'OOP', positions: Record<string, string | null>, onSelect: (slot: string, role: string | null) => void }) {
  // Determine available roles from JSON
  const getRolesForSlot = (slot: string) => {
    const key = SLOT_TO_DATA_KEY[slot];
    // rolesData is structure: { "IP": { "D(L/R)": { "Full Back": { ... } } } }
    const phaseKey = phase;
    // Handle JSON spacing key variations
    // rolesData keys might be "D(L/R)" or "D (L/R)"?
    // Let's assume normalized in my helper, but here I use raw JSON.
    // I should check what's in roles.json actually.
    // The provided file had "D(L/R)", "M (L/R)", "AM (L/R)".
    // So my SLOT_TO_DATA_KEY needs to match exactly.
    
    // Safety check
    const phaseData = (rolesData as any)[phaseKey] || {};
    let posData = phaseData[key];
    
    if (!posData) {
        // Try fuzzy check for space
        const target = key.replace(' ', '');
        for (const k of Object.keys(phaseData)) {
            if (k.replace(' ', '') === target) {
                posData = phaseData[k];
                break;
            }
        }
    }
    
    if (!posData) return [];
    return Object.keys(posData);
  };

  return (
    <div className="flex flex-col gap-4 max-w-4xl mx-auto items-center">
      {ROWS.map((row, i) => (
        <div key={i} className="flex justify-center gap-4 w-full">
          {row.map(slot => {
            const role = positions[slot] || '';
            const availableRoles = getRolesForSlot(slot);
            const isActive = !!role;
            
            return (
              <div key={slot} className="flex flex-col items-center w-32">
                <div className={`w-12 h-12 rounded-full flex items-center justify-center mb-2 border-2 transition-colors ${
                  isActive 
                    ? 'bg-fm-teal/20 border-fm-teal text-fm-teal' 
                    : 'bg-white/5 border-white/10 text-white/30'
                }`}>
                  <span className="text-xs font-bold">{slot.split('_')[0]}</span>
                </div>
                <select 
                  value={role}
                  onChange={(e) => onSelect(slot, e.target.value || null)}
                  className={`w-full text-[10px] bg-fm-dark border rounded px-1 py-1 focus:outline-none focus:border-fm-teal ${
                    isActive ? 'border-fm-teal/50 text-white' : 'border-white/10 text-white/30'
                  }`}
                >
                  <option value="">- Role -</option>
                  {availableRoles.map(r => (
                    <option key={r} value={r}>{r}</option>
                  ))}
                </select>
                <div className="text-[9px] text-white/30 mt-1 text-center truncate w-full">
                  {SLOT_NAMES[slot]}
                </div>
              </div>
            );
          })}
        </div>
      ))}
    </div>
  );
}

function MappingView({ ipPositions, oopPositions, mapping, onMap }: { 
  ipPositions: Record<string, string | null>, 
  oopPositions: Record<string, string | null>, 
  mapping: Record<string, string | null>,
  onMap: (ip: string, oop: string | null) => void
}) {
  const activeIpSlots = Object.entries(ipPositions).filter(([_, r]) => r).map(([s]) => s);
  const activeOopSlots = Object.entries(oopPositions).filter(([_, r]) => r).map(([s]) => s);

  // Auto-map GK if not mapped
  useEffect(() => {
    if (ipPositions['GK'] && oopPositions['GK'] && mapping['GK'] !== 'GK') {
      onMap('GK', 'GK');
    }
  }, [ipPositions, oopPositions, mapping, onMap]);

  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-fm-dark/30 rounded-lg border border-white/5 overflow-hidden">
        <table className="w-full text-sm text-left">
          <thead className="bg-white/5 text-fm-light/70 uppercase text-xs">
            <tr>
              <th className="px-4 py-3">IP Position / Role</th>
              <th className="px-4 py-3 text-center">Mapped To</th>
              <th className="px-4 py-3">OOP Position / Role</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-white/5">
            {activeIpSlots.map(ipSlot => {
              const ipRole = ipPositions[ipSlot];
              const currentMap = mapping[ipSlot] || '';
              
              // Helper to check if mapping is valid (target exists in OOP)
              const isValid = !currentMap || activeOopSlots.includes(currentMap);
              
              return (
                <tr key={ipSlot} className="hover:bg-white/5 transition-colors">
                  <td className="px-4 py-3">
                    <div className="font-bold text-fm-teal">{SLOT_NAMES[ipSlot]}</div>
                    <div className="text-xs text-white/50">{ipRole}</div>
                  </td>
                  <td className="px-4 py-3 text-center">
                    <div className="flex justify-center items-center">
                      <ArrowRight size={16} className="text-fm-light/30" />
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    {ipSlot === 'GK' ? (
                      <div className="text-white/50 text-xs italic">Fixed (GK)</div>
                    ) : (
                      <select
                        value={currentMap}
                        onChange={(e) => onMap(ipSlot, e.target.value || null)}
                        className={`w-full bg-fm-dark border rounded px-2 py-1.5 focus:border-fm-teal outline-none ${
                          !isValid ? 'border-red-500 text-red-400' : 'border-white/10'
                        }`}
                      >
                        <option value="">- Select OOP Position -</option>
                        {activeOopSlots.map(oopSlot => (
                          <option key={oopSlot} value={oopSlot}>
                            {SLOT_NAMES[oopSlot]} ({oopPositions[oopSlot]})
                          </option>
                        ))}
                      </select>
                    )}
                  </td>
                </tr>
              );
            })}
            {activeIpSlots.length === 0 && (
              <tr>
                <td colSpan={3} className="px-4 py-8 text-center text-white/30 italic">
                  No positions selected in In-Possession tactic.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
