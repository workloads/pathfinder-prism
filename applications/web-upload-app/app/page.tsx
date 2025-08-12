import React from 'react'
import FileUpload from './components/FileUpload'

export default function Home() {
  return (
    <main className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 p-8">
      <div className="max-w-4xl mx-auto">
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">
            Azure Nomad Workshop
          </h1>
          <p className="text-xl text-gray-600">
            Upload documents to process with AI
          </p>
        </div>
        
        <div className="bg-white rounded-lg shadow-lg p-8">
          <FileUpload />
        </div>
        
        <div className="mt-8 text-center text-gray-500">
          <p>Documents will be processed and added to the OpenWebUI knowledge base</p>
        </div>
      </div>
    </main>
  )
} 