"use client";
import { useState, useEffect } from "react";
import api from "@/lib/api";

interface DailyStat {
  date: string;
  comparisons: number;
  chat_calls: number;
  total_calls: number;
  estimated_tokens: number;
}

interface DashboardData {
  total_users: number;
  total_calls: number;
  today_calls: number;
  total_comparisons: number;
  total_chat_calls: number;
  today_comparisons: number;
  today_chat_calls: number;
  total_tokens: number;
  today_tokens: number;
  estimated_cost: number;
  active_users_10m: number;
  daily_trend: DailyStat[];
  uptime: string;
  db_size: string;
  api_status: { deepseek: boolean; amap: boolean };
}

export default function AdminPage() {
  const [data, setData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [now, setNow] = useState(new Date());

  // 自动刷新
  useEffect(() => { fetchDashboard(); }, []);

  const fetchDashboard = async () => {
    setLoading(true);
    try {
      const res = await api.request("GET", "/admin/dashboard");
      setData(res);
    } catch (e: any) {
      setError(e.message || "加载失败");
    } finally {
      setLoading(false);
    }
  };

  // ── 格式化 ──
  const fmt = (n: number) => n.toLocaleString();
  const costCNY = (cost: number) => `¥${cost.toFixed(4)}`;

  if (loading) {
    return (
      <div className="min-h-screen bg-[#0f0f0f] flex items-center justify-center">
        <div className="w-6 h-6 border-2 border-[#555] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-[#0f0f0f] flex items-center justify-center text-[#aaa] text-sm">
        {error}
      </div>
    );
  }

  const Card = ({ label, value, sub, color }: { label: string; value: string; sub?: string; color?: string }) => (
    <div className="bg-[#1a1a1a] border border-[#2a2a2a] rounded-lg p-5">
      <div className="text-[#888] text-xs uppercase tracking-wider mb-1">{label}</div>
      <div className={`text-2xl font-mono font-bold ${color || "text-white"}`}>{value}</div>
      {sub && <div className="text-[#666] text-xs mt-1">{sub}</div>}
    </div>
  );

  const tdClass = "px-4 py-2 text-xs font-mono text-[#ccc] border-b border-[#222]";
  const thClass = "px-4 py-2 text-xs font-mono text-[#888] uppercase tracking-wider text-left border-b border-[#333]";

  return (
    <div className="min-h-screen bg-[#0f0f0f] text-white">
      {/* Header */}
      <header className="border-b border-[#2a2a2a] px-6 py-3 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <span className="text-sm font-bold text-white tracking-wide">WanderWise</span>
          <span className="text-[#555] text-xs">/ admin</span>
        </div>
        <div className="flex items-center gap-4">
          <span className="text-[#666] text-xs">{now.toLocaleString("zh-CN")}</span>
          <span className="text-[#666] text-xs">运行 {data?.uptime || "—"}</span>
          <button
            onClick={fetchDashboard}
            className="text-xs text-[#888] hover:text-white border border-[#333] px-3 py-1 rounded transition-colors"
          >
            刷新
          </button>
        </div>
      </header>

      <div className="max-w-6xl mx-auto p-6 space-y-6">
        {/* Summary Cards */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <Card label="注册用户" value={fmt(data?.total_users || 0)} sub={`最后更新 ${now.toLocaleTimeString("zh-CN")}`} color="text-emerald-400" />
          <Card label="今日 API 调用" value={fmt(data?.today_calls || 0)} sub={`对比 ${fmt(data?.today_comparisons || 0)} / 聊天 ${fmt(data?.today_chat_calls || 0)}`} color="text-sky-400" />
          <Card label="Token 消耗（累计）" value={fmt(data?.total_tokens || 0)} sub={`≈ ${costCNY(data?.estimated_cost || 0)}`} color="text-amber-400" />
          <Card label="10 分钟内活跃" value={fmt(data?.active_users_10m || 0)} sub="独立设备" color="text-violet-400" />
        </div>

        {/* System Status */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="bg-[#1a1a1a] border border-[#2a2a2a] rounded-lg p-4">
            <div className="text-[#888] text-xs uppercase tracking-wider mb-1">累计调用</div>
            <div className="text-lg font-mono font-bold text-white">{fmt(data?.total_calls || 0)}</div>
            <div className="text-[#666] text-xs mt-1">对比 {fmt(data?.total_comparisons || 0)} · 聊天 {fmt(data?.total_chat_calls || 0)}</div>
          </div>
          <div className="bg-[#1a1a1a] border border-[#2a2a2a] rounded-lg p-4">
            <div className="text-[#888] text-xs uppercase tracking-wider mb-1">DeepSeek</div>
            <div className="flex items-center gap-2 mt-2">
              <span className={`w-2 h-2 rounded-full ${data?.api_status?.deepseek ? "bg-emerald-500" : "bg-red-500"}`} />
              <span className="text-sm text-white font-mono">{data?.api_status?.deepseek ? "已连接" : "未配置"}</span>
            </div>
          </div>
          <div className="bg-[#1a1a1a] border border-[#2a2a2a] rounded-lg p-4">
            <div className="text-[#888] text-xs uppercase tracking-wider mb-1">高德地图</div>
            <div className="flex items-center gap-2 mt-2">
              <span className={`w-2 h-2 rounded-full ${data?.api_status?.amap ? "bg-emerald-500" : "bg-red-500"}`} />
              <span className="text-sm text-white font-mono">{data?.api_status?.amap ? "已连接" : "未配置"}</span>
            </div>
          </div>
          <div className="bg-[#1a1a1a] border border-[#2a2a2a] rounded-lg p-4">
            <div className="text-[#888] text-xs uppercase tracking-wider mb-1">数据库</div>
            <div className="text-lg font-mono font-bold text-white">{data?.db_size || "—"}</div>
            <div className="text-[#666] text-xs mt-1">SQLite · 运行 {data?.uptime || "—"}</div>
          </div>
        </div>

        {/* Daily Trend Table */}
        <div className="bg-[#1a1a1a] border border-[#2a2a2a] rounded-lg overflow-hidden">
          <div className="px-5 py-3 border-b border-[#2a2a2a]">
            <h2 className="text-sm font-bold text-white">近 7 天调用趋势</h2>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="bg-[#151515]">
                  <th className={thClass}>日期</th>
                  <th className={thClass}>对比</th>
                  <th className={thClass}>聊天</th>
                  <th className={thClass}>合计</th>
                  <th className={thClass}>Token 估算</th>
                  <th className={thClass}>趋势</th>
                </tr>
              </thead>
              <tbody>
                {data?.daily_trend?.map((d) => {
                  const max = Math.max(...(data?.daily_trend || []).map((x) => x.total_calls), 1);
                  const barWidth = d.total_calls > 0 ? Math.round((d.total_calls / max) * 100) : 0;
                  return (
                    <tr key={d.date} className="hover:bg-[#222] transition-colors">
                      <td className={tdClass}>{d.date.slice(5)}</td>
                      <td className={tdClass}>{d.comparisons}</td>
                      <td className={tdClass}>{d.chat_calls}</td>
                      <td className={`${tdClass} font-bold text-white`}>{d.total_calls}</td>
                      <td className={tdClass}>{fmt(d.estimated_tokens)}</td>
                      <td className={`${tdClass} w-32`}>
                        <div className="w-full h-2 bg-[#333] rounded-full overflow-hidden">
                          <div
                            className="h-full bg-sky-500 rounded-full transition-all"
                            style={{ width: `${barWidth}%` }}
                          />
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>

        {/* Footer */}
        <div className="text-center text-[#444] text-xs">
          WanderWise Admin v2.0.0 · 数据每 30 秒自动刷新
        </div>
      </div>
    </div>
  );
}
