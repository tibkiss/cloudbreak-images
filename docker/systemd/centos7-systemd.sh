#!/bin/bash

set -eiuo pipefail

## Cloudbreak related setup
if [[ $# -eq 3 ]]; then
    set -x
    cb_init_script_base64=$1
    ssh_user=$2
    ssh_pub_key=$3

    echo "${ssh_pub_key}" >> /home/${ssh_user}/.ssh/authorized_keys

    echo "${cb_init_script_base64}" | base64 -d > /usr/bin/cb-init.sh
    chmod +x /usr/bin/cb-init.sh
    /usr/bin/cb-init.sh
fi

exec -l /usr/lib/systemd/systemd --system
