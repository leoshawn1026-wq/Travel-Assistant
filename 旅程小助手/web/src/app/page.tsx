"use client";
import { useState, useEffect } from "react";
import Link from "next/link";
import api from "@/lib/api";
import { useAuth } from "@/lib/auth-context";
import {
  IconSparkles,
  IconPlayerPlay,
  IconBolt,
  IconGitCompare,
  IconRoute,
  IconSearch,
  IconUsers,
  IconHeart,
  IconBookmark,
  IconCopy,
  IconArrowRight,
} from "@tabler/icons-react";

/* ── constants ── */
const SAMPLE_TRIPS = [
  {
    id: "s1",
    emoji: "🏯",
    bg: "#FFF8E1",
    username: "lixiaoming",
    avatarColor: "#2D6A4F",
    avatarInitial: "李",
    title: "东京 7 日深度游",
    meta: "7天 · 2人 · ¥12,000 预算",
    likes: 284,
    bookmarks: 97,
  },
  {
    id: "s2",
    emoji: "🌿",
    bg: "#E8F5E9",
    username: "wangfang_travels",
    avatarColor: "#1565C0",
    avatarInitial: "王",
    title: "巴厘岛亲子 5 日",
    meta: "5天 · 4人 · ¥28,000 预算",
    likes: 156,
    bookmarks: 63,
  },
  {
    id: "s3",
    emoji: "🗼",
    bg: "#FCE4EC",
    username: "chenyue_globe",
    avatarColor: "#AD1457",
    avatarInitial: "陈",
    title: "巴黎浪漫周末",
    meta: "4天 · 2人 · ¥35,000 预算",
    likes: 421,
    bookmarks: 182,
  },
];

const DESTINATIONS = [
  { flag: "🇯🇵", bg: "#FFF3E0", name: "东京，日本", tags: "文化 · 美食 · 都市", pct: 94 },
  { flag: "🇰🇷", bg: "#E3F2FD", name: "首尔，韩国", tags: "时尚 · 夜生活 · 美食", pct: 87 },
  { flag: "🇸🇬", bg: "#E8F5E9", name: "新加坡", tags: "现代 · 多元 · 美食", pct: 79 },
];

