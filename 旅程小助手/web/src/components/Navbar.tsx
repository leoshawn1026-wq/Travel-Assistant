"use client";
import Link from "next/link";
import { useAuth } from "@/lib/auth-context";
import { useState } from "react";
import {
  IconRoute,
  IconHeart,
  IconUsers,
  IconCurrencyDollar,
  IconMenu2,
  IconX,
  IconMessage2,
  IconCompass,
} from "@tabler/icons-react";

const navLinks = [
  { href: "/chat", label: "AI 助手", icon: IconMessage2 },
  { href: "/travel", label: "出行", icon: IconCompass },
  { href: "/compare", label: "对比", icon: IconRoute },
  { href: "/itinerary/new", label: "发现", icon: IconHeart },
  { href: "/#community", label: "社区", icon: IconUsers },
  { href: "/#pricing", label: "定价", icon: IconCurrencyDollar },
];

export default function Navbar() {
  const { user, logout, loading } = useAuth();
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <nav className="sticky top-0 z-100 bg-cream border-b-[0.5px] border-wander-border">
      <div className="max-w-6xl mx-auto px-8 sm:px-12 lg:px-16">
        <div className="flex justify-between h-16 items-center">
          {/* Logo */}
          <Link
            href="/"
            className="font-heading text-2xl font-bold tracking-tight text-wander-dark"
          >
            Wander<span className="text-wander-green">Wise</span>
          </Link>

          {/* Desktop Nav */}
          <ul className="hidden md:flex items-center gap-8">
            {navLinks.map((link) => (
              <li key={link.label}>
                <Link
                  href={link.href}
                  className="text-wander-gray text-sm hover:text-wander-dark transition-colors"
                >
                  {link.label}
                </Link>
              </li>
            ))}
            <li>
              {loading ? (
                <div className="w-5 h-5 border-2 border-wander-green border-t-transparent rounded-full animate-spin" />
              ) : user ? (
                <div className="flex items-center gap-4">
                  <Link
                    href={`/profile/${user.username}`}
                    className="flex items-center gap-2 text-sm text-wander-gray hover:text-wander-dark transition-colors"
                  >
                    <div className="w-7 h-7 rounded-full bg-wander-green flex items-center justify-center text-xs font-medium text-white">
                      {user.username[0]}
                    </div>
                    <span>{user.username}</span>
                  </Link>
                  <button
                    onClick={logout}
                    className="text-sm text-wander-gray hover:text-red-500 transition-colors"
                  >
                    退出
                  </button>
                </div>
              ) : (
                <div className="flex items-center gap-3">
                  <Link
                    href="/auth/login"
                    className="text-sm text-wander-gray hover:text-wander-dark transition-colors"
                  >
                    登录
                  </Link>
                  <Link
                    href="/auth/register"
                    className="bg-wander-dark text-cream text-sm font-medium px-5 py-2 rounded-full hover:bg-wander-green transition-colors"
                  >
                    免费开始
                  </Link>
                </div>
              )}
            </li>
          </ul>

          {/* Mobile Toggle */}
          <button
            className="md:hidden p-2 text-wander-dark"
            onClick={() => setMenuOpen(!menuOpen)}
          >
            {menuOpen ? <IconX size={24} /> : <IconMenu2 size={24} />}
          </button>
        </div>

        {/* Mobile Menu */}
        {menuOpen && (
          <div className="md:hidden pb-5 space-y-3">
            {navLinks.map((link) => (
              <Link
                key={link.label}
                href={link.href}
                className="block py-2 text-sm text-wander-gray"
                onClick={() => setMenuOpen(false)}
              >
                {link.label}
              </Link>
            ))}
            <hr className="border-wander-border" />
            {user ? (
              <>
                <Link
                  href={`/profile/${user.username}`}
                  className="block py-2 text-sm font-medium"
                  onClick={() => setMenuOpen(false)}
                >
                  @{user.username}
                </Link>
                <button
                  onClick={() => {
                    logout();
                    setMenuOpen(false);
                  }}
                  className="block py-2 text-sm text-red-500"
                >
                  退出
                </button>
              </>
            ) : (
              <>
                <Link
                  href="/auth/login"
                  className="block py-2 text-sm text-wander-gray"
                  onClick={() => setMenuOpen(false)}
                >
                  登录
                </Link>
                <Link
                  href="/auth/register"
                  className="block py-2 text-sm font-medium text-wander-green"
                  onClick={() => setMenuOpen(false)}
                >
                  免费开始
                </Link>
              </>
            )}
          </div>
        )}
      </div>
    </nav>
  );
}
