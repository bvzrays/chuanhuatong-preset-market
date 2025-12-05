import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import axios from 'axios'
import { useAuth } from '../contexts/AuthContext'

interface Preset {
  id: number
  name: string
  slug: string
  description?: string
  preview_image?: string
  author: {
    id: number
    username: string
    avatar_url: string
  }
  download_count: number
  like_count: number
  comment_count: number
  is_liked: boolean
  created_at: string
}

export default function HomePage() {
  const [presets, setPresets] = useState<Preset[]>([])
  const [loading, setLoading] = useState(true)
  const [sort, setSort] = useState('latest')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const [total, setTotal] = useState(0)
  const { token, isAuthenticated } = useAuth()

  const fetchPresets = async () => {
    setLoading(true)
    try {
      const response = await axios.get('/api/presets', {
        params: { page, sort, search: search || undefined },
        headers: token ? { Authorization: `Bearer ${token}` } : {},
      })
      setPresets(response.data.items)
      setTotal(response.data.total)
    } catch (error) {
      console.error('获取预设列表失败:', error)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchPresets()
  }, [page, sort, search])

  const handleLike = async (presetId: number) => {
    if (!isAuthenticated) {
      alert('请先登录')
      return
    }
    try {
      const response = await axios.post(
        `/api/presets/${presetId}/like`,
        {},
        { headers: { Authorization: `Bearer ${token}` } }
      )
      setPresets((prev) =>
        prev.map((p) =>
          p.id === presetId
            ? { ...p, is_liked: response.data.liked, like_count: response.data.like_count }
            : p
        )
      )
    } catch (error) {
      console.error('点赞失败:', error)
    }
  }

  return (
    <div>
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-4">预设市场</h1>
        <div className="flex flex-col sm:flex-row gap-4">
          <input
            type="text"
            placeholder="搜索预设..."
            value={search}
            onChange={(e) => {
              setSearch(e.target.value)
              setPage(1)
            }}
            className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
          />
          <select
            value={sort}
            onChange={(e) => {
              setSort(e.target.value)
              setPage(1)
            }}
            className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500"
          >
            <option value="latest">最新</option>
            <option value="popular">最热</option>
            <option value="likes">最多点赞</option>
          </select>
        </div>
      </div>

      {loading ? (
        <div className="text-center py-12">
          <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
          <p className="mt-2 text-gray-500">加载中...</p>
        </div>
      ) : presets.length === 0 ? (
        <div className="text-center py-12">
          <p className="text-gray-500">暂无预设</p>
        </div>
      ) : (
        <>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {presets.map((preset) => (
              <div
                key={preset.id}
                className="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow"
              >
                <Link to={`/preset/${preset.id}`}>
                  {preset.preview_image ? (
                    <img
                      src={preset.preview_image.startsWith('http') ? preset.preview_image : `http://localhost:8000${preset.preview_image}`}
                      alt={preset.name}
                      className="w-full h-48 object-cover"
                    />
                  ) : (
                    <div className="w-full h-48 bg-gray-200 flex items-center justify-center">
                      <span className="text-gray-400">无预览图</span>
                    </div>
                  )}
                </Link>
                <div className="p-4">
                  <Link to={`/preset/${preset.id}`}>
                    <h3 className="text-lg font-semibold text-gray-900 mb-2 hover:text-primary-600">
                      {preset.name}
                    </h3>
                  </Link>
                  {preset.description && (
                    <p className="text-sm text-gray-600 mb-3 line-clamp-2">
                      {preset.description}
                    </p>
                  )}
                  <div className="flex items-center justify-between text-sm text-gray-500">
                    <div className="flex items-center space-x-4">
                      <span>👤 {preset.author.username}</span>
                      <span>⬇️ {preset.download_count}</span>
                      <span>💬 {preset.comment_count}</span>
                    </div>
                    <button
                      onClick={(e) => {
                        e.preventDefault()
                        handleLike(preset.id)
                      }}
                      className={`${
                        preset.is_liked ? 'text-red-500' : 'text-gray-400'
                      } hover:text-red-500`}
                    >
                      ❤️ {preset.like_count}
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
          <div className="mt-8 flex justify-center">
            <div className="flex space-x-2">
              <button
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                disabled={page === 1}
                className="px-4 py-2 border rounded-lg disabled:opacity-50"
              >
                上一页
              </button>
              <span className="px-4 py-2">
                第 {page} 页 / 共 {Math.ceil(total / 20)} 页
              </span>
              <button
                onClick={() => setPage((p) => p + 1)}
                disabled={page >= Math.ceil(total / 20)}
                className="px-4 py-2 border rounded-lg disabled:opacity-50"
              >
                下一页
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  )
}