/* ── Component ── */
export default function Home() {
  const { user } = useAuth();
  const [feed, setFeed] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api
      .getFeed()
      .then((data) => setFeed(data.items || []))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const tripCards = feed.length > 0 ? feed.slice(0, 3) : SAMPLE_TRIPS;

  return (
    <div>
      {/* ── HERO ── */}
      <section className="bg-cream">
        <div className="max-w-6xl mx-auto px-8 sm:px-12 lg:px-16 py-16 md:py-24 grid md:grid-cols-2 gap-10 md:gap-16 items-center">
          {/* Left */}
          <div>
            <div className="inline-flex items-center gap-1.5 bg-wander-green-light text-wander-green text-xs font-medium px-3.5 py-1.5 rounded-full mb-6">
              <IconSparkles size={14} />
              AI 驱动的旅行决策引擎
            </div>
            <h1 className="font-heading text-4xl sm:text-5xl md:text-6xl leading-[1.1] font-bold text-wander-dark mb-6">
              不再纠结
              <br />
              <em className="not-italic text-wander-green">去哪里</em>
              <br />
              只需出发
            </h1>
            <p className="text-wander-gray text-base leading-relaxed mb-8 max-w-md">
              WanderWise 用 AI 分析你的旅行偏好，帮你在多个目的地间做出最优决策，并为你量身定制完整旅程方案。
            </p>
            <div className="flex items-center gap-4">
              <Link
                href="/itinerary/new"
                className="bg-wander-dark text-cream px-6 py-3 rounded-full text-sm font-medium hover:bg-wander-green transition-colors inline-flex items-center gap-2"
              >
                免费规划我的旅行 <IconArrowRight size={16} />
              </Link>
              <Link
                href="/compare"
                className="text-wander-dark text-sm flex items-center gap-1.5 hover:text-wander-green transition-colors"
              >
                <IconPlayerPlay size={18} /> 查看演示
              </Link>
            </div>
          </div>

          {/* Right — Destination Match Card */}
          <div className="relative">
            <div className="absolute -top-4 right-6 bg-wander-green text-white text-xs font-medium px-3.5 py-1.5 rounded-full flex items-center gap-1.5 shadow-sm">
              <IconBolt size={14} /> AI 正在分析中
            </div>
            <div className="bg-white rounded-2xl p-6 border-[0.5px] border-wander-border shadow-sm">
              <p className="text-xs text-wander-lighter font-medium tracking-wide mb-4">
                目的地匹配结果
              </p>
              {DESTINATIONS.map((d) => (
                <div key={d.name} className="dest-row">
                  <div className="flex items-center gap-3">
                    <div
                      className="w-9 h-9 rounded-xl flex items-center justify-center text-xl"
                      style={{ background: d.bg }}
                    >
                      {d.flag}
                    </div>
                    <div>
                      <div className="text-sm font-medium text-wander-dark">
                        {d.name}
                      </div>
                      <div className="text-xs text-wander-lighter">{d.tags}</div>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="w-20 h-1.5 bg-[#f0ede8] rounded-full overflow-hidden">
                      <div
                        className="h-full rounded-full bg-wander-green"
                        style={{ width: `${d.pct}%` }}
                      />
                    </div>
                    <span className="text-xs font-medium text-wander-green">
                      {d.pct}%
                    </span>
                  </div>
                </div>
              ))}
              <div className="mt-4 pt-3 border-t-[0.5px] border-[#f0ede8] flex gap-2.5">
                <div className="w-2 h-2 bg-wander-green rounded-full mt-1 shrink-0" />
                <p className="text-xs text-wander-gray leading-relaxed">
                  根据你的偏好（美食探索、文化体验、预算适中），
                  <strong className="text-wander-dark">东京</strong>是最佳选择。春季赏樱与你的出行时间高度吻合。
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ── STATS ── */}
      <section className="bg-wander-dark py-10 md:py-12">
        <div className="max-w-4xl mx-auto px-8 flex justify-center gap-8 md:gap-16 flex-wrap">
          {[
            { num: "50k+", label: "规划中的旅行" },
            { num: "120+", label: "覆盖目的地" },
            { num: "4.9★", label: "用户评分" },
            { num: "2min", label: "生成完整方案" },
          ].map((s) => (
            <div key={s.label} className="text-center">
              <div className="font-heading text-3xl md:text-4xl font-bold text-white">
                {s.num}
              </div>
              <div className="text-xs text-wander-lighter mt-1">{s.label}</div>
            </div>
          ))}
        </div>
      </section>

      {/* ── FEATURES ── */}
      <section className="py-16 md:py-24">
        <div className="max-w-6xl mx-auto px-8 sm:px-12 lg:px-16">
          <div className="text-xs font-medium text-wander-green tracking-widest uppercase mb-3">
            核心功能
          </div>
          <div className="grid md:grid-cols-2 gap-6 items-end mb-10">
            <h2 className="font-heading text-3xl md:text-4xl font-bold text-wander-dark leading-tight">
              从犹豫不决
              <br />
              到胸有成竹
            </h2>
            <p className="text-wander-light text-sm leading-relaxed md:mb-1">
              WanderWise 覆盖旅行决策全链路——从目的地筛选、行程定制，到实时信息查询与社区分享，一站搞定。
            </p>
          </div>
          <div className="grid sm:grid-cols-2 gap-4">
            {[
              {
                icon: IconGitCompare,
                title: "AI 目的地对比",
                desc: "输入出行人数、预算与旅行动机，AI 从气候、费用、体验、签证等多维度为你的候选目的地打分排序，告别选择困难。",
                tags: ["用户画像", "多维评分", "AI 推荐"],
              },
              {
                icon: IconRoute,
                title: "智能行程定制",
                desc: "确定目的地后，AI 立即生成按天排布的完整行程，支持拖拽调整、局部重生、版本回退，导出 PDF 或精美分享图。",
                tags: ["按天排布", "拖拽编辑", "导出分享"],
              },
              {
                icon: IconSearch,
                title: "旅行信息聚合",
                desc: "在行程页内直接查询酒店推荐、餐厅评分、实时天气，以及机票和火车票价格参考，信息不出页面。",
                tags: ["酒店/餐厅", "天气预报", "机票参考"],
              },
              {
                icon: IconUsers,
                title: "旅行社区",
                desc: "发现其他旅行者分享的真实行程，一键复制为自己的方案。支持点赞、收藏、评论与好友系统，旅伴匹配功能即将上线。",
                tags: ["行程模板", "好友系统", "旅伴匹配"],
              },
            ].map((f) => (
              <div key={f.title} className="feature-card">
                <div className="w-11 h-11 bg-wander-green-light rounded-xl flex items-center justify-center mb-4">
                  <f.icon size={22} className="text-wander-green" />
                </div>
                <h3 className="font-medium text-base text-wander-dark mb-2">
                  {f.title}
                </h3>
                <p className="text-sm text-wander-light leading-relaxed">
                  {f.desc}
                </p>
                <div className="flex flex-wrap gap-1.5 mt-3">
                  {f.tags.map((t) => (
                    <span
                      key={t}
                      className="text-xs text-wander-gray bg-cream px-2.5 py-1 rounded-full"
                    >
                      {t}
                    </span>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── HOW IT WORKS ── */}
      <section className="bg-white py-16 md:py-24">
        <div className="max-w-4xl mx-auto px-8 sm:px-12 lg:px-16">
          <div className="text-center">
            <div className="text-xs font-medium text-wander-green tracking-widest uppercase mb-3">
              使用流程
            </div>
            <h2 className="font-heading text-3xl md:text-4xl font-bold text-wander-dark">
              四步，从想法到行程
            </h2>
          </div>
          <div className="relative grid grid-cols-2 md:grid-cols-4 gap-6 md:gap-8 mt-12">
            <div className="steps-connector hidden md:block" />
            {[
              { num: 1, title: "填写旅行画像", desc: "告诉我们你的预算、人数、偏好和出行动机" },
              { num: 2, title: "对比目的地", desc: "AI 为你的候选城市生成多维对比报告" },
              { num: 3, title: "生成行程方案", desc: "确认目的地后，2分钟内获得完整行程" },
              { num: 4, title: "分享与出发", desc: "导出、收藏或分享给好友，随时出发" },
            ].map((s, i) => (
              <div key={s.num} className="text-center relative z-10">
                <div
                  className={`w-14 h-14 rounded-full flex items-center justify-center mx-auto mb-4 font-heading text-lg font-bold ${
                    i === 0
                      ? "bg-wander-dark text-cream"
                      : "bg-cream border-[0.5px] border-[#ddd] text-wander-dark"
                  }`}
                >
                  {s.num}
                </div>
                <div className="font-medium text-sm text-wander-dark mb-1.5">
                  {s.title}
                </div>
                <div className="text-xs text-wander-light leading-relaxed max-w-[180px] mx-auto">
                  {s.desc}
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── COMMUNITY ── */}
      <section id="community" className="py-16 md:py-24">
        <div className="max-w-6xl mx-auto px-8 sm:px-12 lg:px-16">
          <div className="flex items-end justify-between mb-8">
            <div>
              <div className="text-xs font-medium text-wander-green tracking-widest uppercase mb-3">
                社区精选
              </div>
              <h2 className="font-heading text-3xl md:text-4xl font-bold text-wander-dark leading-tight">
                旅行者们
                <br />
                正在分享
              </h2>
            </div>
            {feed.length > 0 && (
              <Link
                href="/compare"
                className="hidden sm:flex items-center gap-1 text-sm text-wander-green font-medium hover:underline"
              >
                探索更多 <IconArrowRight size={14} />
              </Link>
            )}
          </div>

          {loading && feed.length === 0 ? (
            <div className="flex justify-center py-16">
              <div className="w-8 h-8 border-2 border-wander-green border-t-transparent rounded-full animate-spin" />
            </div>
          ) : (
            <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
              {tripCards.map((item: any) => {
                const isSample = typeof item.id === "string" && item.id.startsWith("s");
                return (
                  <div key={item.id} className="trip-card">
                    <div
                      className="h-32 md:h-36 flex items-center justify-center text-4xl"
                      style={{ background: item.bg || "#FFF8E1" }}
                    >
                      {item.emoji || "🏝️"}
                    </div>
                    <div className="p-4 md:p-5">
                      <div className="flex items-center gap-2 mb-2.5">
                        <div
                          className="w-7 h-7 rounded-full flex items-center justify-center text-xs font-medium text-white"
                          style={{ background: item.avatarColor || "#2D6A4F" }}
                        >
                          {item.avatarInitial ||
                            (item.user?.username?.[0] || "?")}
                        </div>
                        <span className="text-xs font-medium text-wander-gray">
                          @{item.username || item.user?.username || "traveler"}
                        </span>
                      </div>
                      <h3 className="font-medium text-sm text-wander-dark mb-1">
                        {item.title || "未命名行程"}
                      </h3>
                      <p className="text-xs text-wander-lighter mb-3">
                        {item.meta ||
                          `${item.itinerary_data?.days || "?"}天 · 探索之旅`}
                      </p>
                      <div className="flex items-center gap-4">
                        <span className="flex items-center gap-1 text-xs text-wander-light">
                          <IconHeart size={14} /> {item.likes || item.like_count || 0}
                        </span>
                        <span className="flex items-center gap-1 text-xs text-wander-light">
                          <IconBookmark size={14} /> {item.bookmarks || 0}
                        </span>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </section>

      {/* ── CTA ── */}
      <section id="pricing" className="bg-wander-dark py-16 md:py-24 text-center">
        <h2 className="font-heading text-3xl md:text-5xl text-cream leading-tight mb-4">
          你的下一次旅行
          <br />
          <em className="not-italic text-wander-green-bright">从这里开始</em>
        </h2>
        <p className="text-wander-lighter text-sm max-w-md mx-auto mb-8 leading-relaxed px-4">
          加入已经在用 WanderWise 规划旅行的 50,000+ 旅行者，免费开始，无需信用卡。
        </p>
        {user ? (
          <Link
            href="/itinerary/new"
            className="inline-flex bg-wander-green text-white px-7 py-3 rounded-full text-sm font-medium hover:bg-wander-green-hover transition-colors"
          >
            开始规划行程
          </Link>
        ) : (
          <Link
            href="/auth/register"
            className="inline-flex bg-wander-green text-white px-7 py-3 rounded-full text-sm font-medium hover:bg-wander-green-hover transition-colors"
          >
            免费开始 →
          </Link>
        )}
        <p className="text-xs text-wander-light mt-4">
          ✓ 永久免费基础版 &nbsp; ✓ 无广告 &nbsp; ✓ 随时取消
        </p>
      </section>

      {/* ── FOOTER ── */}
      <footer className="bg-wander-footer-bg py-6 md:py-8">
        <div className="max-w-6xl mx-auto px-8 sm:px-12 lg:px-16 flex flex-col md:flex-row items-center justify-between gap-4">
          <div className="font-heading text-lg text-cream">
            Wander<span className="text-wander-green-bright">Wise</span>
          </div>
          <p className="text-xs text-wander-light">
            © 2026 WanderWise. 让每次旅行都值得。
          </p>
          <div className="flex gap-6">
            {["关于我们", "隐私政策", "联系我们"].map((l) => (
              <span
                key={l}
                className="text-xs text-wander-light cursor-default"
              >
                {l}
              </span>
            ))}
          </div>
        </div>
      </footer>
    </div>
  );
}
