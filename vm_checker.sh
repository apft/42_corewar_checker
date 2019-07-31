#!/bin/bash

SCRIPT_PATH=`dirname $0`

ZAZ_42_COREWAR_STATUS_SUCCESS=43

ASM_DIR=".asm"
DIFF_DIR=".diff"
LEAKS_DIR=".leaks"
DIRS="$ASM_DIR $DIFF_DIR $LEAKS_DIR"

VM_42="$SCRIPT_PATH/resources/42_corewar"
ASM="$SCRIPT_PATH/resources/42_asm"

RUN_ASM=0
CLEAN_FIRST=0
CHECK_LEAKS=0
KILL_TIMEOUT=1
TIMEOUT_VALUE=10 #second
OPT_A=""
OPT_V=""
OPT_V_LIMIT_MIN=0
OPT_V_LIMIT_MAX=31

DIFF=0
FIGHT=0
FIGHT_RANDOM=0

NBR_OF_FIGHTS=0
NBR_OF_CONTESTANTS=-1
FIXED_CONTESTANT=""
FIXED_CONTESTANT_NAME=""

if [ -f "$SCRIPT_PATH/commons.sh" ]; then
	. "$SCRIPT_PATH/commons.sh"
else
	printf "%s\n" "The $SCRIPT_PATH/commons.sh file is missing"
	exit 1
fi

print_usage_and_exit()
{
	printf "%s\n" "Usage: $0 [-abcdhl] [-t N] [-v N] [-f N] [-F N] [-m <1|2|3|4>] [-p <player>] [-B asm] <corewar> <player>..."
	printf "%s\n" "    -a                 enable aff operator"
	printf "%s\n" "    -b                 convert all player file with an extension different to .cor into bytecode first"
	printf "%s\n" "    -c                 clean directory at first"
	printf "%s\n" "    -d                 enable diff mode"
	printf "%s\n" "                         compare exec output with corewar exec provided by 42 (zaz's corewar)"
	printf "%s\n" "    -h                 print this message and exit"
	printf "%s\n" "    -l                 check for leaks"
	printf "%s\n" "    -t N               timeout value in seconds (default 10 seconds)"
	printf "%s\n" "    -v N               verbose mode (mode should be between 0 and 31)"
	printf "%s\n" "    -f N               enable fight mode, run N fights"
	printf "%s\n" "                          if enabled use the set of players to randomly populate"
	printf "%s\n" "                          the arena with 2, 3 or 4 players and let them fight,"
	printf "%s\n" "                          each player is unique in the arena"
	printf "%s\n" "    -F N               same as -f except that a player can fight against himself"
	printf "%s\n" "    -m <1|2|3|4>       set the number of contestants (works only in fight mode)"
	printf "%s\n" "    -p <player>        define a fixed contestant that will appear in all fights (works only in fight mode)"
	printf "%s\n" "    -B <asm>           path to the asm executable to use to convert into bytecode with -b option (default to asm provided by 42)"
	printf "%s\n" "                          assume that the .cor file is created with the same pathname than the input file"
	printf "%s\n" "    <corewar>          path to your corewar executable"
	printf "%s\n" "    <player>...        list of players (.cor file, or .s file with the -b option)"
	exit 1
}

print_last_line_output()
{
	local output=$1

	printf "    "
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
	wait $pid
	return $?
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
		if [ $FIGHT_RANDOM -eq 0 ]; then
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
	local nbr_of_contestants=9999

	for i in `seq $NBR_OF_FIGHTS`
	do
		if [ $nbr_of_players -eq 1 ]; then
			nbr_of_contestants=1
		elif [ $NBR_OF_CONTESTANTS -eq -1 ]; then
			nbr_of_contestants=$((RANDOM % 3 + 2))
			while [ $nbr_of_contestants -gt $nbr_of_players ]
			do
				nbr_of_contestants=$((RANDOM % 3 + 2))
			done
		else
			nbr_of_contestants=$NBR_OF_CONTESTANTS
		fi
		contestants="`get_contestants $nbr_of_contestants $nbr_of_players $players`"
		set_players+="$contestants;`get_basename $contestants`\n"
	done
	printf "$set_players"
}

get_list_fights()
{
	if [ $FIGHT -eq 1 -o $FIGHT_RANDOM -eq 1 ]; then
		create_list_fights $@
	else
		echo "$@"
	fi
}

create_list_asm()
{
	local items=$@
	local list_asm=""
	local item_suffix=""

	for item in $items
	do
		item_suffix=`echo "$item" | rev | cut -c -4 | rev`
		if [ ${item_suffix:0:4} = ".cor" ]; then
			list_asm+="$item "
		else
			local main_part=`echo $item | rev | cut -d '.' -f 2- | rev`
			list_asm+="${main_part:-$item}.cor "
		fi
	done
	printf "$list_asm"
}

