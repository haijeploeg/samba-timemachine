FROM alpine:3.11

ENV BACKUPDIR /backups
ENV SAMBA_VERSION "4.11.4-r0"

RUN apk --no-cache --no-progress update && \
    apk --no-cache --no-progress upgrade && \
    apk --no-cache --no-progress add bash shadow tzdata && \
    apk --no-cache --no-progress add samba="$SAMBA_VERSION" && \
    addgroup -S smb && \
    adduser -S -D -H -h /tmp -s /sbin/nologin -G smb -g 'Samba User' smbuser && \
    rm -rf /tmp/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

COPY smb.conf /etc/samba/smb.conf
COPY TimeMachine.quota.tmpl /etc/TimeMachine.quota.tmpl

EXPOSE 445

HEALTHCHECK --interval=60s --timeout=15s \
            CMD nc -zv localhost 445 || exit 1

VOLUME ["/backups"]

ENTRYPOINT ["/entrypoint.sh"]