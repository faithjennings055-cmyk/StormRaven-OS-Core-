'use client';
import React from 'react';

export default function Desktop({ children }: { children: React.ReactNode }) {
  return (
    <div className="relative h-screen w-screen overflow-hidden bg-[#07030a] text-slate-200">
      {/* Mac-style Top Bar */}
      <div className="fixed top-0 left-0 right-0 h-8 bg-[#07030a]/80 backdrop-blur-md border-b border-[#06b6d4]/30 flex items-center px-4 justify-between z-50 text-xs font-medium">
        <div className="flex items-center gap-4">
          <span className="font-bold text-[#06b6d4]"> StormRaven OS</span>
          <span className="opacity-70">Infinity Protocol</span>
          <span className="opacity-50">File  Edit  View  Go  Window  Help</span>
        </div>
        <div className="flex items-center gap-3">
          <span>{new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
          <span className="text-[#a855f7]">● Ymir Core: Active</span>
        </div>
      </div>

      {/* Main Content Area */}
      <main className="pt-8 h-full w-full relative">
        {children}
      </main>

      {/* Win11-style Dock */}
      <div className="fixed bottom-4 left-1/2 -translate-x-1/2 h-14 px-2 bg-[#07030a]/60 backdrop-blur-xl border border-[#06b6d4]/20 rounded-2xl flex items-center gap-2 z-50 shadow-2xl">
        <DockItem icon="📁" label="Fafnir" color="#06b6d4" />
        <DockItem icon="🛡️" label="Heimdall" color="#a855f7" />
        <DockItem icon="🧠" label="Odin" color="#06b6d4" />
        <div className="w-px h-6 bg-slate-700 mx-1" />
        <DockItem icon="⚙️" label="System" color="#94a3b8" />
      </div>
    </div>
  );
}

function DockItem({ icon, label, color }: { icon: string, label: string, color: string }) {
  return (
    <div className="group relative w-12 h-12 flex items-center justify-center rounded-xl bg-slate-800/50 hover:bg-slate-700 transition-all duration-200 cursor-pointer hover:-translate-y-2" 
         style={{ borderBottom: `3px solid ${color}` }}>
      <span className="text-2xl">{icon}</span>
      <span className="absolute -top-8 left-1/2 -translate-x-1/2 px-2 py-1 bg-black/80 text-[10px] rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap">
        {label}
      </span>
    </div>
  );
}
