#!/bin/bash

if [ -f commons.sh ]; then
	. commons.sh
else
	printf "%s\n" "The commons.sh file is missing"
	exit 1
fi

print_usage_and_exit()
{
	printf "%s\n" "Usage: ./$0 [-bchl] [-v N] [-t N] [-f N] [-F N] [-m <1|2|3|4>] [-p <player>] exec player..."
	printf "%s\n" "  - [-b]               convert player .s file to bytecode first"
	printf "%s\n" "  - [-c]               clean directory at first"
	printf "%s\n" "  - [-a]               enable aff operator"
	printf "%s\n" "  - [-v N]             verbose mode (mode should be between 0 and 31)"
	printf "%s\n" "  - [-t N]             timeout value in seconds (default 10 seconds)"
	printf "%s\n" "  - [-l]               check for leaks"
	printf "%s\n" "  - [-h]               print this message and exit"
	printf "%s\n" "  - [-f N]             run N fights"
	printf "%s\n" "                          if enabled use the set of players to randomly populate"
	printf "%s\n" "                          the arena with 2, 3 or 4 players and let them fight,"
	printf "%s\n" "                          each player is unique in the arena"
	printf "%s\n" "  - [-F N]             same as -f except that a player can fight against himself"
	printf "%s\n" "  - [-m <1|2|3|4>]     set the maximum number of contestants (only works in fight mode)"
	printf "%s\n" "  - [-p <player>]      define a fixed contestant that will appear in all fights"
	printf "%s\n" "  - exec               path to your executable"
	printf "%s\n" "  - player             player (.cor file, or .s file with the -b option)"
	exit
}

print_winner()
{
	local output=$1

	printf "  "
	tail -n 1 $output | tr -d '\n'
}

timeout_fct()
{
	local bin=$1
	local tmp_out=$2
	local leak_file=$3
	shift 3
	local args=$@

	if [ "$bin" != "$VM_42" ]; then
		{ time `cmd_check_leaks $leak_file` $bin $args; } > $tmp_out 2>&1 &
	else
		{ time $bin $args; } > $tmp_out 2>&1 &
	fi
	local pid=$!
	sleep $TIMEOUT_VALUE &
	local pid_sleep=$!
	while ps -p $pid_sleep > /dev/null
	do
		if ! ps -p $pid > /dev/null; then
			kill $pid_sleep > /dev/null 2>&1
		fi
	done
	if ps -p $pid > /dev/null; then
		kill $pid && killall `basename $bin` > /dev/null 2>&1
		return $STATUS_TIMEOUT
	fi
	# remove last 4 lines of file (added by the time command)
	sed -i '' -e :a -e '$d;N;2,4ba' -e 'P;D' $tmp_out
	return 0
}

get_contestants()
{
	local nbr_of_contestants=$1
	local nbr_of_players=$2
	shift 2
	local list_contestants=""
	local contestant=""
	local index=$nbr_of_players
	local index_fixed=-1

	[ ! -z "$FIXED_CONTESTANT" ] && index_fixed=$((RANDOM % nbr_of_contestants + 1))
	while [ $nbr_of_contestants -gt 0 ]; do
		if [ $nbr_of_contestants -eq $index_fixed ]; then
			contestant=$FIXED_CONTESTANT
		else
			[ $nbr_of_players -gt 1 ] && index=$((RANDOM % nbr_of_players + 1))
			contestant="$(eval echo \${$index})"
		fi
		if [ $MODE -ne $MODE_FIGHT_RANDOM ]; then
			while echo $list_contestants | grep $contestant > /dev/null;
			do
				index=$((RANDOM % nbr_of_players + 1))
				contestant="$(eval echo \${$index})"
			done
		fi
		list_contestants+="$contestant "
		((nbr_of_contestants--))
	done
	printf "$list_contestants"
}

create_list_fights()
{
	local players=$@
	local nbr_of_players=$#
	local set_players=""
	local contestants=""
	local nbr_of_contestants=$NBR_OF_CONTESTANTS

	for i in `seq $NBR_OF_FIGHTS`
	do
		if [ $nbr_of_contestants -eq 0 ]; then
			nbr_of_contestants=$((RANDOM % 3 + 2))
		fi
		contestants="`get_contestants $nbr_of_contestants $nbr_of_players $players`"
		set_players+="$contestants;`get_basename $contestants`\n"
	done
	printf "$set_players"
}

