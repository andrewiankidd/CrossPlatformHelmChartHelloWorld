$ErrorActionPreference = 'Stop'

function Log {
    param([string]$Message)
    Write-Host "[INFO] $Message"
}

function Fail {
    param([string]$Message)
    Write-Error "[ERROR] $Message"
    exit 1
}

function Ensure-Env {
    param(
        [string]$Name,
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        Fail "Missing environment variable $Name"
    }
}

function Parse-ConnectionString {
    param([string]$ConnectionString)

    $dictionary = @{}
    foreach ($segment in $ConnectionString.Split(';')) {
        if (-not $segment) { continue }
        $parts = $segment.Split('=', 2)
        if ($parts.Count -lt 2) { continue }
        $dictionary[$parts[0].Trim().ToLowerInvariant()] = $parts[1].Trim()
    }
    return $dictionary
}

function Test-Sql {
    Log 'Starting SQL Server connectivity verification'
    $parts = Parse-ConnectionString $env:SQL_CONNECTION_STRING
    $server = $parts['server'] ?? $parts['data source'] ?? $parts['datasource']
    $user = $parts['user'] ?? $parts['user id'] ?? $parts['userid']
    $password = $parts['password'] ?? $parts['pwd']
    $database = $parts['database'] ?? $parts['initial catalog'] ?? 'master'

    if (-not $server) { Fail 'SQL_CONNECTION_STRING missing Server or Data Source' }
    if (-not $user) { Fail 'SQL_CONNECTION_STRING missing User or User Id' }
    if (-not $password) { Fail 'SQL_CONNECTION_STRING missing Password or Pwd' }

    Log "Running sqlcmd against $server (database $database)"
    & sqlcmd -S $server -d $database -U $user -P $password -Q 'SET NOCOUNT ON; SELECT 1' -b | Out-Null
    Log 'SQL Server query succeeded'
}

function Get-ServiceBusSasToken {
    param(
        [string]$ResourceUri,
        [string]$KeyName,
        [string]$Key
    )

    $expiry = [int](Get-Date -UFormat %s) + 300
    $stringToSign = "$ResourceUri`n$expiry"
    $keyBytes = [Convert]::FromBase64String($Key)
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = $keyBytes
    $signatureBytes = $hmac.ComputeHash([System.Text.Encoding]::Utf8.GetBytes($stringToSign))
    $signature = [Convert]::ToBase64String($signatureBytes)
    $encodedResource = [System.Uri]::EscapeDataString($ResourceUri)
    $encodedSignature = [System.Uri]::EscapeDataString($signature)
    return "SharedAccessSignature sr=$encodedResource&sig=$encodedSignature&se=$expiry&skn=$KeyName"
}

function Test-ServiceBus {
    Log 'Starting Service Bus connectivity verification'
    $parts = Parse-ConnectionString $env:SB_CONNECTION_STRING
    $endpoint = $parts['endpoint']
    $keyName = $parts['sharedaccesskeyname']
    $key = $parts['sharedaccesskey']

    if (-not $endpoint) { Fail 'SB_CONNECTION_STRING missing Endpoint' }
    if (-not $keyName) { Fail 'SB_CONNECTION_STRING missing SharedAccessKeyName' }
    if (-not $key) { Fail 'SB_CONNECTION_STRING missing SharedAccessKey' }

    $host = ($endpoint -replace '^[^:]+://', '') -replace '/+$', ''
    $resourceUri = "https://$host"
    $sasToken = Get-ServiceBusSasToken -ResourceUri $resourceUri -KeyName $keyName -Key $key
    Log "Calling $resourceUri/\$Resources"

    try {
        Invoke-WebRequest -Uri "$resourceUri/\$Resources" -Headers @{ Authorization = $sasToken } -UseBasicParsing -Method Get -TimeoutSec 30 | Out-Null
    }
    catch {
        Fail "Service Bus management call failed: $_"
    }

    Log 'Service Bus token validation succeeded'
}

Ensure-Env 'SQL_CONNECTION_STRING' $env:SQL_CONNECTION_STRING
Ensure-Env 'SB_CONNECTION_STRING' $env:SB_CONNECTION_STRING
Log 'Connectivity gate starting'
Test-Sql
Test-ServiceBus
Log 'Connectivity gate succeeded'
