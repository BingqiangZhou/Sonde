# 声读统一镜像：api / worker / web 共用（compose 里用不同 command 启动）
FROM node:24-trixie-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
COPY apps ./apps
COPY packages ./packages
COPY industry ./industry
COPY scripts ./scripts
COPY database ./database
COPY tsconfig.base.json ./
RUN npm ci
RUN npm run build -w apps/web

FROM node:24-trixie-slim
WORKDIR /app
COPY --from=build /app ./
ENV NODE_ENV=production
EXPOSE 3000 3001
CMD ["node", "apps/api/src/main.ts"]