run_asm()
{
	local tmp_list=$1
	local log_file=$2
	shift 2
	local files=$@
	local file_suffix=""

	for file in $files
	do
		file_suffix=`echo "$file" | rev | cut -c -4 | rev`
		if [ ${file_suffix:0:4} != ".cor" ]; then
			$ASM $file > $log_file 2>&1
			[ $? -ne 0 ] && return $STATUS_ASM_FAILED
			local bytecode_file="`echo $file | rev | cut -d '.' -f 2- | rev`"
			echo "${bytecode_file:-$file}.cor" >> $tmp_list
			rm $log_file
		fi
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
	local asm_file diff_file leak_file
	local status vm1_status vm2_status
	local nbr_of_fights=$#
	local nbr_of_win_fixed_contestant=0
	local convert_to_bytecode_list="$ASM_DIR/list.txt"
	local vm_success vm_failure vm_timeout vm_leaks

	local old_IFS=$IFS
	local new_IFS=$'\n'

	local list_fights=`get_list_fights $players`
	local first_column_width
	if [ $FIGHT -eq 1 -o $FIGHT_RANDOM -eq 1 ]; then
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
		if [ $FIGHT -eq 1 -o $FIGHT_RANDOM -eq 1 ]; then
			full_paths=`echo $fight | cut -d ';' -f 1`
			only_names=`echo $fight | cut -d ';' -f 2`
			printf "%3d: %-*s  " $i $first_column_width "$only_names"
		else
			full_paths=$fight
			only_names=`basename $fight`
			printf "%-*s  " $first_column_width "$fight"
		fi
		check_valid_file $list_contestants
		if [ $? -ne 0 ]; then
			((count_failure++))
		else
			tmp_file=`echo $only_names | sed -E 's/( )+/_-_/g'`
			if [ $RUN_ASM -eq 1 ]; then
				asm_file=$ASM_DIR/`create_filename $tmp_file "asm"`
				run_asm $convert_to_bytecode_list $asm_file $full_paths
				status=$?
				if [ $status -ne $STATUS_SUCCESS ]; then
					print_status $status
					printf "Could not convert to bytecode"
					printf "  %s\n" "`cat $asm_file`"
					((count_failure++))
					continue
				fi
			fi
			list_asm="`create_list_asm $full_paths`"
			leak_file=$LEAKS_DIR/`create_filename $tmp_file "leak"`
			if [ $DIFF -eq 1 ]; then
				timeout_fct $vm1_exec $vm1_output_tmp $leak_file $OPT_A $OPT_V $list_asm 2> /dev/null
				vm1_status=$?
				[ $vm1_status -eq $ZAZ_42_COREWAR_STATUS_SUCCESS ] && vm1_status=$STATUS_SUCCESS
				print_status $vm1_status
			fi
			timeout_fct $vm2_exec $vm2_output_tmp $leak_file $OPT_A $OPT_V $list_asm 2> /dev/null
			get_status $? $vm2_output_tmp $leak_file
			vm2_status=$?
			print_status $vm2_status
			vm_success=0
			vm_failure=0
			vm_timeout=0
			vm_leaks=0
			if [ $DIFF -eq 1 ]; then
				if [ $vm1_status -eq 0 -a $vm2_status -eq 0 ]; then
					diff $vm1_output_tmp $vm2_output_tmp > $diff_tmp
					if [ -s $diff_tmp ]; then
						vm_failure=1
						diff_file=$DIFF_DIR/`create_filename $tmp_file "diff"`
						diff -y $vm1_output_tmp $vm2_output_tmp > $diff_file
						print_error "Booo!"
						printf " see $diff_file"
					else
						vm_success=1
						print_ok "Good!"
						if [ ! -z "$FIXED_CONTESTANT" ]; then
							if tail -n 1 $vm1_output_tmp | grep "$FIXED_CONTESTANT_NAME" > /dev/null; then
								((nbr_of_win_fixed_contestant++))
							fi
						fi
					fi
				fi
				[ $vm1_status -eq $STATUS_TIMEOUT ] && print_error "timeout  " && vm_timeout=1
				rm $vm1_output_tmp
			fi
			if [ $vm2_status -ne 0 ]; then
				if [ $vm2_status -eq $STATUS_SEGV ]; then
					print_error "segfault"
					vm_failure=1
				elif [ $vm2_status -eq $STATUS_TIMEOUT ]; then
					print_error "timeout"
					vm_timeout=1
				elif [ $vm2_status -eq $STATUS_LEAKS -a $CHECK_LEAKS -ne 0 ]; then
					print_error "leaks"
					vm_leaks=1
					vm_failure=1
				else
					print_last_line_output $vm2_output_tmp
					vm_failure=1
				fi
			else
				[ $DIFF -eq 0 ] && vm_success=1
				if [ $FIGHT -eq 1 -o $FIGHT_RANDOM -eq 1 ]; then
					[ $vm2_status -eq 0 ] && print_last_line_output $vm2_output_tmp
				fi
			fi
			printf "\n"
			[ $vm_success -eq 1 ] && ((count_success++))
			[ $vm_failure -eq 1 ] && ((count_failure++))
			[ $vm_timeout -eq 1 ] && ((count_timeout++))
			[ $vm_leaks -eq 1 ] && ((count_leaks++))
			rm $vm2_output_tmp
		fi
		IFS=$new_IFS
	done
	IFS=$old_IFS
	printf "\n"
	print_summary $nbr_of_fights
	if [ ! -z "$FIXED_CONTESTANT" ]; then
		printf "\n\"%s\" has won ${CYAN}%3d/%d${RESET} fights\n" "$FIXED_CONTESTANT_NAME" $nbr_of_win_fixed_contestant $nbr_of_fights
	fi
	if [ $RUN_ASM -eq 1 -a -f $convert_to_bytecode_list ]; then
	   uniq $convert_to_bytecode_list | xargs rm 2> /dev/null
	   rm $convert_to_bytecode_list
   fi
   [ -f $diff_tmp ] && rm $diff_tmp
}

