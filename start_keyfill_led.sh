#!/usr/bin/env sh
trap "exit 0" INT TERM

. /etc/profile.d/shell_functions.sh

wait_initialized

PIN=`get_config_val PTT OutputGPIONum`
BIAS=`get_config_val PTT OutputBias`
ACTIVE=`get_config_val PTT OutputActiveLow`
DRIVE=`get_config_val PTT OutputDrive`

if test "$ACTIVE" -ne 0
then
	ACTIVE_ARG="-l"
fi

exec gpioset -m signal -B "$BIAS" -D "$DRIVE" $ACTIVE_ARG gpiochip0 "$PIN"=1
