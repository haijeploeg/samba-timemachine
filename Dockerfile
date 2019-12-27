FROM alpine:3.11

ENV BACKUPDIR /backups

RUN apk --no-cache --no-progress update && \
    apk --no-cache --no-progress upgrade && \
    apk --no-cache --no-progress add bash samba shadow tzdata && \
    addgroup -S smb && \
    adduser -S -D -H -h /tmp -s /sbin/nologin -G smb -g 'Samba User' smbuser && \
    rm -rf /tmp/*

RUN mkdir -p ${BACKUPDIR}

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

COPY smb.conf /etc/samba/smb.conf
COPY TimeMachine.quota.tmpl /etc/TimeMachine.quota.tmpl

EXPOSE 445

HEALTHCHECK --interval=60s --timeout=15s \
            CMD smbclient -L '\\localhost' -U '%' -m SMB3

VOLUME ["/backups"]

ENTRYPOINT ["/entrypoint.sh"]