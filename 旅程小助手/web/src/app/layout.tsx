import type { Metadata } from "next";
import { Playfair_Display, DM_Sans } from "next/font/google";
import "./globals.css";
import { AuthProvider } from "@/lib/auth-context";
import Navbar from "@/components/Navbar";
import ErrorBoundary from "@/components/ErrorBoundary";

const playfair = Playfair_Display({
  subsets: ["latin"],
  variable: "--font-heading",
  display: "swap",
});

const dmSans = DM_Sans({
  subsets: ["latin"],
  weight: ["300", "400", "500"],
  variable: "--font-body",
  display: "swap",
});

export const metadata: Metadata = {
  title: "WanderWise — AI 旅行规划",
  description:
    "不再纠结去哪里，只需出发。WanderWise 用 AI 分析你的旅行偏好，帮你决策目的地并定制完整旅程方案。",
  openGraph: {
    title: "WanderWise — AI 旅行规划",
    description: "AI 帮你决策目的地并定制完整旅程方案",
    type: "website",
    siteName: "WanderWise",
  },
  twitter: {
    card: "summary_large_image",
    title: "WanderWise — AI 旅行规划",
    description: "AI 帮你决策目的地并定制完整旅程方案",
  },
  robots: "index, follow",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html
      lang="zh-CN"
      className={`${playfair.variable} ${dmSans.variable}`}
    >
      <body className="font-body antialiased min-h-screen">
        <ErrorBoundary>
          <AuthProvider>
            <Navbar />
            {children}
          </AuthProvider>
        </ErrorBoundary>
      </body>
    </html>
  );
}
