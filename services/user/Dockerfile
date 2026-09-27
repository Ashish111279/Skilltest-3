FROM node:20-alpine
ENV NODE_ENV=production SERVICE_NAME=User PORT=3001
WORKDIR /app
COPY services/common/server.js ./server.js
EXPOSE 3001
HEALTHCHECK --interval=10s --timeout=3s --start-period=3s --retries=3 CMD node -e "fetch('http://127.0.0.1:3001/health').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"
USER node
CMD ["node", "server.js"]