while getopts "bchadv:t:lf:F:m:p:B:" opt
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
		d)
			DIFF=1
			;;
		v)
			if echo $OPTARG | grep -E "^[0-9]+$" > /dev/null 2>&1; then
				if [ $OPTARG -ge $OPT_V_LIMIT_MIN -a $OPTARG -le $OPT_V_LIMIT_MAX ]; then
					OPT_V="-v $OPTARG"
				else
					printf "%s\n\n" "Error: -v arg should be between $OPT_V_LIMIT_MIN and $OPT_V_LIMIT_MAX"
					print_usage_and_exit
				fi
			else
				printf "%s\n\n" "Error: -v arg should be a number"
				print_usage_and_exit
			fi
			;;
		f|F)
			if echo $OPTARG | grep -E "^[0-9]+$" > /dev/null 2>&1; then
				[ "$opt" = "f" ] && FIGHT=1 || FIGHT_RANDOM=1
				NBR_OF_FIGHTS=$OPTARG
			else
				printf "Invalid number or fight, fight mode disabled...\n"
			fi
			;;
		m)
			if echo $OPTARG | grep -E "^[1-4]$" > /dev/null 2>&1; then
				NBR_OF_CONTESTANTS=$OPTARG
			else
				printf "%s\n\n" "Error: -m arg should be between 1 and 4"
				print_usage_and_exit
			fi
			;;
		p)
			if [ ! -f $OPTARG ]; then
				printf "The provided player (-p) is not a valid file: %s\n" $OPTARG
				exit 1
			fi
			FIXED_CONTESTANT=$OPTARG
			FIXED_CONTESTANT_NAME=`strings $FIXED_CONTESTANT | head -n 1`
			;;
		B)
			if [ ! -x $OPTARG ]; then
				printf "The provided asm is not executable, use default asm.\n"
			else
				ASM=$OPTARG
				[ $(dirname $ASM) = '.' -a ${ASM:0:2} != "./" ] && ASM="./$ASM"
			fi
			;;
		h|*)
			print_usage_and_exit
			;;
	esac
done
shift $((OPTIND - 1))

if [ $FIGHT -eq 1 -a $FIGHT_RANDOM -eq 1 ]; then
	printf "%s\n\n" "Error: choose a fight mode"
	print_usage_and_exit
fi

if [ $FIGHT -eq 0 -a $FIGHT_RANDOM -eq 0 ]; then
	if [ $NBR_OF_CONTESTANTS -ne -1 -o ! -z "$FIXED_CONTESTANT" ]; then
		printf "%s\n\n" "Error: fight mode not enabled"
		print_usage_and_exit
	fi
fi

if [ $# -lt 2 ]; then
	print_usage_and_exit
fi

NBR_OF_PLAYERS=$(($# - 1))
if [ $NBR_OF_PLAYERS -eq 1 -a $FIGHT -eq 1 ]; then
	printf "%s\n" "Not enough player ($NBR_OF_PLAYERS) to run the fight mode"
	exit 1
fi
if [ ! -z "$FIXED_CONTESTANT" ]; then
	if ! echo $@ | grep "$FIXED_CONTESTANT" > /dev/null; then
		((NBR_OF_PLAYERS++))
	fi
fi
if [ $NBR_OF_CONTESTANTS -gt $NBR_OF_PLAYERS ]; then
	printf "The provided set of %s players is to small to generate fights with %s contestants.\n" $(($# - 1)) $NBR_OF_CONTESTANTS
	exit 1
fi

[ $CLEAN_FIRST -ne 0 ] && clean_dir $DIRS
check_executable $1
initialize_dir $DIRS
[ $FIGHT -eq 1 -o $FIGHT_RANDOM -eq 1 ] && printf "Fight mode enabled.\n"
run_test $@
