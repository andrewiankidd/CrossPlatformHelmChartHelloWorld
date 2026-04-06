FROM mcr.microsoft.com/windows/servercore:ltsc2022

SHELL ["powershell", "-NoLogo", "-Command", "$ErrorActionPreference='Stop';"]

# Install Node.js LTS
RUN Invoke-WebRequest -Uri 'https://nodejs.org/dist/v22.15.0/node-v22.15.0-win-x64.zip' -OutFile C:\node.zip; \
    Expand-Archive C:\node.zip -DestinationPath C:\; \
    Rename-Item C:\node-v22.15.0-win-x64 C:\nodejs; \
    Remove-Item C:\node.zip

ENV PATH="C:\nodejs;C:\Windows\System32;C:\Windows"

WORKDIR C:/app
COPY server.js .
COPY favicon.ico .
ENV PORT=80
EXPOSE 80
COPY healthcheck.js .
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s \
  CMD ["C:\\nodejs\\node.exe", "C:\\app\\healthcheck.js"]
CMD ["C:\\nodejs\\node.exe", "server.js"]
