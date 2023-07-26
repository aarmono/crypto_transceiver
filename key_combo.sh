#!/usr/bin/env sh
trap "kill %1; exit 0" INT TERM

. /etc/profile.d/shell_functions.sh

wait_initialized

A_PIN=`get_config_val Combo AGPIONum`
B_PIN=`get_config_val Combo BGPIONum`
BIAS=`get_config_val Combo Bias`
ACTIVE=`get_config_val Combo ActiveLow`
DEBOUNCE=`get_config_val Combo Debounce`

exec key_combo "$A_PIN" "$B_PIN" "$BIAS" "$ACTIVE" "$DEBOUNCE"
