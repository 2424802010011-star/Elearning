# Máy chủ EduBoard (API + giao diện web). Build từ thư mục backend:
#   docker build -t eduboard ./backend
# Giao diện web lấy từ backend/public (bản build Flutter web), nếu có.

FROM node:22-bookworm-slim AS build
WORKDIR /src
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
RUN npm run build && npm prune --omit=dev && mkdir -p public

FROM node:22-bookworm-slim
ENV NODE_ENV=production PORT=3000 UPLOAD_DIR=/data/uploads
WORKDIR /app
COPY --from=build /src/package.json ./
COPY --from=build /src/node_modules ./node_modules
COPY --from=build /src/dist ./dist
COPY --from=build /src/public ./public
RUN mkdir -p /data/uploads && chown -R node:node /data
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD node -e "fetch('http://localhost:'+process.env.PORT+'/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "dist/main.js"]
