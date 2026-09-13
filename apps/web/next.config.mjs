import { fileURLToPath } from "node:url";

const workspaceRoot = fileURLToPath(new URL("../..", import.meta.url));

/** @type {import('next').NextConfig} */
const nextConfig = {
  devIndicators: false,
  async redirects() {
    return [
      {
        source: "/fun",
        destination: "/keyboard-sound-tester",
        permanent: true
      }
    ];
  },
  turbopack: {
    root: workspaceRoot
  }
};

export default nextConfig;
