#!env bash

set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
type multipass >/dev/null 2>&1 || { echo >&2 "multipass required but it's not installed; aborting."; exit 1; }

instances=$(multipass list | grep "^k8s" | awk '{print $1}')

for instance in $instances; do
  echo "Removing $instance ..."
  multipass delete $instance
done

multipass purge

echo "Done!"
