#!/usr/bin/env sh
trap "exit 0" INT TERM

. /etc/profile.d/shell_functions.sh

wait_initialized

UP=`get_config_val Volume UpGPIONum`
DOWN=`get_config_val Volume DownGPIONum`
BIAS=`get_config_val Volume Bias`
ACTIVE=`get_config_val Volume ActiveLow`
DEBOUNCE=`get_config_val Volume Debounce`

exec volume_buttons "$UP" "$DOWN" "$BIAS" "$ACTIVE" "$DEBOUNCE"
