"use client";
import { useState, useEffect } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import api from "@/lib/api";
import { useAuth } from "@/lib/auth-context";

export default function ProfilePage() {
  const params = useParams();
  const username = params.username as string;
  const { user: currentUser } = useAuth();
  const [profile, setProfile] = useState<any>(null);
  const [itineraries, setItineraries] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [isFollowing, setIsFollowing] = useState(false);

  useEffect(() => {
    Promise.all([
      api.getUserProfile(username),
      api.getUserItineraries(username),
    ])
      .then(([profileData, itinData]) => {
        setProfile(profileData);
        setIsFollowing(profileData.is_following || false);
        setItineraries(itinData || []);
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [username]);

  const handleFollow = async () => {
    if (!currentUser) return;
    try {
      if (isFollowing) {
        await api.unfollowUser(profile.id);
        setIsFollowing(false);
        setProfile((p: any) => ({
          ...p,
          follower_count: (p.follower_count || 1) - 1,
        }));
      } else {
        await api.followUser(profile.id);
        setIsFollowing(true);
        setProfile((p: any) => ({
          ...p,
          follower_count: (p.follower_count || 0) + 1,
        }));
      }
    } catch (e) {
      console.warn("[用户] 关注失败:", e);
    }
  };

  if (loading)
    return (
      <div className="flex justify-center py-20">
        <div className="w-8 h-8 border-2 border-wander-green border-t-transparent rounded-full animate-spin" />
      </div>
    );

  if (!profile)
    return (
      <div className="text-center py-20">
        <p className="text-wander-light">用户不存在</p>
        <Link href="/" className="text-wander-green mt-4 inline-block text-sm hover:underline">
          返回首页
        </Link>
      </div>
    );

  const isOwn = currentUser?.id === profile.id;

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-8 py-8 space-y-6">
      {/* Profile Card */}
      <div className="bg-white rounded-2xl p-6 md:p-8 border-[0.5px] border-wander-border">
        <div className="flex items-start gap-5">
          <div className="w-16 h-16 md:w-20 md:h-20 rounded-full bg-wander-green flex items-center justify-center text-2xl md:text-3xl font-bold text-white shrink-0">
            {profile.username?.[0]?.toUpperCase() || "?"}
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-center justify-between flex-wrap gap-3">
              <div>
                <h1 className="font-heading text-xl md:text-2xl font-bold text-wander-dark">
                  {profile.username}
                </h1>
                {profile.bio && (
                  <p className="text-wander-gray text-sm mt-0.5">
                    {profile.bio}
                  </p>
                )}
              </div>
              {!isOwn && currentUser && (
                <button
                  onClick={handleFollow}
                  className={`px-5 py-2 rounded-full text-sm font-medium transition-colors ${
                    isFollowing
                      ? "bg-cream text-wander-gray border-[0.5px] border-wander-border hover:bg-gray-100"
                      : "bg-wander-dark text-cream hover:bg-wander-green"
                  }`}
                >
                  {isFollowing ? "已关注" : "关注"}
                </button>
              )}
            </div>

            <div className="flex gap-6 mt-4 text-sm">
              <div>
                <span className="font-bold text-wander-dark">
                  {profile.follower_count || 0}
                </span>{" "}
                <span className="text-wander-light">粉丝</span>
              </div>
              <div>
                <span className="font-bold text-wander-dark">
                  {profile.following_count || 0}
                </span>{" "}
                <span className="text-wander-light">关注</span>
              </div>
              <div>
                <span className="font-bold text-wander-dark">
                  {profile.itinerary_count || 0}
                </span>{" "}
                <span className="text-wander-light">行程</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Itineraries */}
      <h2 className="font-heading text-lg font-bold text-wander-dark">
        公开行程
      </h2>
      {itineraries.length === 0 ? (
        <div className="text-center py-12 bg-white rounded-xl border-[0.5px] border-wander-border">
          <p className="text-wander-lighter text-sm">暂无公开行程</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {itineraries.map((it: any) => (
            <Link
              key={it.id}
              href={`/share/${it.id}`}
              className="bg-white rounded-xl p-5 border-[0.5px] border-wander-border hover:border-wander-green/30 transition-colors"
            >
              <h3 className="font-medium text-wander-dark mb-1.5">
                {it.title}
              </h3>
              <p className="text-sm text-wander-gray mb-3">
                📍 {it.destination}
              </p>
              <div className="flex items-center gap-3 text-xs text-wander-lighter">
                <span>❤️ {it.like_count}</span>
                <span>📅 {it.created_at?.slice(0, 10)}</span>
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
