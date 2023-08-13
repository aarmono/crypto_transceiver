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

if test "$1" -gt 0
then
	MODE="time"
	TIME_ARG="-u $1"
else
	MODE="signal"
fi

exec gpioset -m "$MODE" $TIME_ARG -B "$BIAS" -D "$DRIVE" $ACTIVE_ARG gpiochip0 "$PIN"=1
