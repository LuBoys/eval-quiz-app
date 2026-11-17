FROM node:24.22.3-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY index.html gestion-quiz.html vite.config.js main.js style.css questions_*.js ./
COPY public ./public
RUN npm run build

FROM nginx/nginx-unprivileged:1.30.6-alpine
USER root
RUN apk upgrade --no-cache zlib
USER 101
ENV BACKEND_URL=http://backend:3007 \
    NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1 \
    NGINX_ENVSUBST_FILTER="^(BACKEND_URL|NGINX_LOCAL_RESOLVERS)$"
COPY nginx/nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist/ /usr/share/nginx/html/
EXPOSE 8080
