import config from "./vite.config.js";

export default {
  ...config,
  plugins: [
    ...(config.plugins ?? []),
    {
      name: "local-admin-page",
      configureServer(server) {
        server.middlewares.use((request, _response, next) => {
          if (request.url) {
            request.url = request.url.replace(/^\/gestion-quiz(?=\?|$)/, "/gestion-quiz.html");
          }
          next();
        });
      },
    },
  ],
  server: {
    host: "0.0.0.0",
    port: 8080,
    strictPort: true,
    watch: {
      usePolling: true,
      interval: 300,
    },
    proxy: {
      "/api": "http://backend:3007",
      "/health": "http://backend:3007",
    },
  },
};
