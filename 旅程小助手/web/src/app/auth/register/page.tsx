"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { useAuth } from "@/lib/auth-context";

export default function RegisterPage() {
  const { register } = useAuth();
  const router = useRouter();
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await register(username, email, password);
      router.push("/");
    } catch (err: any) {
      setError(err.message || "注册失败");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-[calc(100vh-4rem)] flex items-center justify-center px-4">
      <div className="w-full max-w-sm">
        <div className="text-center mb-8">
          <div className="font-heading text-3xl font-bold text-wander-dark mb-2">
            Wander<span className="text-wander-green">Wise</span>
          </div>
          <p className="text-sm text-wander-light">免费开始你的旅行规划</p>
        </div>

        <form onSubmit={handleSubmit} className="bg-white rounded-2xl p-8 border-[0.5px] border-wander-border shadow-sm space-y-5">
          <div>
            <label className="block text-sm font-medium text-wander-dark mb-1.5">用户名</label>
            <input
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="w-full px-4 py-2.5 border-[0.5px] border-[#ddd] rounded-xl text-sm focus:outline-none focus:border-wander-green transition-colors bg-cream text-wander-dark placeholder-wander-lighter"
              placeholder="2-50个字符"
              required
              minLength={2}
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-wander-dark mb-1.5">邮箱</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-4 py-2.5 border-[0.5px] border-[#ddd] rounded-xl text-sm focus:outline-none focus:border-wander-green transition-colors bg-cream text-wander-dark placeholder-wander-lighter"
              placeholder="your@email.com"
              required
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-wander-dark mb-1.5">密码</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-4 py-2.5 border-[0.5px] border-[#ddd] rounded-xl text-sm focus:outline-none focus:border-wander-green transition-colors bg-cream text-wander-dark placeholder-wander-lighter"
              placeholder="至少6位"
              required
              minLength={6}
            />
          </div>

          {error && <p className="text-red-500 text-xs">{error}</p>}

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-wander-dark text-cream py-2.5 rounded-xl text-sm font-medium hover:bg-wander-green disabled:opacity-50 transition-colors"
          >
            {loading ? "注册中..." : "免费注册"}
          </button>

          <div className="text-center space-y-1">
            <p className="text-xs text-wander-light">
              已有账号？{" "}
              <Link href="/auth/login" className="text-wander-green font-medium hover:underline">
                去登录
              </Link>
            </p>
            <p className="text-xs text-wander-lighter">✓ 永久免费 &nbsp; ✓ 无广告 &nbsp; ✓ 随时取消</p>
          </div>
        </form>
      </div>
    </div>
  );
}
