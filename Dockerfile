FROM alpine:3.15

ENV BACKUPDIR /backups

RUN apk --no-cache --no-progress update && \
    apk --no-cache --no-progress add bash shadow tzdata && \
    apk --no-cache --no-progress add samba && \
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
