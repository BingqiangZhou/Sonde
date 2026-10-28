# 声读 web 阅读站（React Router SSR，自定义 node server 反代 /api）
FROM node:24-alpine

WORKDIR /app

# 构建上下文为仓库根（changelog 页面需要打包根 CHANGELOG.md，见 .dockerignore 白名单）
COPY web/package.json web/package-lock.json ./
RUN npm ci --no-audit --no-fund

# 构建
COPY web/ .
COPY CHANGELOG.md /CHANGELOG.md
RUN npm run build

ENV PORT=3000 \
    API_URL=http://backend:8000 \
    NODE_ENV=production

EXPOSE 3000

# node 24 直接运行 TypeScript（server.ts）
CMD ["node", "server.ts"]