get_list_fights()
{
	if [ $MODE -eq $MODE_FIGHT ]; then
		create_list_fights $@
	else
		echo "$@"
	fi
}

create_list_asm()
{
	local items=$@
	local list_asm=""

	for item in $items
	do
		list_asm+="`echo $item | rev | cut -d '.' -f 2- | rev`"
		list_asm+=".cor "
	done
	printf "$list_asm"
}

run_asm()
{
	local files=$@

	for file in $files
	do
		$ASM $file > /dev/null 2>&1
		[ $? -ne 0 ] && return $STATUS_ASM_FAILED
	done
	return $STATUS_SUCCESS
}

run_test()
{
	local vm1_exec=$VM_42
	local vm2_exec=$1
	shift
	local players=$@
	local nbr_of_players=$#
	local vm1_output_tmp="/tmp/corewar_checker_vm1_output.tmp"
	local vm2_output_tmp="/tmp/corewar_checker_vm2_output.tmp"
	local diff_tmp="diff_output.tmp"
	local list_asm full_paths only_names
	local diff_file leak_file
	local status vm1_status vm2_status
	local nbr_of_fights=$#

	local old_IFS=$IFS
	local new_IFS=$'\n'

	local list_fights=`get_list_fights $players`
	local first_column_width
	if [ $MODE -eq $MODE_FIGHT ]; then
		IFS=$new_IFS
		only_names="`echo "$list_fights" | cut -d ';' -f 2`"
		first_column_width=`compute_column_width $only_names`
		nbr_of_fights=`echo "$list_fights" | wc -l | bc`
	else
		first_column_width=`compute_column_width $list_fights`
	fi

	local i=0
	for fight in $list_fights
	do
		IFS=$old_IFS
		((i++))
		case $MODE in
			$MODE_FIGHT)
				full_paths=`echo $fight | cut -d ';' -f 1`
				only_names=`echo $fight | cut -d ';' -f 2`
				printf "%3d: %-*s  " $i $first_column_width "$only_names"
				;;
			*)
				full_paths=$fight
				only_names=`basename $fight`
				printf "%-*s  " $first_column_width "$fight"
				;;
		esac
		check_valid_file $list_contestants
		if [ $? -ne 0 ]; then
			((count_failure++))
		else
			tmp_file=`echo $only_names | sed -E 's/( )+/_-_/g'`
			leak_file=$LEAKS_DIR/`create_filename $tmp_file "leak"`
			if [ $RUN_ASM -eq 1 ]; then
				run_asm $full_paths
				status=$?
				if [ $status -ne $STATUS_SUCCESS ]; then
					print_status $status
					print_status $status
					printf "Could not convert to ASM\n"
					((count_failure++))
					continue
				fi
				list_asm="`create_list_asm $full_paths`"
			else
				list_asm="$full_paths"
			fi
			timeout_fct $vm1_exec $vm1_output_tmp $leak_file $OPT_A $OPT_V $list_asm 2> /dev/null
			vm1_status=$?
			print_status $vm1_status
			timeout_fct $vm2_exec $vm2_output_tmp $leak_file $OPT_A $OPT_V $list_asm 2> /dev/null
			get_status $? $leak_file
			vm2_status=$?
			print_status $vm2_status
			if [ $vm1_status -ne 0 -o $vm2_status -ne 0 ]; then
				local vm_timeout=0
				local vm_leaks=0
				for vm_status in $vm1_status $vm2_status
				do
					[ $vm_status -eq 0 ] && printf "ok      "
					[ $vm_status -eq $STATUS_TIMEOUT ] && print_error "timeout  " && vm_timeout=1
					[ $CHECK_LEAKS -ne 0 -a $vm_status -eq $STATUS_LEAKS ] && print_error "leaks    " && vm_leaks=1
				done
				[ $vm_timeout -eq 1 ] && ((count_timeout++))
				[ $vm_leaks -eq 1 ] && ((count_leaks++))
			else
				diff $vm1_output_tmp $vm2_output_tmp > $diff_tmp
				if [ -s $diff_tmp ]; then
					((count_failure++))
					diff_file=$DIFF_DIR/`create_filename $tmp_file "diff"`
					diff -y $vm1_output_tmp $vm2_output_tmp > $diff_file
					print_error "Booo!"
					printf " see $diff_file"
				else
					((count_success++))
					print_ok "Good!"
					print_winner $vm1_output_tmp
				fi
				rm $vm1_output_tmp $vm2_output_tmp
			fi
			printf "\n"
			[ $RUN_ASM -eq 1 ] && rm $list_asm
		fi
		IFS=$new_IFS
	done
	IFS=$old_IFS
	printf "\n"
	print_summary $nbr_of_fights
	[ -f $diff_tmp ] && rm $diff_tmp
}

