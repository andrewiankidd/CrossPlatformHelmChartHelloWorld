FROM mcr.microsoft.com/windows/servercore:ltsc2022

SHELL ["powershell", "-NoLogo", "-Command", "$ErrorActionPreference='Stop';"]

RUN Invoke-WebRequest -Uri "https://aka.ms/sqlcmd2022" -OutFile "C:\\sqlcmd.msi"; \
    Start-Process msiexec.exe -ArgumentList '/i', 'C:\\sqlcmd.msi', '/qn', '/norestart' -Wait; \
    Remove-Item "C:\\sqlcmd.msi"

ENV PATH="C:\\Program Files\\Microsoft SQL Server\\Client SDK\\ODBC\\170\\Tools\\Binn;C:\\Windows\\System32;C:\\Windows;C:\\Windows\\System32\\Wbem;C:\\Windows\\System32\\WindowsPowerShell\\v1.0"

COPY entrypoint.ps1 C:/entrypoint.ps1

ENTRYPOINT ["powershell", "-NoLogo", "-ExecutionPolicy", "Bypass", "-File", "C:/entrypoint.ps1"]
