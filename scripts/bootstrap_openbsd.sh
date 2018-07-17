#!/bin/sh

if [ $(id -u) -ne 0 ] ; then
  echo "this script must be run as root"
  exit 1
fi

echo 'https://cloudflare.cdn.openbsd.org/pub/OpenBSD' > /etc/installurl
pkg_add -xz python-2.7 ansible py-psycopg2
echo 'permit nopass :wheel' > /etc/doas.conf

echo "NOTE: /etc/doas.conf has been configured for PASSWORDLESS usage for all members of group 'wheel'."
echo "      You probably want to change this after running Ansible!"
