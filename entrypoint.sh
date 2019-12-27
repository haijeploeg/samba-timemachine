#!/bin/bash
set -e -o pipefail

export QUOTA_SIZE="${QUOTA_SIZE:-512000}"

INITALIZED="/.initialized"
QUOTA_TM=$((QUOTA_SIZE * 1048576))

echo "Checking if requirements are met..."
if [ ! "$(env | grep '^USER_')" ] || [ ! "$(env | grep '^PASSWORD_')" ]; then
    echo "Some required environment variables are not set. Did you specify USER_<username> and PASSWORD_<username>?"
    exit 1
fi
if ! grep "${BACKUPDIR}" /proc/mounts | awk '{print $1}' ; then
    echo "${BACKUPDIR} not found did you forget to add the volume?"
    exit 1
fi

for USER in "$(env | grep '^USER_')"
do
    USERNAME=$(echo "${USER}" | cut -d '=' -f2)
    USERNAME_UPPER="$(printf '%s\n' "${USERNAME}" | awk '{ print toupper($0) }')"
    PASSWORD=$(env | grep '^PASSWORD_'"${USERNAME_UPPER^^}" | cut -d '=' -f2)
    DIR=$BACKUPDIR/$USERNAME

    echo "Creating user ${USERNAME}..."
    if [ ! $(id -u ${USERNAME} > /dev/null 2&>1) ]; then
        useradd --home "/backups/${USERNAME}" --shell /bin/nologin --no-create-home "${USERNAME}"
    fi

    echo "Setup SAMBA authentication for ${USERNAME}..."
    printf "%s\n%s\n" "${PASSWORD}" "${PASSWORD}" | smbpasswd -a -s "${USERNAME}"

    echo "Configure backup directory for ${USERNAME}..."
    if [ ! -d "$DIR" ]; then
        mkdir "${DIR}"
    fi
    touch "${DIR}/.com.apple.TimeMachine.supported"
    sed "s%TM_SIZE%${QUOTA_TM}%" /etc/TimeMachine.quota.tmpl > "${DIR}/.com.apple.TimeMachine.quota.plist"

    echo "Configuring permissions on ${DIR}..."
    chown -R "${USERNAME}:${USERNAME}" "${DIR}"
    chmod -R u+rwX,g=,o= "${DIR}"
done

echo "Set quota of SAMBA..."
sed -i "s/fruit:time machine max size.*/fruit:time machine max size = ${QUOTA_SIZE}M/g" /etc/samba/smb.conf

echo "=================================================="
echo "=           Starting SAMBA TimeMachine           ="
echo "=================================================="
exec /usr/sbin/smbd --no-process-group --log-stdout --foreground "$@"