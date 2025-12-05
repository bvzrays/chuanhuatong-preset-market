import { useEffect } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'

export default function AuthCallback() {
  const [searchParams] = useSearchParams()
  const navigate = useNavigate()
  const { setAuthToken } = useAuth()

  useEffect(() => {
    const token = searchParams.get('token')
    const error = searchParams.get('error')

    if (error) {
      alert(`登录失败: ${error}`)
      navigate('/')
      return
    }

    if (token) {
      setAuthToken(token)
      navigate('/')
    } else {
      navigate('/')
    }
  }, [searchParams, navigate, setAuthToken])

  return (
    <div className="text-center py-12">
      <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
      <p className="mt-2 text-gray-500">正在登录...</p>
    </div>
  )
}

