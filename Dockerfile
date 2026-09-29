# 声读统一镜像：api / worker / web 共用（compose 里用不同 command 启动）
FROM node:24-trixie-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
COPY apps ./apps
COPY packages ./packages
COPY industry ./industry
COPY scripts ./scripts
COPY database ./database
COPY CHANGELOG.md ./
COPY tsconfig.base.json ./
RUN npm ci
RUN npm run build -w apps/web

FROM node:24-trixie-slim
# worker 需要 ffmpeg 做音频转码；统一安装，镜像共享
RUN apt-get update \
  && apt-get install -y --no-install-recommends ffmpeg \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app ./
ENV NODE_ENV=production
EXPOSE 3000 3001
CMD ["node", "apps/api/src/main.ts"]