DIFF_DIR=".diff"
LEAKS_DIR=".leaks"
DIRS="$DIFF_DIR $LEAKS_DIR"

VM_42="./resources/42_corewar"
ASM="resources/42_asm"

RUN_ASM=0
CLEAN_FIRST=0
CHECK_LEAKS=0
KILL_TIMEOUT=1
TIMEOUT_VALUE=10 #second
OPT_A=""
OPT_V=""
OPT_V_LIMIT_MIN=0
OPT_V_LIMIT_MAX=31

MODE_NORMAL=0
MODE_FIGHT=1
MODE_FIGHT_RANDOM=2
MODE=$MODE_NORMAL

NBR_OF_FIGHTS=0
NBR_OF_CONTESTANTS=0
FIXED_CONTESTANT=""

while getopts "bchav:t:lf:F:m:p:" opt
do
	case "$opt" in
		b)
			RUN_ASM=1
			;;
		c)
			CLEAN_FIRST=1
			;;
		a)
			OPT_A="-a"
			;;
		t)
			if echo $OPTARG | grep -E "^[0-9]+$" > /dev/null 2>&1; then
				TIMEOUT_VALUE=$OPTARG
			fi
			;;
		l)
			CHECK_LEAKS=1
			;;
		v)
			if echo $OPTARG | grep -E "^[0-9]+$" > /dev/null 2>&1; then
				if [ $OPTARG -ge $OPT_V_LIMIT_MIN -a $OPTARG -le $OPT_V_LIMIT_MAX ]; then
					OPT_V="-v $OPTARG"
				else
					print_usage_and_exit
				fi
			else
				print_usage_and_exit
			fi
			;;
		f|F)
			if echo $OPTARG | grep -E "^[0-9]+$" > /dev/null 2>&1; then
				printf "Fight mode enabled.\n"
				[ "$opt" = "r" ] && MODE=$MODE_FIGHT_RANDOM || MODE=$MODE_FIGHT
				NBR_OF_FIGHTS=$OPTARG
			else
				printf "Invalid number or fight, fight mode disabled...\n"
			fi
			;;
		m)
			if echo $OPTARG | grep -E "^[1-4]$" > /dev/null 2>&1; then
				NBR_OF_CONTESTANTS=$OPTARG
			else
				print_usage_and_exit
			fi
			;;
		p)
			if [ ! -f $OPTARG ]; then
				printf "The provided player (-p) is not a valid file: %s\n" $OPTARG
				exit
			fi
			FIXED_CONTESTANT=$OPTARG
			;;
		h|*)
			print_usage_and_exit
			;;
	esac
done
shift $((OPTIND - 1))

if [ $NBR_OF_CONTESTANTS -ne 0 -a $MODE -eq $MODE_NORMAL ]; then
	print_usage_and_exit
fi

if [ $# -lt 2 ]; then
	print_usage_and_exit
fi

NBR_OF_PLAYERS=$(($# - 1))
if [ ! -z $FIXED_CONTESTANT ]; then
	if ! echo $@ | grep $FIXED_CONTESTANT > /dev/null; then
		((NBR_OF_PLAYERS++))
	fi
fi
if [ $NBR_OF_CONTESTANTS -gt $NBR_OF_PLAYERS ]; then
	printf "The provided set of %s players is to small to generate fights with %s contestants.\n" $(($# - 1)) $NBR_OF_CONTESTANTS
	exit
fi

[ $CLEAN_FIRST -ne 0 ] && clean_dir $DIRS
check_executable $1
initialize_dir $DIRS
run_test $@
