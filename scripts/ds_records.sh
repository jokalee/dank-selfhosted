#!/bin/sh

if [ $# -ne 1 ] ; then
  echo "usage: $0 DOMAIN"
  exit 1
fi

DOMAIN=$1

ldns-key2ds -n -1 /var/nsd/zones/master/${DOMAIN}.zone.signed
ldns-key2ds -n -2 /var/nsd/zones/master/${DOMAIN}.zone.signed
