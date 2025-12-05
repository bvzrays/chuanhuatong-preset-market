import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { useState, useEffect } from 'react'
import Layout from './components/Layout'
import HomePage from './pages/HomePage'
import PresetDetailPage from './pages/PresetDetailPage'
import UploadPage from './pages/UploadPage'
import AuthCallback from './pages/AuthCallback'
import { AuthProvider } from './contexts/AuthContext'
import './App.css'

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Layout />}>
            <Route index element={<HomePage />} />
            <Route path="preset/:id" element={<PresetDetailPage />} />
            <Route path="upload" element={<UploadPage />} />
            <Route path="auth/callback" element={<AuthCallback />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  )
}

export default App

