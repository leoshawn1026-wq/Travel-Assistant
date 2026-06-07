"use client";
export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <html>
      <body className="min-h-screen bg-cream flex items-center justify-center px-4">
        <div className="text-center max-w-md">
          <div className="w-16 h-16 rounded-2xl bg-red-50 flex items-center justify-center mx-auto mb-5">
            <span className="text-2xl">⚠️</span>
          </div>
          <h2 className="font-heading text-xl font-bold text-wander-dark mb-2">
            应用异常
          </h2>
          <p className="text-sm text-wander-light mb-6">
            应用发生了严重错误，请刷新重试。
          </p>
          <button
            onClick={() => reset()}
            className="bg-wander-dark text-cream px-6 py-2.5 rounded-xl text-sm font-medium hover:bg-wander-green transition-colors"
          >
            刷新页面
          </button>
        </div>
      </body>
    </html>
  );
}
