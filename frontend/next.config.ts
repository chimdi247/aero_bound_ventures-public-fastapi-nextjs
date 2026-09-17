import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  typescript: {
    // Warning: This allows production builds to successfully complete even if
    // your project has type errors.
    ignoreBuildErrors: true,
  },
  // Produces a minimal standalone server bundle in .next/standalone,
  // used by the multi-stage Dockerfile for a small runtime image.
  output: "standalone",
};

export default nextConfig;
