import React, { useState } from 'react';
import { useAppState } from './hooks/useAppState';
import { FixtureTab } from './tabs/FixtureTab';
import { MatchSelectionTab } from './tabs/MatchSelectionTab';
import { TrainingTab } from './tabs/TrainingTab';
import { RestTab } from './tabs/RestTab';
import { PlayerRemovalTab } from './tabs/PlayerRemovalTab';
import { FirstXITab } from './tabs/FirstXITab';
import { SecondXITab } from './tabs/SecondXITab';
import { Button, Input } from './components/UI';
import { Calendar, Users, Dumbbell, Settings, ChevronLeft, ChevronRight, BatteryCharging, UserMinus, Star, UsersRound } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

function App() {
  const {
    state,
    loading,
    updateDate,
    updateMatches,
    updateRejectedPlayers,
    resetRejectedPlayers,
    updateRejectedTraining,
    resetRejectedTraining,
    updateFiles,
    confirmMatch,
    undoConfirmation,
    updateManualOverrides,
    clearManualOverrides
  } = useAppState();

  const [activeTab, setActiveTab] = useState<'fixtures' | 'selection' | 'training' | 'rest' | 'removal' | 'firstXI' | 'secondXI'>('fixtures');
  const [showSettings, setShowSettings] = useState(false);

  const changeDate = (days: number) => {
    const date = new Date(state.currentDate);
    date.setDate(date.getDate() + days);
    updateDate(date.toISOString().split('T')[0]);
  };

  if (loading) {
    return <div className="h-screen w-screen bg-fm-dark flex items-center justify-center text-fm-teal font-bold text-xl animate-pulse">
      Loading Application State...
    </div>;
  }

  return (
    <div className="h-screen w-screen bg-fm-dark text-white flex overflow-hidden">
      {/* Sidebar */}
      <div className="w-64 bg-fm-purple flex flex-col border-r border-white/5 shrink-0">
        <div className="p-6">
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <span className="text-fm-teal">FM26</span> Optimizer
          </h1>
        </div>

        <div className="px-4 mb-6">
           <label className="text-xs text-fm-light/50 uppercase font-bold mb-2 block">Current Date</label>
           <div className="relative">
             <Calendar className="absolute left-3 top-1/2 -translate-y-1/2 text-fm-teal" size={16} />
             <Input 
                type="date" 
                className="w-full pl-10 bg-fm-dark/30" 
                value={state.currentDate}
                onChange={(e) => updateDate(e.target.value)}
             />
           </div>
           
           <div className="flex gap-2 mt-2">
             <Button 
               variant="secondary" 
               size="sm" 
               className="flex-1 flex justify-center"
               onClick={() => changeDate(-1)}
             >
               <ChevronLeft size={16} />
             </Button>
             <Button 
               variant="secondary" 
               size="sm" 
               className="flex-1 flex justify-center"
               onClick={() => changeDate(1)}
             >
               <ChevronRight size={16} />
             </Button>
           </div>
        </div>

        <nav className="flex-1 px-2 space-y-1">
          <SidebarItem 
            active={activeTab === 'fixtures'} 
            onClick={() => setActiveTab('fixtures')} 
            icon={<Calendar size={20} />} 
            label="Fixture List" 
          />
          <SidebarItem 
            active={activeTab === 'selection'} 
            onClick={() => setActiveTab('selection')} 
            icon={<Users size={20} />} 
            label="Match Selection" 
          />
          <SidebarItem 
            active={activeTab === 'training'} 
            onClick={() => setActiveTab('training')} 
            icon={<Dumbbell size={20} />} 
            label="Position Training" 
          />
          <SidebarItem
            active={activeTab === 'rest'}
            onClick={() => setActiveTab('rest')}
            icon={<BatteryCharging size={20} />}
            label="Rest & Rotation"
          />
          <SidebarItem
            active={activeTab === 'removal'}
            onClick={() => setActiveTab('removal')}
            icon={<UserMinus size={20} />}
            label="Player Removal"
          />
          <SidebarItem
            active={activeTab === 'firstXI'}
            onClick={() => setActiveTab('firstXI')}
            icon={<Star size={20} />}
            label="First XI"
          />
          <SidebarItem
            active={activeTab === 'secondXI'}
            onClick={() => setActiveTab('secondXI')}
            icon={<UsersRound size={20} />}
            label="Second XI"
          />
        </nav>

        <div className="p-4 mt-auto border-t border-white/5">
          <button 
            onClick={() => setShowSettings(!showSettings)}
            className="flex items-center gap-2 text-fm-light/50 hover:text-white transition-colors text-sm w-full"
          >
            <Settings size={16} />
            Data Sources
          </button>
          
          <AnimatePresence>
            {showSettings && (
              <motion.div 
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: 'auto', opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                className="mt-3 space-y-2 overflow-hidden"
              >
                <div>
                  <label className="text-[10px] text-fm-light/50 block mb-1">Status File (CSV)</label>
                  <Input 
                    className="w-full text-xs py-1" 
                    value={state.files.status} 
                    onChange={e => updateFiles({ ...state.files, status: e.target.value })}
                  />
                </div>
                <div>
                  <label className="text-[10px] text-fm-light/50 block mb-1">Abilities File (CSV)</label>
                  <Input 
                    className="w-full text-xs py-1" 
                    value={state.files.abilities} 
                    onChange={e => updateFiles({ ...state.files, abilities: e.target.value })}
                  />
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </div>

      {/* Main Content */}
      <div className="flex-1 bg-gradient-to-br from-fm-dark to-fm-purple/50 overflow-y-auto relative">
        <AnimatePresence mode="wait">
          <motion.div
            key={activeTab}
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            transition={{ duration: 0.2 }}
            className="min-h-full"
          >
            {activeTab === 'fixtures' && (
              <FixtureTab 
                matches={state.matches} 
                onUpdateMatches={updateMatches} 
                currentDate={state.currentDate}
              />
            )}
            {activeTab === 'selection' && (
              <MatchSelectionTab
                state={state}
                onRejectPlayer={updateRejectedPlayers}
                onResetRejections={resetRejectedPlayers}
                onConfirmMatch={confirmMatch}
                onUndoConfirmation={undoConfirmation}
                onUpdateManualOverrides={updateManualOverrides}
                onClearManualOverrides={clearManualOverrides}
              />
            )}
            {activeTab === 'training' && (
              <TrainingTab 
                state={state}
                onRejectTraining={updateRejectedTraining}
                onResetRejections={resetRejectedTraining}
              />
            )}
            {activeTab === 'rest' && (
              <RestTab state={state} />
            )}
            {activeTab === 'removal' && (
              <PlayerRemovalTab state={state} />
            )}
            {activeTab === 'firstXI' && (
              <FirstXITab state={state} />
            )}
            {activeTab === 'secondXI' && (
              <SecondXITab state={state} />
            )}
          </motion.div>
        </AnimatePresence>
      </div>
    </div>
  );
}

function SidebarItem({ active, onClick, icon, label }: { active: boolean, onClick: () => void, icon: React.ReactNode, label: string }) {
  return (
    <button
      onClick={onClick}
      className={`w-full flex items-center gap-3 px-4 py-3 rounded-md transition-all ${
        active 
          ? 'bg-fm-teal text-fm-dark font-bold shadow-lg shadow-fm-teal/20' 
          : 'text-fm-light hover:bg-white/5 hover:text-white'
      }`}
    >
      {icon}
      <span>{label}</span>
    </button>
  );
}

export default App;
