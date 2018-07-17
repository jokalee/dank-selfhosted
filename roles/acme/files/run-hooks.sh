#!/bin/sh

if [ -z "$(ls /etc/acme/hooks.d)" ] ; then
  echo "no hooks to run"
  exit 0
fi

for file in /etc/acme/hooks.d/* ; do
  $file
done

