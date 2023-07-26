#!/usr/bin/env sh
trap "kill %1; exit 0" INT TERM

. /etc/profile.d/shell_functions.sh

wait_initialized

A_PIN=`get_config_val Selector AGPIONum`
B_PIN=`get_config_val Selector BGPIONum`
D_PIN=`get_config_val Selector DGPIONum`
BIAS=`get_config_val Selector Bias`
ACTIVE=`get_config_val Selector ActiveLow`
DEBOUNCE=`get_config_val Selector Debounce`

exec key_combo "$A_PIN" "$B_PIN" "$D_PIN" "$BIAS" "$ACTIVE" "$DEBOUNCE"
