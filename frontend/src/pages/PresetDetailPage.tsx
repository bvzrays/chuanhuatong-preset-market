import { useState, useEffect } from 'react'
import { useParams, Link, useNavigate } from 'react-router-dom'
import axios from 'axios'
import { useAuth } from '../contexts/AuthContext'

interface Preset {
  id: number
  name: string
  slug: string
  description?: string
  layout: any
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
  is_owner: boolean
  created_at: string
}

interface Comment {
  id: number
  content: string
  author: {
    id: number
    username: string
    avatar_url: string
  }
  created_at: string
}

export default function PresetDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const [preset, setPreset] = useState<Preset | null>(null)
  const [comments, setComments] = useState<Comment[]>([])
  const [loading, setLoading] = useState(true)
  const [commentText, setCommentText] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const { token, isAuthenticated, user } = useAuth()

  useEffect(() => {
    fetchPreset()
    fetchComments()
  }, [id])

  const fetchPreset = async () => {
    try {
      const response = await axios.get(`/api/presets/${id}`, {
        headers: token ? { Authorization: `Bearer ${token}` } : {},
      })
      setPreset(response.data)
    } catch (error) {
      console.error('获取预设详情失败:', error)
    } finally {
      setLoading(false)
    }
  }

  const fetchComments = async () => {
    try {
      const response = await axios.get(`/api/comments/preset/${id}`)
      setComments(response.data.items)
    } catch (error) {
      console.error('获取评论失败:', error)
    }
  }

  const handleLike = async () => {
    if (!isAuthenticated) {
      alert('请先登录')
      return
    }
    try {
      const response = await axios.post(
        `/api/presets/${preset!.id}/like`,
        {},
        { headers: { Authorization: `Bearer ${token}` } }
      )
      setPreset((p) =>
        p
          ? { ...p, is_liked: response.data.liked, like_count: response.data.like_count }
          : null
      )
    } catch (error) {
      console.error('点赞失败:', error)
    }
  }

  const handleDownload = async () => {
    try {
      const response = await axios.get(`/api/presets/${preset!.id}/download`, {
        responseType: 'json',
      })
      if (response.data.path) {
        alert(`预设已保存到: ${response.data.path}`)
      } else {
        // 下载 JSON 文件
        const blob = new Blob([JSON.stringify(response.data.preset, null, 2)], {
          type: 'application/json',
        })
        const url = URL.createObjectURL(blob)
        const a = document.createElement('a')
        a.href = url
        a.download = `${preset!.slug}.json`
        a.click()
        URL.revokeObjectURL(url)
      }
      fetchPreset() // 刷新下载计数
    } catch (error) {
      console.error('下载失败:', error)
    }
  }

  const handleSubmitComment = async () => {
    if (!isAuthenticated) {
      alert('请先登录')
      return
    }
    if (!commentText.trim()) {
      return
    }
    setSubmitting(true)
    try {
      await axios.post(
        `/api/comments/preset/${id}`,
        { content: commentText },
        { headers: { Authorization: `Bearer ${token}` } }
      )
      setCommentText('')
      fetchComments()
      fetchPreset() // 刷新评论计数
    } catch (error) {
      console.error('提交评论失败:', error)
    } finally {
      setSubmitting(false)
    }
  }

  const handleDelete = async () => {
    if (!confirm('确定要删除这个预设吗？')) {
      return
    }
    try {
      await axios.delete(`/api/presets/${preset!.id}`, {
        headers: { Authorization: `Bearer ${token}` },
      })
      navigate('/')
    } catch (error) {
      console.error('删除失败:', error)
    }
  }

  if (loading) {
    return (
      <div className="text-center py-12">
        <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
        <p className="mt-2 text-gray-500">加载中...</p>
      </div>
    )
  }

  if (!preset) {
    return <div className="text-center py-12">预设不存在</div>
  }

  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg shadow-md overflow-hidden">
        {preset.preview_image && (
          <img
            src={preset.preview_image.startsWith('http') ? preset.preview_image : `http://localhost:8000${preset.preview_image}`}
            alt={preset.name}
            className="w-full h-64 object-cover"
          />
        )}
        <div className="p-6">
          <div className="flex items-start justify-between mb-4">
            <div>
              <h1 className="text-3xl font-bold text-gray-900 mb-2">{preset.name}</h1>
              <div className="flex items-center space-x-4 text-sm text-gray-500">
                <div className="flex items-center space-x-2">
                  <img
                    src={preset.author.avatar_url}
                    alt={preset.author.username}
                    className="w-6 h-6 rounded-full"
                  />
                  <span>{preset.author.username}</span>
                </div>
                <span>⬇️ {preset.download_count} 次下载</span>
                <span>💬 {preset.comment_count} 条评论</span>
                <span>📅 {new Date(preset.created_at).toLocaleDateString('zh-CN')}</span>
              </div>
            </div>
            <div className="flex space-x-2">
              <button
                onClick={handleLike}
                className={`px-4 py-2 rounded-lg ${
                  preset.is_liked
                    ? 'bg-red-100 text-red-600'
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                }`}
              >
                ❤️ {preset.like_count}
              </button>
              <button
                onClick={handleDownload}
                className="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700"
              >
                下载预设
              </button>
              {preset.is_owner && (
                <button
                  onClick={handleDelete}
                  className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
                >
                  删除
                </button>
              )}
            </div>
          </div>
          {preset.description && (
            <p className="text-gray-700 mb-6 whitespace-pre-wrap">{preset.description}</p>
          )}
        </div>
      </div>

      <div className="mt-8 bg-white rounded-lg shadow-md p-6">
        <h2 className="text-xl font-bold text-gray-900 mb-4">评论 ({comments.length})</h2>
        {isAuthenticated ? (
          <div className="mb-6">
            <textarea
              value={commentText}
              onChange={(e) => setCommentText(e.target.value)}
              placeholder="写下你的评论..."
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              rows={3}
            />
            <button
              onClick={handleSubmitComment}
              disabled={submitting || !commentText.trim()}
              className="mt-2 px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 disabled:opacity-50"
            >
              {submitting ? '提交中...' : '提交评论'}
            </button>
          </div>
        ) : (
          <p className="text-gray-500 mb-4">
            请<Link to="/api/auth/github" className="text-primary-600 hover:underline">登录</Link>
            后发表评论
          </p>
        )}
        <div className="space-y-4">
          {comments.length === 0 ? (
            <p className="text-gray-500 text-center py-4">暂无评论</p>
          ) : (
            comments.map((comment) => (
              <div key={comment.id} className="border-b border-gray-200 pb-4">
                <div className="flex items-center space-x-3 mb-2">
                  <img
                    src={comment.author.avatar_url}
                    alt={comment.author.username}
                    className="w-8 h-8 rounded-full"
                  />
                  <span className="font-semibold text-gray-900">
                    {comment.author.username}
                  </span>
                  <span className="text-sm text-gray-500">
                    {new Date(comment.created_at).toLocaleString('zh-CN')}
                  </span>
                </div>
                <p className="text-gray-700 whitespace-pre-wrap">{comment.content}</p>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  )
}

