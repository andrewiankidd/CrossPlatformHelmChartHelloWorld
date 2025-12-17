#!/bin/sh
set -eo pipefail

log() {
  printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

require_env() {
  var="$1"
  if [ -z "$(eval "printf '%s' \"\${${var}:-}\"")" ]; then
    fail "Missing environment variable $var"
  fi
}

parse_sql_connection_string() {
  sql_server=""
  sql_user=""
  sql_password=""
  sql_database="master"

  while IFS= read -r pair; do
    pair=$(printf '%s' "$pair" | sed -e 's/^ *//' -e 's/ *$//')
    [ -z "$pair" ] && continue
    key=$(printf '%s' "$pair" | cut -d'=' -f1 | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
    value=$(printf '%s' "$pair" | cut -d'=' -f2-)
    value=$(printf '%s' "$value" | sed -e 's/^ *//' -e 's/ *$//')
    case "$key" in
      server|data-source|datasource)
        sql_server="$value"
        ;;
      database|initialcatalog|initial-catalog)
        sql_database="$value"
        ;;
      user|userid|user-id)
        sql_user="$value"
        ;;
      password|pwd)
        sql_password="$value"
        ;;
    esac
  done <<EOF
$(printf '%s\n' "$SQL_CONNECTION_STRING" | tr ';' '\n')
EOF

  [ -n "$sql_server" ] || fail "SQL_CONNECTION_STRING missing Server or Data Source"
  [ -n "$sql_user" ] || fail "SQL_CONNECTION_STRING missing User or User Id"
  [ -n "$sql_password" ] || fail "SQL_CONNECTION_STRING missing Password"
}

parse_service_bus_connection_string() {
  sb_endpoint=""
  sb_key_name=""
  sb_key=""

  while IFS= read -r pair; do
    pair=$(printf '%s' "$pair" | sed -e 's/^ *//' -e 's/ *$//')
    [ -z "$pair" ] && continue
    key=$(printf '%s' "$pair" | cut -d'=' -f1 | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
    value=$(printf '%s' "$pair" | cut -d'=' -f2-)
    value=$(printf '%s' "$value" | sed -e 's/^ *//' -e 's/ *$//')
    case "$key" in
      endpoint)
        sb_endpoint="$value"
        ;;
      sharedaccesskeyname)
        sb_key_name="$value"
        ;;
      sharedaccesskey)
        sb_key="$value"
        ;;
    esac
  done <<EOF
$(printf '%s\n' "$SB_CONNECTION_STRING" | tr ';' '\n')
EOF

  [ -n "$sb_endpoint" ] || fail "SB_CONNECTION_STRING missing Endpoint"
  [ -n "$sb_key_name" ] || fail "SB_CONNECTION_STRING missing SharedAccessKeyName"
  [ -n "$sb_key" ] || fail "SB_CONNECTION_STRING missing SharedAccessKey"
}

test_sql() {
  log "Running SQL Server check"
  parse_sql_connection_string
  log "Executing SELECT 1 against $sql_server"
  sqlcmd -S "$sql_server" -d "$sql_database" -U "$sql_user" -P "$sql_password" -Q "SET NOCOUNT ON; SELECT 1" -b >/dev/null 2>&1
}

test_service_bus() {
  log "Running Service Bus check"
  parse_service_bus_connection_string
  cleaned=$(printf '%s' "$sb_endpoint" | sed -e 's~^[^:]*://~~' -e 's~/*$~~')
  host=$(printf '%s' "$cleaned" | cut -d'/' -f1)
  resource_uri="https://$host"
  expiry=$(( $(date +%s) + 300 ))
  sign_input="$resource_uri\n$expiry"
  signature=$(printf '%s' "$sign_input" | openssl dgst -sha256 -hmac "$sb_key" -binary | openssl base64)
  encoded_resource=$(jq -nr --arg s "$resource_uri" '$s|@uri')
  encoded_signature=$(jq -nr --arg s "$signature" '$s|@uri')
  sas_token="SharedAccessSignature sr=$encoded_resource&sig=$encoded_signature&se=$expiry&skn=$sb_key_name"
  log "Calling $resource_uri/\$Resources"
  curl --fail --silent --show-error -H "Authorization: $sas_token" -H "Accept: application/json" "$resource_uri/\$Resources" >/dev/null
}

main() {
  require_env SQL_CONNECTION_STRING
  require_env SB_CONNECTION_STRING
  log "Connectivity gate starting"
  test_sql
  test_service_bus
  log "Connectivity gate succeeded"
}

main "$@"
