"use client";
import { useState, useRef } from "react";
import api from "@/lib/api";
import { useAuth } from "@/lib/auth-context";
import Link from "next/link";
import { IconArrowRight, IconSparkles, IconDog } from "@tabler/icons-react";
import { useEffect } from "react";

const PACE_OPTIONS = [
  { value: "relaxed", label: "悠闲" },
  { value: "moderate", label: "适中" },
  { value: "intense", label: "紧凑" },
];

export default function ItineraryNewPage() {
  const { user } = useAuth();
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
  }, []);
  const [destination, setDestination] = useState("");
  const [date, setDate] = useState("");
  const [days, setDays] = useState(1);
  const [pace, setPace] = useState("moderate");
  const [preferences, setPreferences] = useState("");
  const [withPet, setWithPet] = useState(false);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<any>(null);
  const [error, setError] = useState("");
  const [editMode, setEditMode] = useState(false);
  const [editedResult, setEditedResult] = useState<any>(null);
  const resultRef = useRef<HTMLDivElement>(null);

  const handleGenerate = async () => {
    if (!destination.trim()) { setError("请输入目的地"); return; }
    if (!date) { setError("请选择日期"); return; }
    setError("");
    setLoading(true);
    setResult(null);
    setEditMode(false);

    try {
      const data = await api.generateItinerary({
        destination: destination.trim(),
        date,
        days,
        pace,
        with_pet: withPet,
        device_id: deviceId,
        preferences: preferences
          ? preferences
              .split(/[,，、]/)
              .map((s) => s.trim())
              .filter(Boolean)
          : [],
      });
      setResult(data);
      setEditedResult(JSON.parse(JSON.stringify(data)));
      setTimeout(
        () => resultRef.current?.scrollIntoView({ behavior: "smooth" }),
        200
      );
    } catch (e: any) {
      setError(e.message || "行程生成失败");
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    if (!user) return;
    try {
      await api.saveItinerary({
        title: editedResult?.title || `${destination}行程`,
        destination: destination.trim(),
        itinerary_data: editedResult,
        is_public: true,
      });
      alert("✅ 行程已保存并分享！");
    } catch (e: any) {
      alert("保存失败: " + e.message);
    }
  };

  const dayPlans = editedResult?.day_plans || [];
  const items = editedResult?.items || [];
  const isMultiDay = days > 1;

  const updateItem = (
    dayIdx: number,
    itemIdx: number,
    field: string,
    value: string
  ) => {
    const copy = JSON.parse(JSON.stringify(editedResult));
    if (isMultiDay) {
      copy.day_plans[dayIdx].items[itemIdx][field] = value;
    } else {
      copy.items[itemIdx][field] = value;
    }
    setEditedResult(copy);
  };

  const getItems = (dayIdx?: number) => {
    if (isMultiDay && dayIdx !== undefined) return dayPlans[dayIdx]?.items || [];
    return items;
  };

  const inputClass =
    "w-full px-4 py-2.5 border-[0.5px] border-[#ddd] rounded-xl text-sm focus:outline-none focus:border-wander-green transition-colors bg-cream text-wander-dark placeholder-wander-lighter";
  const selectClass = inputClass;

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-8 py-8 space-y-8">
      {/* Header */}
      <div className="text-center">
        <div className="inline-flex items-center gap-1.5 bg-wander-green-light text-wander-green text-xs font-medium px-3.5 py-1.5 rounded-full mb-4">
          <IconSparkles size={14} />
          AI 生成
        </div>
        <h1 className="font-heading text-3xl md:text-4xl font-bold text-wander-dark mb-3">
          定制行程
        </h1>
        <p className="text-wander-light text-sm max-w-lg mx-auto">
          输入目的地，AI 一键生成专属行程方案
        </p>
      </div>

      {/* Form */}
      <div className="bg-white rounded-2xl p-6 md:p-8 border-[0.5px] border-wander-border shadow-sm space-y-5">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-wander-dark mb-1.5">
              目的地
            </label>
            <input
              value={destination}
              onChange={(e) => setDestination(e.target.value)}
              placeholder="如：成都、东京、巴黎..."
              className={inputClass}
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-wander-dark mb-1.5">
              出发日期
            </label>
            <input
              type="date"
              value={date}
              onChange={(e) => setDate(e.target.value)}
              className={inputClass}
            />
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label className="block text-sm font-medium text-wander-dark mb-1.5">
              天数
            </label>
            <input
              type="number"
              min={1}
              max={7}
              value={days}
              onChange={(e) => setDays(Number(e.target.value))}
              className={inputClass}
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-wander-dark mb-1.5">
              节奏
            </label>
            <select
              value={pace}
              onChange={(e) => setPace(e.target.value)}
              className={selectClass}
            >
              {PACE_OPTIONS.map((o) => (
                <option key={o.value} value={o.value}>
                  {o.label}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-wander-dark mb-1.5">
              偏好
            </label>
            <input
              value={preferences}
              onChange={(e) => setPreferences(e.target.value)}
              placeholder="美食、文化、自然..."
              className={inputClass}
            />
          </div>
        </div>

        {/* 宠物友好 */}
        <label className="flex items-center gap-2.5 cursor-pointer select-none">
          <button
            type="button"
            onClick={() => setWithPet(!withPet)}
            className={`w-10 h-5 rounded-full transition-colors relative ${
              withPet ? "bg-wander-green" : "bg-[#ddd]"
            }`}
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
          onClick={handleGenerate}
          disabled={loading}
          className="w-full bg-wander-dark text-cream py-3 rounded-xl text-sm font-medium hover:bg-wander-green disabled:opacity-50 transition-colors flex items-center justify-center gap-2"
        >
          {loading ? (
            <>
              <span className="w-5 h-5 border-2 border-cream border-t-transparent rounded-full animate-spin" />
              AI 正在规划行程...
            </>
          ) : (
            <>
              生成行程 <IconArrowRight size={16} />
            </>
          )}
        </button>
      </div>

      {/* Result */}
      {editedResult && (
        <div ref={resultRef} className="space-y-6">
          {/* Title Bar */}
          <div className="bg-white rounded-2xl p-6 border-[0.5px] border-wander-border">
            <div className="flex items-center justify-between flex-wrap gap-3 mb-4">
              <div>
                <h2 className="font-heading text-xl font-bold text-wander-dark">
                  {editedResult.title || `${destination}行程`}
                </h2>
                <p className="text-wander-gray text-xs mt-1">
                  📅 {date} · {days}天 · {isMultiDay ? "多日" : "单日"}行程
                </p>
              </div>
              <div className="flex gap-2">
                <button
                  onClick={() => setEditMode(!editMode)}
                  className={`px-4 py-1.5 text-xs rounded-full border-[0.5px] transition-colors ${
                    editMode
                      ? "bg-wander-green text-white border-wander-green"
                      : "border-wander-border text-wander-gray hover:bg-cream"
                  }`}
                >
                  {editMode ? "完成编辑" : "编辑"}
                </button>
                {user ? (
                  <button
                    onClick={handleSave}
                    className="px-4 py-1.5 text-xs rounded-full bg-wander-dark text-cream hover:bg-wander-green transition-colors"
                  >
                    保存并分享
                  </button>
                ) : (
                  <Link
                    href="/auth/login"
                    className="px-4 py-1.5 text-xs rounded-full bg-cream text-wander-light border-[0.5px] border-wander-border"
                  >
                    登录后可保存
                  </Link>
                )}
              </div>
            </div>

            {editedResult.summary && (
              <p className="text-sm text-wander-gray bg-cream rounded-xl p-4 leading-relaxed">
                {editedResult.summary}
              </p>
            )}
          </div>

          {/* Multi-day */}
          {isMultiDay ? (
            <div className="space-y-6">
              {dayPlans.map((day: any, di: number) => (
                <div
                  key={di}
                  className="bg-white rounded-2xl border-[0.5px] border-wander-border overflow-hidden"
                >
                  <div className="bg-gradient-to-r from-cream to-wander-green-light px-6 py-4 border-b-[0.5px] border-wander-border">
                    <div className="flex items-center justify-between">
                      <div>
                        <h3 className="font-heading font-bold text-lg text-wander-dark">
                          {day.title || `第 ${day.day || di + 1} 天`}
                        </h3>
                        <p className="text-xs text-wander-light">
                          {day.date}
                        </p>
                      </div>
                    </div>
                    {day.summary && (
                      <p className="text-xs text-wander-gray mt-1">
                        {day.summary}
                      </p>
                    )}
                  </div>

                  <div className="p-5 md:p-6 space-y-4">
                    {(day.items || []).map((item: any, ii: number) => (
                      <div key={ii} className="flex gap-4 items-start">
                        <div className="w-14 text-center shrink-0">
                          {editMode ? (
                            <input
                              value={item.time}
                              onChange={(e) =>
                                updateItem(di, ii, "time", e.target.value)
                              }
                              className="w-full text-xs text-center px-1 py-1 border-[0.5px] border-[#ddd] rounded"
                            />
                          ) : (
                            <span className="text-xs font-medium text-wander-green bg-wander-green-light px-2 py-1 rounded">
                              {item.time}
                            </span>
                          )}
                        </div>
                        <div className="flex-1 min-w-0">
                          {editMode ? (
                            <input
                              value={item.name}
                              onChange={(e) =>
                                updateItem(di, ii, "name", e.target.value)
                              }
                              className="w-full px-2 py-1 border-[0.5px] border-[#ddd] rounded text-sm font-medium mb-1"
                            />
                          ) : (
                            <h4 className="font-medium text-sm text-wander-dark">
                              {item.name}
                              {item.is_local && (
                                <span className="ml-2 text-xs bg-wander-green-light text-wander-green px-2 py-0.5 rounded-full">
                                  本地推荐
                                </span>
                              )}
                            </h4>
                          )}
                          <div className="flex items-center gap-2 text-xs text-wander-lighter mt-1">
                            <span>
                              {item.type === "food" ||
                              item.type === "local_food"
                                ? "🍽️"
                                : item.type === "attraction" ||
                                    item.type === "local_spot"
                                  ? "📍"
                                  : "🚶"}{" "}
                              {item.type === "local_food"
                                ? "本地美食"
                                : item.type === "food"
                                  ? "餐厅"
                                  : item.type === "local_spot"
                                    ? "小众景点"
                                    : item.type === "attraction"
                                      ? "景点"
                                      : item.type === "transport"
                                        ? "交通"
                                        : item.type}
                            </span>
                            {item.duration_minutes && (
                              <span>⏱️ {item.duration_minutes}分钟</span>
                            )}
                          </div>
                          {(item.tips || item.local_tip) && (
                            <p className="text-xs text-wander-gray mt-1">
                              💡 {item.local_tip || item.tips}
                            </p>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>

                  {day.accommodation && (
                    <div className="border-t-[0.5px] border-wander-border px-6 py-4 bg-amber-50/50">
                      <p className="text-sm font-medium text-amber-800 mb-0.5">
                        🏨 住宿推荐：{day.accommodation.name}
                      </p>
                      <p className="text-xs text-amber-600">
                        {day.accommodation.area} ·{" "}
                        {day.accommodation.price_range}
                        {day.accommodation.reason &&
                          ` · ${day.accommodation.reason}`}
                      </p>
                    </div>
                  )}
                </div>
              ))}
            </div>
          ) : (
            /* Single day */
            <div className="bg-white rounded-2xl border-[0.5px] border-wander-border overflow-hidden">
              <div className="p-5 md:p-6 space-y-4">
                {(items || []).map((item: any, ii: number) => (
                  <div key={ii} className="flex gap-4 items-start">
                    <div className="w-14 text-center shrink-0">
                      {editMode ? (
                        <input
                          value={item.time}
                          onChange={(e) =>
                            updateItem(0, ii, "time", e.target.value)
                          }
                          className="w-full text-xs text-center px-1 py-1 border-[0.5px] border-[#ddd] rounded"
                        />
                      ) : (
                        <span className="text-xs font-medium text-wander-green bg-wander-green-light px-2 py-1 rounded">
                          {item.time}
                        </span>
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      {editMode ? (
                        <input
                          value={item.name}
                          onChange={(e) =>
                            updateItem(0, ii, "name", e.target.value)
                          }
                          className="w-full px-2 py-1 border-[0.5px] border-[#ddd] rounded text-sm font-medium mb-1"
                        />
                      ) : (
                        <h4 className="font-medium text-sm text-wander-dark">
                          {item.name}
                          {item.is_local && (
                            <span className="ml-2 text-xs bg-wander-green-light text-wander-green px-2 py-0.5 rounded-full">
                              本地推荐
                            </span>
                          )}
                        </h4>
                      )}
                      {item.address && (
                        <p className="text-xs text-wander-lighter mt-0.5">
                          {item.address}
                        </p>
                      )}
                      {(item.tips || item.local_tip) && (
                        <p className="text-xs text-wander-gray mt-1">
                          💡 {item.local_tip || item.tips}
                        </p>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
