FROM node:22-alpine
WORKDIR /app
COPY server.js .
COPY favicon.ico .
ENV PORT=8080
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=8s --start-period=5s \
  CMD wget -qO- http://localhost:8080/ || exit 1
CMD ["node", "server.js"]
