"use client";
import { createContext, useContext, useState, useEffect, useCallback, ReactNode } from "react";
import api from "@/lib/api";

interface User {
  id: number;
  username: string;
  email?: string;
  avatar: string;
  bio: string;
  travel_preferences: Record<string, any>;
  created_at: string;
}

interface AuthContextType {
  user: User | null;
  loading: boolean;
  login: (username: string, password: string) => Promise<void>;
  register: (username: string, email: string, password: string) => Promise<void>;
  logout: () => void;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  const refreshUser = useCallback(async () => {
    try {
      if (api.getToken()) {
        const data = await api.getMe();
        setUser(data.user || data);
      }
    } catch (e) {
      console.warn("[认证] Token 失效, 已清除:", e);
      api.setToken(null);
      setUser(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { refreshUser(); }, [refreshUser]);

  const login = async (username: string, password: string) => {
    const data = await api.login(username, password);
    api.setToken(data.access_token);
    setUser(data.user);
  };

  const register = async (username: string, email: string, password: string) => {
    const data = await api.register(username, email, password);
    api.setToken(data.access_token);
    setUser(data.user);
  };

  const logout = async () => {
    try {
      await api.logout();
    } catch {
      // 即便后端调用失败，前端也清除本地状态
    }
    api.setToken(null);
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, loading, login, register, logout, refreshUser }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
