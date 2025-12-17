FROM mcr.microsoft.com/mssql-tools AS mssql_tools

FROM alpine:3.18

RUN apk add --no-cache ca-certificates curl gcompat jq openssl \
  && update-ca-certificates

ENV PATH=/opt/mssql-tools/bin:$PATH \
    LD_LIBRARY_PATH=/opt/microsoft/msodbcsql18/lib64:/opt/microsoft/odbc/lib64

COPY --from=mssql_tools /opt/mssql-tools /opt/mssql-tools
COPY --from=mssql_tools /opt/microsoft /opt/microsoft
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
