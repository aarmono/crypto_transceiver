#!/usr/bin/env sh

exec /usr/sbin/pppoe-server -F -q /usr/sbin/pppd -Q /usr/sbin/pppoe -O /etc/ppp/options -S keyfill -C keyfill
