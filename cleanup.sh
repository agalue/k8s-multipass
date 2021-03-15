#!/usr/local/bin/bash

instances=$(multipass list | grep "^k8s" | awk '{print $1}')

for instance in $instances; do
  echo "Removing $instance ..."
  multipass delete $instance
done

echo "Done!"
