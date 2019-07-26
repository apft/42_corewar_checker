#!/bin/bash

# 1: exec 1
# 2: exec 2
# 3: player
# 4: cycle
# 5: verbose level

run_test(){
	local exec1=$1
	local exec2=$2
	local cycle=$3
	local verbose_lvl=$4
	shift 4
	local players=$@

	$exec1 -v $verbose_lvl -d $cycle $players > vm1_output.tmp 2>&1
	$exec2 -v $verbose_lvl -d $cycle $players > vm2_output.tmp 2>&1
	diff vm1_output.tmp vm2_output.tmp > diff_output.tmp
}

run_tests(){
	local nb_of_cycles=`$VM1_EXEC -v 2 $PLAYERS | grep "It is now cycle" | tail -n 1 | cut -d ' ' -f 5 | bc`
	local min=1
	local max=$nb_of_cycles
	
	printf "Number of cycles: %d\n" $nb_of_cycles
	while [ $min -lt `echo "$max - 1" | bc` ];
	do
		cycle=`echo "($min + $max) / 2" | bc`
		run_test $VM1_EXEC $VM2_EXEC $cycle 0 $PLAYERS
		if [ -s diff_output.tmp ];then
			max=$cycle
		else
			min=$cycle
		fi
	done
	if [ $max -eq $nb_of_cycles ]; then
		printf "Same dump output\n"
	else
		printf "Dump differs at cycle %d\n" $max
		run_test $VM1_EXEC $VM2_EXEC $max 31 $PLAYERS
	fi
}

VM1_EXEC=$1
VM2_EXEC=$2
shift 2
PLAYERS=$@

run_tests
