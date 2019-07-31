#!/bin/sh

if [ $# -ne 1 ]; then
	printf "Usage: $0 folder\n"
	exit
fi

FOLDER=$1

[ ! -d $FOLDER ] && mkdir $FOLDER

DATA="list.txt"
SEPARATOR=";"

NAME=".name"
COMMENT=".comment"

extract_field()
{
	local field="$1"
	shift
	echo $@ | cut -d "$SEPARATOR" -f $field
}

create_content()
{
	local count_sep=$1
	shift
	local line=$@

	local op=`extract_field 2 $line`
	local comment="$op: `extract_field 3 $line`"
	local args=`extract_field 4 $line`

	echo "$NAME \"$op\""
	echo "$COMMENT \"$comment\""
	echo
	i=4
	while [ $i -le $count_sep ]
	do
		echo `extract_field $((i + 1)) $line`
		((i++))
	done
	echo $op $args
}

create_filename()
{
	local line=$@
	local op_num=`extract_field 1 $line`
	local op=`extract_field 2 $line`
	local comment=`extract_field 3 $line | tr ' ' '_'`

	echo "$FOLDER/${op_num}_${op}-${comment}.s"
}

while read line
do
	count_sep="`echo $line | grep -o \"$SEPARATOR\" | wc -l | bc`"
	if [ "$line" -a $count_sep -ge 3 ]; then
		filename=`create_filename $line`
		create_content $count_sep $line > $filename
	fi
done < $DATA
