# CrossPlatformHelmChartHelloWorld

This repository is deliberately small. It contains one Helm chart plus two sample container images (located in `images/linux` and `images/windows`) whose entrypoints validate real SQL Server and Azure Service Bus connectivity before declaring success, so a single release can still run a Linux Pod and a Windows Pod side by side with no extra abstractions.

## What this demo proves
- A single Helm chart can target both operating systems at once.
- The Linux Pod is pinned with `kubernetes.io/os: linux` and runs `entrypoint.sh`, which uses `sqlcmd` to execute `SELECT 1` and crafts an HMAC-SHA256 Service Bus SAS token before hitting the `/$Resources` endpoint.
- The Windows Pod is pinned with `kubernetes.io/os: windows` and runs `entrypoint.ps1`, which uses the built-in PowerShell/`sqlcmd` stack to perform the same authenticated checks.
- There are no Services, ports, or production extras—just two Pods that gate their readiness on successful connectivity.

## Connection strings
Both images require the same two secrets at runtime:

- `SQL_CONNECTION_STRING`: must include `Server` (or `Data Source`), `User Id` (or `User`), `Password`, and optionally `Database`. The entrypoints use `sqlcmd` to run `SET NOCOUNT ON; SELECT 1`.
- `SB_CONNECTION_STRING`: must include `Endpoint`, `SharedAccessKeyName`, and `SharedAccessKey`. The scripts build a SAS token and call `https://<namespace>.servicebus.windows.net/$Resources`.

## Build the images (optional)
The GitHub Actions workflow builds and publishes both images, but you can test locally. Make sure you have all required connection strings before running either container.

```bash
# Linux
cd images/linux
podman build -t ghcr.io/you/crossplatform-helm-chart-hello-world-linux:latest .
podman run --rm \
  -e SQL_CONNECTION_STRING='Server=...;User Id=...;Password=...;' \
  -e SB_CONNECTION_STRING='Endpoint=sb://.../;SharedAccessKeyName=...;SharedAccessKey=...' \
  ghcr.io/you/crossplatform-helm-chart-hello-world-linux:latest

# Windows (Powershell)
cd ../windows
docker build -t ghcr.io/you/crossplatform-helm-chart-hello-world-windows:latest .
docker run --rm \
  -e SQL_CONNECTION_STRING='Server=...;User Id=...;Password=...;' \
  -e SB_CONNECTION_STRING='Endpoint=sb://.../;SharedAccessKeyName=...;SharedAccessKey=...' \
  ghcr.io/you/crossplatform-helm-chart-hello-world-windows:latest
```

Push both images to the same registry and tag. The chart expects the repository and tag to be shared; it adds the `-linux` or `-windows` suffix automatically when referencing each image.

## Install the chart
Set the repository and tag for the images you pushed, then install:

```bash
helm install crossplatform chart/ \
  --set image.repository=ghcr.io/you/crossplatform-helm-chart-hello-world \
  --set image.tag=latest
```

You should see two Pods:

```bash
kubectl get pods
NAME                       READY   STATUS    AGE
crossplatform-linux        1/1     Running   10s
crossplatform-windows      1/1     Running   10s
```

Uninstall with `helm uninstall crossplatform` when finished.
