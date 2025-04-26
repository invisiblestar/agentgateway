import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import ThemeRegistry from './ThemeRegistry';

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Agent Gateway",
  description: "A gateway for OpenAI Assistants",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <ThemeRegistry>{children}</ThemeRegistry>
      </body>
    </html>
  )
} 