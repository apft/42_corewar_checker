#!/bin/bash

# 1: exec 1
# 2: exec 2
# 3: player
# 4: cycle
# 5: verbose level
run_test(){
	$1 -v $5 -d $4 $3 > vm1_output.tmp 2>&1
	$2 -v $5 -d $4 $3 > vm2_output.tmp 2>&1
	diff vm1_output.tmp vm2_output.tmp > diff_output.tmp
}

run_tests(){
	local nb_of_cycles=`$VM1_EXEC -v 2 $PLAYER | grep "It is now cycle" | tail -n 1 | cut -d ' ' -f 5 | bc`
	local min=1
	local max=$nb_of_cycles
	
	printf "Number of cycles: %d\n" $nb_of_cycles
	while [ $min -lt `echo "$max - 1" | bc` ];
	do
		cycle=`echo "($min + $max) / 2" | bc`
		run_test $VM1_EXEC $VM2_EXEC $PLAYER $cycle 0
		if [ -s diff_output.tmp ];then
			max=$cycle
		else
			min=$cycle
		fi
	done
	printf "Dump differs at cycle %d\n" $max
	run_test $VM1_EXEC $VM2_EXEC $PLAYER $max 31
}

VM1_EXEC=$1
VM2_EXEC=$2
PLAYER=$3

run_tests
