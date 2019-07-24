#!/bin/sh

ASM_42="resources/asm_42"
ASM_USR=""
CHAMPIONS_FOLDER="test_champs"
CHAMPIONS="`find ${CHAMPIONS_FOLDER} -type f`"
CHAMPIONS+=" /dev/null /dev/random /dev/urandom"

CHECK_LEAKS=0

DIR_LEAKS=".leaks"
STATUS_LEAKS=2

# Colors
RED='\x1b[0;31m'
GREEN='\x1b[0;32m'
YELLOW='\x1b[0;33m'
BLUE='\x1b[0;34m'
MAGENTA='\x1b[0;35m'
B_RED='\x1b[1;31m'
B_GREEN='\x1b[1;32m'
B_YELLOW='\x1b[1;33m'
B_BLUE='\x1b[1;34m'
B_MAGENTA='\x1b[1;35m'
NC='\x1b[0m'

print_error(){
	printf "${RED}%s${NC}\n" "$1"
}

print_ok(){
	printf "${GREEN}%s${NC}\n" "$1"
}

print_warn(){
	printf "${YELLOW}%s${NC}\n" "$1"
}

print_usage()
{
	echo "usage:"
	echo "\t$0 asm [-lc] [champions...]"
	echo "\t    - [-l]\t\tcheck for leaks (use valgrind)"
	echo "\t    - [-c]\t\tclear dir"
	echo "\t    - asm\t\tpath to your asm executable file"
	echo "\t    - champions\t\tpath to each champion files to test, if empty use a set of predefine champions stored in the \`${CHAMPIONS_FOLDER}' folder"
}

print_usage_and_exit()
{
	print_usage
	exit 1
}

print_error_and_exit()
{
	printf "Error: %s\n" "$1"
	exit 1
}

initialize_dir()
{
	for dir in $DIR_LEAKS
	do
		[ ! -d $dir ] && mkdir $dir
	done
}

clean_dir()
{
	for dir in $DIR_LEAKS
	do
		[ -d $dir ] && rm -R $dir
	done
}

check_leaks()
{
	local leak_file=$1
	local definitely_lost="^==[0-9]+==\s+definitely lost: 0 bytes in 0 blocks$"
	local indirectly_lost="^==[0-9]+==\s+indirectly lost: 0 bytes in 0 blocks$"
	local still_reachable="^==[0-9]+==\s+still reachable: 200 bytes in [0-9] blocks$"

	for leak in "$definitely_lost" "$indirectly_lost" "$still_reachable"
	do
		if ! grep -E "$leak" $leak_file > /dev/null; then
			return $STATUS_LEAKS
		fi
	done
	rm $leak_file
	return 0
}

get_status()
{
	local status=$1
	local leak_file=$2
	local status_leaks

	if [ $CHECK_LEAKS -ne 0 ]; then
		check_leaks $leak_file
		[ $? -eq $STATUS_LEAKS ] && return $STATUS_LEAKS
	fi
	[ $status -ne 0 ] && return $status
	return 0
}

print_status_asm()
{
	if [ $1 -eq 0 ]; then
		printf "${B_GREEN}✔ ${NC}"
	else
		printf "${B_RED}✗ ${NC}"
	fi
}

print_output()
{
	local width=$1
	shift
	local status=$1
	shift
	local output="$@"
	local msg=`cat "$output" | tr '\n' ' '`

	if [ $status -eq 139 ]; then
		printf "${RED}%-70s${NC}" "segfault"
	else
		printf "%-*s" $width "$msg"
	fi
}

run_checks()
{
	local output_42=".output_42"
	local output_usr=".output_usr"
	local bytecode_42=".bytecode_42"
	local bytecode_usr=".bytecode_usr"
	local status_42 status_usr asm_file
	local valgrind_log valgrind_cmd

	for champ in $CHAMPIONS
	do
		valgrind_log="$DIR_LEAKS/`basename $champ`.leaks"
		if [ $CHECK_LEAKS -ne 0 ]; then
			valgrind_cmd="valgrind --log-file=$valgrind_log --leak-check=full"
		else
			valgrind_cmd=""
		fi

		asm_file=`echo $champ | rev | cut -d '.' -f 2- | rev`
		asm_file+=".cor"
		printf "%-60s" $champ
		$valgrind_cmd ./$ASM_USR $champ > $output_usr 2>&1
		get_status $? $valgrind_log
		status_usr=$?
		print_status_asm $status_usr
		[ -f $asm_file ] && mv $asm_file $bytecode_usr
		./$ASM_42 $champ > $output_42 2>&1
		status_42=$?
		print_status_asm $status_42
		[ -f $asm_file ] && mv $asm_file $bytecode_42

		if [ $status_usr -eq $STATUS_LEAKS ]; then
			printf "${RED}%-8s${NC} %s" "leaks" "see $valgrind_log"
			printf "\n"
			continue
		elif [ $status_usr -ne 0 -a $status_42 -ne 0 ]; then
			printf "${GREEN}%-8s${NC}" "good"
		elif [ $status_usr -eq 0 -a $status_42 -eq 0 ]; then
			local diff=`diff $bytecode_42 $bytecode_usr 2>&1`
			if [ "$diff" ];then
				printf "${RED}%-8s${NC} %s" "error" "bytecode files differ"
			else
				printf "${GREEN}%-8s${NC}" "success"
			fi
		else
			printf "${RED}%-8s${NC}" "error"
		fi
		[ $status_usr -ne 0 ] && print_output 70 $status_usr $output_usr
		[ $status_42 -ne 0 ] && print_output 110 $status_42 $output_42
		printf "\n"
	done
	rm $output_42 $output_usr $bytecode_42 $bytecode_usr
}

while getopts "lc" opt
do
	case $opt in
		c)
			clean_dir
			;;
		l)
			CHECK_LEAKS=1
			;;
		*)
			print_usage_and_exit
			;;
	esac
done
shift $((OPTIND - 1))
[ ! -x "$ASM_42" ] && chmod u+x "$ASM_42"
[ $# -lt 1 ] && print_usage_and_exit
[ ! -x $1 ] && print_error_and_exit "the file '$1' is not executable"
ASM_USR="$1"
shift
[ $# -gt 0 ] && CHAMPIONS="$@"
initialize_dir
run_checks 2> /dev/null
