"use client";
import { useState, useRef, useEffect } from "react";
import api from "@/lib/api";
import {
  IconArrowRight,
  IconSparkles,
  IconCheck,
  IconClock,
  IconX,
  IconDog,
} from "@tabler/icons-react";

const PURPOSE_OPTIONS = [
  { value: "leisure", label: "休闲度假" },
  { value: "culture", label: "文化历史" },
  { value: "food", label: "美食之旅" },
  { value: "adventure", label: "探险户外" },
  { value: "honeymoon", label: "蜜月浪漫" },
  { value: "family", label: "亲子家庭" },
  { value: "shopping", label: "购物血拼" },
];
const WITH_WHO_OPTIONS = [
  { value: "alone", label: "独自旅行" },
  { value: "couple", label: "情侣/伴侣" },
  { value: "family", label: "带孩子/家人" },
  { value: "friends", label: "和朋友一起" },
];
const BUDGET_OPTIONS = [
  { value: "low", label: "经济省钱" },
  { value: "medium", label: "适中" },
  { value: "high", label: "高端舒适" },
];

interface StreamRow {
  dimension: string;
  values: string[];
}
interface ScoreEntry {
  destination: string;
  overall: number;
  details: Record<string, number>;
}
interface HistoryItem {
  id: string;
  destinations: string[];
  summary: string;
  created_at: string;
  chosen?: string;
}

