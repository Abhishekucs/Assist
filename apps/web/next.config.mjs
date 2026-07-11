import { fileURLToPath } from "node:url";

const workspaceRoot = fileURLToPath(new URL("../..", import.meta.url));

/** @type {import('next').NextConfig} */
const nextConfig = {
  devIndicators: false,
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "m94bitnxyzpsrcu1.public.blob.vercel-storage.com",
        pathname: "/HeroIsland/**"
      }
    ]
  },
  turbopack: {
    root: workspaceRoot
  }
};

export default nextConfig;
