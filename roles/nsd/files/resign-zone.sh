#!/bin/sh

set -e

if [ $# -ne 1 ] ; then
  echo "usage: resign-zone DOMAIN"
  return 1
fi

if [ $(id -u) -ne 0 ] ; then
  echo "must be superuser"
  exit 1
fi

DOMAIN=$1


echo -n "computing new serial..."

SERIAL=$(grep -Eo "$(date +%Y%m%d)[[:digit:]]{2}" /var/nsd/zones/master/${DOMAIN}.zone || true)

if [ -z "$SERIAL" ] ; then
  SERIAL="$(date +%Y%m%d)00"
else
  SERIAL=$((( $SERIAL+1 )))
fi

sed -Ei "s/[[:digit:]]{10} ; serial/$SERIAL ; serial/" /var/nsd/zones/master/${DOMAIN}.zone

echo $SERIAL


echo -n "resigning zone..."

cd /var/nsd/keys

EXPIRE=$(echo "$(date +%s) + (30 * 24 * 60 * 60)" | bc)

/usr/local/bin/ldns-signzone -n -e $EXPIRE \
    -s $(head -n 1024 /dev/urandom | sha1 | cut -b 1-16) \
    -f /var/nsd/zones/master/${DOMAIN}.zone.signed \
    /var/nsd/zones/master/${DOMAIN}.zone \
    ${DOMAIN}.zsk \
    ${DOMAIN}.ksk

echo "expires $(date -r $EXPIRE +%Y-%m-%d)"


echo -n "reloading NSD..."

rcctl reload nsd > /dev/null

echo  "done"
