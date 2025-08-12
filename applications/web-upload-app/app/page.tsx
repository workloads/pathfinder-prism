import React from 'react'
import FileUpload from './components/FileUpload'
import { Badge } from '@/components/ui/badge'

export default function Home() {
  return (
    <main className="min-h-screen bg-slate-50 p-4">
      <div className="max-w-6xl mx-auto space-y-4">
        {/* Header Section with Technical Specs */}
        <div className="text-center space-y-3">
          <h1 className="text-4xl font-normal text-slate-600 tracking-tight font-condensed leading-relaxed">
            AI Document Pipeline
          </h1>
          <p className="text-base text-slate-500 max-w-2xl mx-auto font-sans leading-relaxed">
            Create your own knowledge bases and organize documents by topic, project, or any criteria you choose
          </p>
          
          {/* Subtle Technical Specifications */}
          <div className="flex flex-wrap justify-center gap-2 text-xs opacity-60">
            <Badge variant="outline" className="px-2 py-1 text-xs bg-white/30 border-slate-200 text-slate-500">
              PDF, DOCX, TXT, MD
            </Badge>
            <Badge variant="outline" className="px-2 py-1 text-xs bg-white/30 border-slate-200 text-slate-500">
              OpenWebUI
            </Badge>
            <Badge variant="outline" className="px-2 py-1 text-xs bg-white/30 border-slate-200 text-slate-500">
              IBM Granite
            </Badge>
            <Badge variant="outline" className="px-2 py-1 text-xs bg-white/30 border-slate-200 text-slate-500">
              DocLings
            </Badge>
            <Badge variant="outline" className="px-2 py-1 text-xs bg-white/30 border-slate-200 text-slate-500">
              Azure
            </Badge>
            <Badge variant="outline" className="px-2 py-1 text-xs bg-white/30 border-slate-200 text-slate-500">
              Nomad
            </Badge>
            <Badge variant="outline" className="px-2 py-1 text-xs bg-white/30 border-slate-200 text-slate-500">
              Vault
            </Badge>
          </div>
        </div>
        
        {/* Main Content - Document Organization as Hero Section */}
        <FileUpload />
      </div>
    </main>
  )
} 