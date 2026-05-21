import type { Metadata } from "next";
import { DM_Sans, DM_Mono } from "next/font/google";
import "./globals.css";
 
const dmSans = DM_Sans({
  subsets: ["latin"],
  variable: "--font-sans",
});
 
const dmMono = DM_Mono({
  subsets: ["latin"],
  weight: ["400", "500"],
  variable: "--font-mono",
});
 
export const metadata: Metadata = {
  title: "Stark App",
  description: "A containerised Next.js application built with Terraform & Docker",
};
 
export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={`${dmSans.variable} ${dmMono.variable}`}>
      <body>{children}</body>
    </html>
  );
}