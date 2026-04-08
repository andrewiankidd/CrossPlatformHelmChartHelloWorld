# Cross-Platform Helm Chart Hello World

A minimal Helm chart that deploys a Linux service and a Windows service side-by-side, each validating connectivity to shared infrastructure and to each other. Designed as the reference fixture for [Crosspose](https://github.com/andrewiankidd/crosspose) — it bundles its own `crosspose/` directory inside the chart so a single `helm pull` gives you everything you need to dekompose and run.

## What it tests

| Check | Purpose |
|-------|---------|
| MSSQL | TCP connection to SQL Server (port 1433) |
| Service Bus | TCP connection to Azure Service Bus Emulator (AMQP 5672) |
| Azure Storage | HTTP probe against Azurite blob endpoint (port 10000) |
| Peer Service | HTTP call from Windows container to Linux, and vice-versa |

Each container serves an HTML status page on its root path with green/red indicators for each check. Returns HTTP 200 when all pass, 503 when any fail. This endpoint doubles as the container healthcheck.

## Repository layout

```
chart/
  Chart.yaml
  values.yaml
  templates/              Deployments + Services for hello-linux and hello-windows
  crosspose/              Embedded Crosspose defaults (extracted by Crosspose on pull)
    values.yaml           Local-dev values for Crosspose
    dekompose.yml         Dekompose rules: MSSQL + Service Bus + Azurite infra
images/
  server.js               Shared Node.js health-check server (zero npm deps)
  linux/Dockerfile        Linux image (node:22-alpine)
  windows/                Windows image + healthcheck.js (servercore + node)
```

The `chart/crosspose/` directory follows the [Crosspose helm chart authoring convention](https://github.com/andrewiankidd/crosspose/blob/main/docs/helm-chart-authoring.md). When the chart is pulled via the Crosspose GUI, these files are automatically extracted as named siblings next to the chart `.tgz` (e.g. `cross-platform-hello-0.4.0.values.yaml`).

## Use with Crosspose

### From the GUI
1. Add `ghcr.io/andrewiankidd` as an OCI source in **Helm Charts**.
2. Pull `cross-platform-hello` — Crosspose extracts the bundled `crosspose/` defaults automatically.
3. Click **Dekompose** on the chart, then **Deploy** the resulting bundle.
4. Open the mapped ports for both `hello-linux` and `hello-windows` to see the status pages.

### From the CLI

```powershell
# Pull the chart from GHCR
helm pull oci://ghcr.io/andrewiankidd/charts/cross-platform-hello --destination .

# Extract the embedded crosspose defaults from the chart bundle
tar -xzf cross-platform-hello-0.4.0.tgz cross-platform-hello/crosspose

# Dekompose
dotnet run --project src/Crosspose.Dekompose.Cli -- `
  --chart cross-platform-hello-0.4.0.tgz `
  --values cross-platform-hello/crosspose/values.yaml `
  --dekompose-config cross-platform-hello/crosspose/dekompose.yml `
  --infra --remap-ports --compress
```

## Build images locally

```bash
# Linux
docker build -t ghcr.io/andrewiankidd/crossplatform-helm-chart-hello-world-linux:latest images/linux/

# Windows (Docker Desktop in Windows container mode)
docker build -t ghcr.io/andrewiankidd/crossplatform-helm-chart-hello-world-windows:latest images/windows/
```

The CI workflow copies `images/server.js` into each build context before building.

## Infrastructure

`chart/crosspose/dekompose.yml` defines three infra services that Crosspose provisions automatically:

- **MSSQL 2022** — `mcr.microsoft.com/mssql/server:2022-latest` with SA password and healthcheck
- **Azure Service Bus Emulator** — `mcr.microsoft.com/azure-messaging/servicebus-emulator:latest` (depends on MSSQL)
- **Azurite** — `mcr.microsoft.com/azure-storage/azurite:latest` (blob, queue, table)

## Screenshot

![Crosspose Hello World](.github/screencap.png)
