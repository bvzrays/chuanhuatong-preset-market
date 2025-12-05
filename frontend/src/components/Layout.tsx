import { Outlet, Link, useNavigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'

export default function Layout() {
  const { user, logout, isAuthenticated } = useAuth()
  const navigate = useNavigate()

  return (
    <div className="min-h-screen bg-gray-50">
      <nav className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex items-center">
              <Link to="/" className="text-2xl font-bold text-primary-600">
                传话筒预设市场
              </Link>
            </div>
            <div className="flex items-center space-x-4">
              <Link
                to="/"
                className="text-gray-700 hover:text-primary-600 px-3 py-2 rounded-md text-sm font-medium"
              >
                首页
              </Link>
              {isAuthenticated ? (
                <>
                  <Link
                    to="/upload"
                    className="text-gray-700 hover:text-primary-600 px-3 py-2 rounded-md text-sm font-medium"
                  >
                    上传预设
                  </Link>
                  <div className="flex items-center space-x-3">
                    <img
                      src={user?.avatar_url}
                      alt={user?.username}
                      className="w-8 h-8 rounded-full"
                    />
                    <span className="text-sm text-gray-700">{user?.username}</span>
                    <button
                      onClick={logout}
                      className="text-gray-700 hover:text-primary-600 px-3 py-2 rounded-md text-sm font-medium"
                    >
                      登出
                    </button>
                  </div>
                </>
              ) : (
                <button
                  onClick={() => navigate('/api/auth/github')}
                  className="bg-primary-600 text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-primary-700"
                >
                  GitHub 登录
                </button>
              )}
            </div>
          </div>
        </div>
      </nav>
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <Outlet />
      </main>
      <footer className="bg-white border-t mt-12">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <p className="text-center text-gray-500 text-sm">
            © 2024 传话筒预设市场. 使用 GitHub OAuth 登录.
          </p>
        </div>
      </footer>
    </div>
  )
}

