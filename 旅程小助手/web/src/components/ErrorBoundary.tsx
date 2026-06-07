"use client";
import { Component, ReactNode } from "react";
import Link from "next/link";

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
}

interface State {
  hasError: boolean;
  error?: Error;
}

export default class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, info: any) {
    console.error("[ErrorBoundary]", error, info);
  }

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) return this.props.fallback;

      return (
        <div className="min-h-[60vh] flex items-center justify-center px-4">
          <div className="text-center max-w-md">
            <div className="w-16 h-16 rounded-2xl bg-red-50 flex items-center justify-center mx-auto mb-5">
              <span className="text-2xl">⚠️</span>
            </div>
            <h2 className="font-heading text-xl font-bold text-wander-dark mb-2">
              页面出现异常
            </h2>
            <p className="text-sm text-wander-light mb-6">
              发生了意外错误，请刷新页面重试。
              {this.state.error?.message && (
                <span className="block mt-1 text-xs text-wander-lighter font-mono">
                  {this.state.error.message}
                </span>
              )}
            </p>
            <div className="flex items-center justify-center gap-3">
              <button
                onClick={() => {
                  this.setState({ hasError: false });
                  window.location.reload();
                }}
                className="bg-wander-dark text-cream px-6 py-2.5 rounded-xl text-sm font-medium hover:bg-wander-green transition-colors"
              >
                刷新页面
              </button>
              <Link
                href="/"
                className="text-wander-gray text-sm hover:text-wander-dark transition-colors"
              >
                返回首页
              </Link>
            </div>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
