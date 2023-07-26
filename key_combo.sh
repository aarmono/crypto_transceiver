#!/usr/bin/env sh
trap "kill %1; exit 0" INT TERM

. /etc/profile.d/shell_functions.sh

wait_initialized

A_PIN=`get_config_val Keypad AGPIONum`
B_PIN=`get_config_val Keypad BGPIONum`
D_PIN=`get_config_val Keypad DGPIONum`
UP_PIN=`get_config_val Keypad UpGPIONum`
DOWN_PIN=`get_config_val Keypad DownGPIONum`
BIAS=`get_config_val Keypad Bias`
ACTIVE=`get_config_val Keypad ActiveLow`
DEBOUNCE=`get_config_val Keypad Debounce`

exec key_combo "$A_PIN" "$B_PIN" "$D_PIN" "$UP_PIN" "$DOWN_PIN" "$BIAS" "$ACTIVE" "$DEBOUNCE"
