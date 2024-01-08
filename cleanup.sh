#!env bash

set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
type multipass >/dev/null 2>&1 || { echo >&2 "multipass required but it's not installed; aborting."; exit 1; }

domain="${1-k8s}"

instances=$(multipass list | grep "^${domain}" | awk '{print $1}' | tr '\n' ' ')
multipass delete --purge ${instances}

echo "Done!"
