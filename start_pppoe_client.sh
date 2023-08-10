#!/usr/bin/env sh

exec /usr/sbin/pppd pty '/usr/sbin/pppoe -S keyfill -C keyfill' nodetach