export default function ComparePage() {
  const [destinations, setDestinations] = useState<string[]>(["", ""]);
  const [purpose, setPurpose] = useState("leisure");
  const [withWho, setWithWho] = useState("alone");
  const [budget, setBudget] = useState("medium");
  const [days, setDays] = useState(3);
  const [withPet, setWithPet] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [statusText, setStatusText] = useState("");
  const [rows, setRows] = useState<StreamRow[]>([]);
  const [recommendation, setRecommendation] = useState("");
  const [verdict, setVerdict] = useState("");
  const [scores, setScores] = useState<ScoreEntry[]>([]);
  const [weather, setWeather] = useState<any[]>([]);
  const [complete, setComplete] = useState(false);
  const [history, setHistory] = useState<HistoryItem[]>([]);
  const [showHistory, setShowHistory] = useState(false);
  const [historyDetail, setHistoryDetail] = useState<any>(null);
  const resultRef = useRef<HTMLDivElement>(null);

  const deviceId =
    "web-" +
    (typeof window !== "undefined"
      ? localStorage.getItem("device_id") ||
        Math.random().toString(36).slice(2)
      : "unknown");

  useEffect(() => {
    if (typeof window !== "undefined" && !localStorage.getItem("device_id")) {
      localStorage.setItem("device_id", deviceId);
    }
    loadHistory();
  }, []);

  const loadHistory = async () => {
    try {
      const data = await api.getCompareHistory(deviceId);
      if (data?.items?.length > 0) setHistory(data.items);
    } catch (e) {
      console.warn("[对比] 加载历史失败:", e);
    }
  };

  const addDestination = () => {
    if (destinations.length < 5) setDestinations([...destinations, ""]);
  };
  const removeDestination = (i: number) => {
    if (destinations.length > 2)
      setDestinations(destinations.filter((_, idx) => idx !== i));
  };
  const updateDestination = (i: number, v: string) => {
    const newDests = [...destinations];
    newDests[i] = v;
    setDestinations(newDests);
  };

  const handleCompare = async () => {
    const validDests = destinations.filter((d) => d.trim());
    if (validDests.length < 2) {
      setError("请至少输入 2 个目的地");
      return;
    }
    setError("");
    setLoading(true);
    setRows([]);
    setRecommendation("");
    setVerdict("");
    setScores([]);
    setWeather([]);
    setComplete(false);
    setStatusText("正在连接 AI...");

    const params = {
      destinations: validDests,
      travel_days: days,
      budget_level: budget,
      purpose,
      with_who: withWho,
      with_pet: withPet,
      device_id: deviceId,
    };

    try {
      const response = (await api.compareDestinationsStream(params)) as Response;
      const reader = response.body?.getReader();
      if (!reader) throw new Error("无法读取流");

      const decoder = new TextDecoder();
      let buffer = "";

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split("\n");
        buffer = lines.pop() || "";

        for (const line of lines) {
          if (!line.startsWith("data: ")) continue;
          const data = line.slice(6).trim();
          if (!data) continue;
          try {
            const event = JSON.parse(data);
            switch (event.type) {
              case "status":
                setStatusText(event.text);
                break;
              case "row":
                setRows((prev) => [...prev, event.data]);
                setTimeout(() => {
                  resultRef.current?.scrollIntoView({ behavior: "smooth" });
                }, 50);
                break;
              case "complete":
                if (event.data) {
                  if (event.data.recommendation)
                    setRecommendation(event.data.recommendation);
                  if (event.data.verdict) setVerdict(event.data.verdict);
                  if (event.data.scores) setScores(event.data.scores);
                }
                setComplete(true);
                setLoading(false);
                setStatusText("");
                loadHistory(); // 刷新历史
                break;
              case "weather":
                setWeather(event.data || []);
                break;
              case "error":
                setError(event.text || "AI 生成出错");
                setLoading(false);
                break;
            }
          } catch {
            // ignore parse errors for incomplete chunks
          }
        }
      }
    } catch (e: any) {
      if (e.name !== "AbortError") {
        setError(e.message || "对比生成失败");
      }
      setLoading(false);
    }
  };

  const selectClass =
    "w-full px-4 py-2.5 border-[0.5px] border-[#ddd] rounded-xl text-sm focus:outline-none focus:border-wander-green transition-colors bg-cream text-wander-dark";
  const inputClass =
    "flex-1 px-4 py-2.5 border-[0.5px] border-[#ddd] rounded-xl text-sm focus:outline-none focus:border-wander-green transition-colors bg-cream text-wander-dark placeholder-wander-lighter";

  const sp = <span className="w-5 h-5 border-2 border-cream border-t-transparent rounded-full animate-spin inline-block" />;

  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-8 py-8 space-y-8">
      {/* Header */}
      <div className="text-center">
        <div className="inline-flex items-center gap-1.5 bg-wander-green-light text-wander-green text-xs font-medium px-3.5 py-1.5 rounded-full mb-4">
          <IconSparkles size={14} />
          AI 驱动
        </div>
        <h1 className="font-heading text-3xl md:text-4xl font-bold text-wander-dark mb-3">
          多维度目的地对比
        </h1>
        <p className="text-wander-light text-sm max-w-lg mx-auto">
          输入目的地和你的旅行画像，AI 实时从预算、季节、美食、交通等维度逐条分析
        </p>
      </div>

      {/* Form */}
      <div className="bg-white rounded-2xl p-6 md:p-8 border-[0.5px] border-wander-border shadow-sm space-y-6">
        <div>
          <label className="block text-sm font-medium text-wander-dark mb-2">
            目的地 <span className="text-wander-lighter font-normal">（2-5 个）</span>
          </label>
          {destinations.map((d, i) => (
            <div key={i} className="flex gap-2 mb-2.5">
              <input
                value={d}
                onChange={(e) => updateDestination(i, e.target.value)}
                placeholder={`目的地 ${i + 1}（如：成都）`}
                className={inputClass}
                disabled={loading}
              />
              {destinations.length > 2 && (
                <button
                  onClick={() => removeDestination(i)}
                  className="text-wander-lighter hover:text-red-400 px-2 text-sm"
                  disabled={loading}
                >
                  ✕
                </button>
              )}
            </div>
          ))}
          {destinations.length < 5 && (
            <button
              onClick={addDestination}
              className="text-wander-green text-sm mt-1 hover:underline disabled:opacity-30"
              disabled={loading}
            >
              + 添加目的地
            </button>
          )}
        </div>

        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          {[
            { label: "旅行目的", val: purpose, set: setPurpose, opts: PURPOSE_OPTIONS },
            { label: "和谁去", val: withWho, set: setWithWho, opts: WITH_WHO_OPTIONS },
            { label: "预算水平", val: budget, set: setBudget, opts: BUDGET_OPTIONS },
            { label: "天数", val: days, set: setDays, type: "number", min: 1, max: 30, opts: null },
          ].map((f: any) => (
            <div key={f.label}>
              <label className="block text-sm font-medium text-wander-dark mb-1.5">
                {f.label}
              </label>
              {f.opts ? (
                <select
                  value={f.val}
                  onChange={(e) => f.set(e.target.value)}
                  className={selectClass}
                  disabled={loading}
                >
                  {f.opts.map((o: any) => (
                    <option key={o.value} value={o.value}>
                      {o.label}
                    </option>
                  ))}
                </select>
              ) : (
                <input
                  type={f.type}
                  min={f.min}
                  max={f.max}
                  value={f.val}
                  onChange={(e) => f.set(Number(e.target.value))}
                  className={selectClass}
                  disabled={loading}
                />
              )}
            </div>
          ))}
        </div>

        {/* 宠物友好 */}
        <label className="flex items-center gap-2.5 cursor-pointer select-none">
          <button
            type="button"
            onClick={() => setWithPet(!withPet)}
            className={`w-10 h-5 rounded-full transition-colors relative ${
              withPet ? "bg-wander-green" : "bg-[#ddd]"
            }`}
            disabled={loading}
          >
            <span
              className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow-sm transition-transform ${
                withPet ? "translate-x-5" : "translate-x-0.5"
              }`}
            />
          </button>
          <span className={`text-sm ${withPet ? "text-wander-dark font-medium" : "text-wander-lighter"}`}>
            <IconDog size={16} className="inline mr-1" />
            带宠物出行
          </span>
        </label>

        {error && <p className="text-red-500 text-sm">{error}</p>}

        <button
          onClick={handleCompare}
          disabled={loading}
          className="w-full bg-wander-dark text-cream py-3 rounded-xl text-sm font-medium hover:bg-wander-green disabled:opacity-50 transition-colors flex items-center justify-center gap-2"
        >
          {loading ? (
            <>{sp} {statusText || "AI 分析中..."}</>
          ) : (
            <>开始多维度对比 <IconArrowRight size={16} /></>
          )}
        </button>
      </div>

      {/* ── Streaming / Result Area ── */}
      {(loading || complete || rows.length > 0) && (
        <div ref={resultRef} className="space-y-6">
          {/* Loading indicator */}
          {loading && !complete && (
            <div className="bg-wander-green-light rounded-2xl p-5 border border-wander-green/20">
              <div className="flex items-center gap-3">
                <span className="w-6 h-6 border-2 border-wander-green border-t-transparent rounded-full animate-spin shrink-0" />
                <div>
                  <p className="text-sm font-medium text-wander-green">
                    AI 正在多维度对比分析...
                  </p>
                  <p className="text-xs text-wander-gray mt-0.5">
                    已生成 {rows.length} 个维度，逐条展示中
                  </p>
                </div>
              </div>
            </div>
          )}

          {/* Complete banner */}
          {complete && (
            <div className="bg-wander-green/10 rounded-2xl p-4 border border-wander-green/20 flex items-center gap-3">
              <IconCheck size={20} className="text-wander-green shrink-0" />
              <p className="text-sm text-wander-dark font-medium">
                对比分析完成！共分析 <span className="text-wander-green">{rows.length}</span> 个维度
              </p>
            </div>
          )}

          {/* ── 多维度对比表格 ── */}
          {rows.length > 0 && (
            <div className="bg-white rounded-2xl border-[0.5px] border-wander-border overflow-hidden">
              <div className="p-4 md:p-5 border-b-[0.5px] border-wander-border">
                <h2 className="font-semibold text-sm text-wander-dark flex items-center gap-2">
                  📋 多维度对比
                  {!complete && loading && (
                    <span className="text-xs text-wander-lighter font-normal">
                      （实时更新中...）
                    </span>
                  )}
                </h2>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="bg-cream">
                      <th className="text-left px-4 py-3 font-semibold text-wander-dark text-xs uppercase tracking-wider w-36">
                        维度
                      </th>
                      {destinations
                        .filter((d) => d.trim())
                        .map((d, i) => (
                          <th
                            key={i}
                            className="text-left px-4 py-3 font-semibold text-wander-dark text-xs uppercase tracking-wider"
                          >
                            {d.trim()}
                          </th>
                        ))}
                    </tr>
                  </thead>
                  <tbody>
                    {rows.map((row, i) => (
                      <tr
                        key={i}
                        className="border-t-[0.5px] border-wander-border hover:bg-cream/50 transition-colors"
                      >
                        <td className="px-4 py-3 font-medium text-wander-dark text-xs">
                          {row.dimension}
                        </td>
                        {row.values.map((v, j) => (
                          <td key={j} className="px-4 py-3 text-wander-gray text-xs leading-relaxed">
                            {v}
                          </td>
                        ))}
                      </tr>
                    ))}
                    {/* Skeleton rows */}
                    {loading &&
                      !complete &&
                      Array.from({ length: 2 }).map((_, i) => (
                        <tr key={`sk-${i}`} className="border-t-[0.5px] border-wander-border">
                          <td className="px-4 py-3">
                            <div className="h-3 w-20 bg-cream rounded animate-pulse" />
                          </td>
                          {destinations.filter((d) => d.trim()).map((_, j) => (
                            <td key={j} className="px-4 py-3">
                              <div className="h-3 w-24 bg-cream rounded animate-pulse" />
                            </td>
                          ))}
                        </tr>
                      ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* ── 推荐结论 ── */}
          {verdict && (
            <div className="bg-gradient-to-br from-wander-dark to-[#2a2a27] rounded-2xl p-6 md:p-8 text-cream">
              <h2 className="font-heading text-xl font-bold mb-3 flex items-center gap-2">
                <span className="text-wander-green-bright">🏆</span>
                <span>推荐结论</span>
              </h2>
              <p className="text-lg md:text-xl mb-2 font-medium">{verdict}</p>
              {recommendation && (
                <p className="text-wander-light text-sm leading-relaxed">
                  {recommendation}
                </p>
              )}
            </div>
          )}

          {/* ── 评分卡片 ── */}
          {scores.length > 0 && (
            <div>
              <h2 className="font-semibold text-sm text-wander-dark mb-3 flex items-center gap-2">
                ⭐ 综合评分
              </h2>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {scores.map((sc, i) => (
                  <div key={i} className="bg-white rounded-xl p-5 border-[0.5px] border-wander-border">
                    <h3 className="font-heading font-bold text-lg text-wander-dark mb-1">
                      {sc.destination}
                    </h3>
                    <div className="font-heading text-3xl font-bold text-wander-green mb-4">
                      {sc.overall?.toFixed(1)} / 5.0
                    </div>
                    {sc.details &&
                      Object.entries(sc.details).map(([k, v]: any) => (
                        <div key={k} className="flex items-center justify-between text-sm py-1.5">
                          <span className="text-wander-gray text-xs">{k}</span>
                          <div className="flex items-center gap-2">
                            <div className="w-20 h-1.5 bg-cream rounded-full overflow-hidden">
                              <div className="h-full bg-wander-green rounded-full" style={{ width: `${(v / 5) * 100}%` }} />
                            </div>
                            <span className="text-wander-lighter text-xs w-5 text-right">{v}</span>
                          </div>
                        </div>
                      ))}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* ── 天气 ── */}
          {weather.length > 0 && (
            <div className="bg-white rounded-2xl p-6 border-[0.5px] border-wander-border">
              <h2 className="font-semibold text-wander-dark mb-4 flex items-center gap-2 text-sm">
                🌤️ 实时天气
              </h2>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                {weather.map((w: any, i: number) => (
                  <div key={i} className="flex items-center gap-3 p-3 bg-cream rounded-xl">
                    <span className="text-2xl">
                      {w.weather?.includes("晴") ? "☀️" : w.weather?.includes("雨") ? "🌧️" : "☁️"}
                    </span>
                    <div>
                      <p className="font-medium text-sm text-wander-dark">{w.city}</p>
                      <p className="text-xs text-wander-light">{w.weather} {w.temperature}°C</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* ── 历史对比 ── */}
      {history.length > 0 && (
        <div className="bg-white rounded-2xl border-[0.5px] border-wander-border overflow-hidden">
          <button
            onClick={() => setShowHistory(!showHistory)}
            className="w-full flex items-center justify-between p-4 md:p-5 hover:bg-cream/50 transition-colors"
          >
            <div className="flex items-center gap-2">
              <IconClock size={16} className="text-wander-light" />
              <h2 className="font-semibold text-sm text-wander-dark">历史对比记录</h2>
              <span className="text-xs text-wander-lighter bg-cream px-2 py-0.5 rounded-full">
                {history.length}
              </span>
            </div>
            <span className={`text-wander-light text-sm transition-transform ${showHistory ? "rotate-180" : ""}`}>
              ▼
            </span>
          </button>

          {showHistory && (
            <div className="border-t-[0.5px] border-wander-border divide-y-[0.5px] divide-wander-border">
              {history.map((h) => (
                <div
                  key={h.id}
                  className="p-4 hover:bg-cream/30 transition-colors cursor-pointer"
                  onClick={async () => {
                    try {
                      const detail = await api.getCompareHistoryDetail(h.id);
                      setHistoryDetail(detail);
                    } catch (e) {
                      console.warn("[对比] 加载历史明细失败:", e);
                    }
                  }}
                >
                  <div className="flex items-center gap-2 mb-1">
                    {h.destinations.map((d, i) => (
                      <span key={d}>
                        <span className="text-sm font-medium text-wander-dark">{d}</span>
                        {i < h.destinations.length - 1 && (
                          <span className="text-wander-lighter mx-1">vs</span>
                        )}
                      </span>
                    ))}
                    <span className="text-xs text-wander-light ml-auto">查看明细 →</span>
                  </div>
                  {h.chosen && (
                    <p className="text-xs text-wander-green">
                      上次选择：{h.chosen}
                    </p>
                  )}
                  <p className="text-xs text-wander-lighter mt-1">
                    {h.created_at?.slice(0, 10)}
                  </p>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* ── 历史对比明细 Modal ── */}
      {historyDetail && (
        <div
          className="fixed inset-0 z-50 bg-black/30 flex items-center justify-center p-4"
          onClick={() => setHistoryDetail(null)}
        >
          <div
            className="bg-white rounded-2xl w-full max-w-3xl max-h-[80vh] flex flex-col overflow-hidden"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between p-5 border-b-[0.5px] border-wander-border shrink-0">
              <h2 className="font-heading font-bold text-lg text-wander-dark">
                对比明细
              </h2>
              <button
                onClick={() => setHistoryDetail(null)}
                className="text-wander-lighter hover:text-wander-dark p-1"
              >
                <IconX size={20} />
              </button>
            </div>
            <div className="flex-1 overflow-y-auto p-5 space-y-6">
              {/* 目的地 */}
              <div className="flex items-center gap-2 flex-wrap">
                {historyDetail.destinations?.map((d: string, i: number) => (
                  <span key={d}>
                    <span className="text-sm font-medium text-wander-dark">{d}</span>
                    {i < historyDetail.destinations.length - 1 && (
                      <span className="text-wander-lighter mx-1">vs</span>
                    )}
                  </span>
                ))}
              </div>

              {/* 对比表格 */}
              {historyDetail.result?.rows?.length > 0 && (
                <div className="overflow-x-auto border-[0.5px] border-wander-border rounded-xl">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="bg-cream">
                        <th className="text-left px-4 py-3 font-semibold text-wander-dark text-xs uppercase tracking-wider">维度</th>
                        {historyDetail.result.rows[0]?.values?.map((_: any, i: number) => (
                          <th key={i} className="text-left px-4 py-3 font-semibold text-wander-dark text-xs uppercase tracking-wider">
                            {historyDetail.destinations?.[i] || `目的地${i + 1}`}
                          </th>
                        ))}
                      </tr>
                    </thead>
                    <tbody>
                      {historyDetail.result.rows.map((row: any, i: number) => (
                        <tr key={i} className="border-t-[0.5px] border-wander-border hover:bg-cream/50">
                          <td className="px-4 py-3 font-medium text-wander-dark text-xs">{row.dimension}</td>
                          {row.values?.map((v: string, j: number) => (
                            <td key={j} className="px-4 py-3 text-wander-gray text-xs">{v}</td>
                          ))}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}

              {/* 推荐 */}
              {historyDetail.result?.verdict && (
                <div className="bg-gradient-to-br from-wander-dark to-[#2a2a27] rounded-xl p-5 text-cream">
                  <h3 className="text-sm font-semibold mb-2 opacity-80">🏆 推荐结论</h3>
                  <p className="text-lg font-medium">{historyDetail.result.verdict}</p>
                  {historyDetail.result.recommendation && (
                    <p className="text-sm text-wander-light mt-2">{historyDetail.result.recommendation}</p>
                  )}
                </div>
              )}

              {/* 评分 */}
              {historyDetail.result?.scores?.length > 0 && (
                <div>
                  <h3 className="font-semibold text-sm text-wander-dark mb-3">⭐ 综合评分</h3>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {historyDetail.result.scores.map((sc: any, i: number) => (
                      <div key={i} className="bg-cream/50 rounded-xl p-4 border-[0.5px] border-wander-border">
                        <h4 className="font-bold text-wander-dark">{sc.destination}</h4>
                        <p className="font-heading text-2xl font-bold text-wander-green my-2">{sc.overall?.toFixed(1)} / 5.0</p>
                        {sc.details && Object.entries(sc.details).map(([k, v]: any) => (
                          <div key={k} className="flex items-center justify-between text-xs py-1">
                            <span className="text-wander-gray">{k}</span>
                            <div className="flex items-center gap-2">
                              <div className="w-16 h-1.5 bg-white rounded-full overflow-hidden">
                                <div className="h-full bg-wander-green rounded-full" style={{ width: `${(v / 5) * 100}%` }} />
                              </div>
                              <span className="text-wander-lighter w-4 text-right">{v}</span>
                            </div>
                          </div>
                        ))}
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
