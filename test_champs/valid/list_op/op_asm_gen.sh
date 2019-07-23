#!/bin/sh

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
	local line=$@

	local op=`extract_field 2 $line`
	local comment="$op: `extract_field 3 $line`"
	local args=`extract_field 4 $line`

	echo "$NAME \"$op\""
	echo "$COMMENT \"$comment\""
	echo
	echo $op $args
}

create_filename()
{
	local line=$@
	local op_num=`extract_field 1 $line`
	local op=`extract_field 2 $line`
	local comment=`extract_field 3 $line | tr ' ' '_'`

	echo "${op_num}_${op}-${comment}.s"
}

while read line
do
	count_sep="`echo $line | grep -o \"$SEPARATOR\" | wc -l | bc`"
	if [ "$line" -a $count_sep -eq 3 ]; then
		filename=`create_filename $line`
		create_content $line > $filename
	fi
done < $DATA
