#!/bin/bash

run_test(){
	$1 -d $4 $3 > vm1_output.tmp 2>&1
	$2 -d $4 $3 > vm2_output.tmp 2>&1
	diff vm1_output.tmp vm2_output.tmp > diff_output.tmp
}

run_tests(){
	local nb_of_cycles=`$VM1_EXEC -v 2 $PLAYER | tail -n 2 | head -n 1 | cut -d ' ' -f 5 | bc`
	local min=1
	local max=$nb_of_cycles
	
	printf "Number of cycles: %d\n" $nb_of_cycles
	while [ $min -lt `echo "$max - 1" | bc` ];
	do
#		printf "min: %d | max: %d\n" $min $max
		cycle=`echo "($min + $max) / 2" | bc`
#		printf "Cycle: %d\n" $cycle
		run_test $VM1_EXEC $VM2_EXEC $PLAYER $cycle
		if [ -s diff_output.tmp ];then
#			printf "Cycle %d: %s\n" $cycle "output differ"
			max=$cycle
		else
#			printf "Cycle %d: %s\n" $cycle "output is same"
			min=$cycle
		fi
	done
	printf "Dump differs at cycle %d\n" $max
	run_test $VM1_EXEC $VM2_EXEC $PLAYER $max
}

VM1_EXEC=$1
VM2_EXEC=$2
PLAYER=$3

run_tests
