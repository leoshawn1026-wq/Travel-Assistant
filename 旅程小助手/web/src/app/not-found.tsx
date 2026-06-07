"use client";
import Link from "next/link";

export default function NotFound() {
  return (
    <div className="min-h-[60vh] flex items-center justify-center px-4">
      <div className="text-center max-w-md">
        <div className="w-16 h-16 rounded-2xl bg-cream flex items-center justify-center mx-auto mb-5">
          <span className="text-3xl">🧭</span>
        </div>
        <h1 className="font-heading text-4xl font-bold text-wander-dark mb-2">
          404
        </h1>
        <p className="text-wander-light text-sm mb-6">
          这片目的地在地图上找不到，试试去别处看看？
        </p>
        <Link
          href="/"
          className="inline-flex items-center gap-2 bg-wander-dark text-cream px-6 py-2.5 rounded-xl text-sm font-medium hover:bg-wander-green transition-colors"
        >
          返回首页
        </Link>
      </div>
    </div>
  );
}
