FROM node:22-windowsservercore-ltsc2022
WORKDIR C:/app
COPY server.js .
ENV PORT=80
EXPOSE 80
HEALTHCHECK --interval=10s --timeout=3s --start-period=30s \
  CMD powershell -Command "try { $r = Invoke-WebRequest -Uri http://localhost:80/ -UseBasicParsing -TimeoutSec 3; if ($r.StatusCode -lt 500) { exit 0 } else { exit 1 } } catch { exit 1 }"
CMD ["node", "server.js"]
