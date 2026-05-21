/** @type {import('next').NextConfig} */
const nextConfig = {
  // Required for the multi-stage Dockerfile — produces a self-contained
  // server.js that doesn't need node_modules at runtime.
  output: "standalone",
};
 
module.exports = nextConfig;