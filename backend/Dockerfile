FROM node:24.22.3-alpine AS dependencies
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund

FROM alpine:3.24.4
ENV NODE_ENV=production
RUN apk upgrade --no-cache \
    && apk add --no-cache ca-certificates libstdc++ \
    && addgroup -S node \
    && adduser -S -G node node
WORKDIR /app
COPY --from=dependencies /usr/local/bin/node /usr/local/bin/node
COPY --from=dependencies /app/node_modules ./node_modules
COPY package.json server.js ./
USER node
EXPOSE 3007
CMD ["node", "server.js"]
