#!/bin/bash
set -e -o pipefail

# QUOTA_SIZE is in Mebibyte
# 488181 = 512GB
# 572205 = 600GB
# 667572 = 700GB
export QUOTA_SIZE="${QUOTA_SIZE:-572205}"
export QUOTA_TM=$((QUOTA_SIZE * 1048576))

# declare arrays
declare -A users
declare -A passwords

echo "Checking if backup directory is properly mounted..."
if ! grep "${BACKUPDIR}" /proc/mounts | awk '{print $1}' &> /dev/null; then
    echo "${BACKUPDIR} not found. Did you add a volume for ${BACKUPDIR}?"
    exit 1
fi

echo "Reading environment variables..."
while IFS='=' read -r name value; do
  if [[ $name == 'USER_'* ]]; then
    users[$name]=$value
  elif [[ $name == 'PASSWORD_'* ]]; then
    passwords[$name]=$value
  fi
done < <(env)

echo "Checking if users are properly configured..."
if [ ${#users[@]} != ${#passwords[@]} ]; then
  echo "Amount of users and passwords don't match, please verify your environment."
  exit 1
elif [[ ${#users[@]} == 0 || ${#passwords[@]} == 0 ]]; then
  echo "No users or passwords found, please verify your environment."
fi

for USERNAME in ${users[@]};
do
    PASSWORD=${passwords["PASSWORD_${USERNAME^^}"]}
    DIR=$BACKUPDIR/$USERNAME

    if ! id -u ${USERNAME} &> /dev/null; then
        echo "Creating user ${USERNAME}..."
        useradd --home "/backups/${USERNAME}" --shell /bin/nologin --no-create-home "${USERNAME}"
    fi

    if ! pdbedit -L | grep ${USERNAME} &> /dev/null; then
        echo "Setup SAMBA authentication for ${USERNAME}..."
        printf "%s\n%s\n" "${PASSWORD}" "${PASSWORD}" | smbpasswd -a -s "${USERNAME}"
    fi

    if [ ! -d "$DIR" ]; then
        echo "Creating backup directory for ${USERNAME}..."
        mkdir "${DIR}"
    fi
    touch "${DIR}/.com.apple.TimeMachine.supported"
    sed "s/<integer>.*<\/integer>/<integer>${QUOTA_TM}<\/integer>/g" /etc/TimeMachine.quota.tmpl > "${DIR}/.com.apple.TimeMachine.quota.plist"

    echo "Configuring permissions on ${DIR}..."
    chown -R "${USERNAME}:${USERNAME}" "${DIR}"
    chmod -R u+rwX,g+rwX,o= "${DIR}"
done

echo "Set quota for SAMBA..."
sed -i "s/fruit:time machine max size.*/fruit:time machine max size = ${QUOTA_SIZE}M/g" /etc/samba/smb.conf

echo "=================================================="
echo "=           Starting SAMBA TimeMachine           ="
echo "=================================================="
exec /usr/sbin/smbd --no-process-group --debug-stdout --foreground "$@"
