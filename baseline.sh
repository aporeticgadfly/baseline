#!/bin/bash

#Desc: creates file system baseline or compares current to previous baseline
#Usage: ./baseline.sh [-d path] <file1> [<file2>]
# if only 1 file specified, a new baseline created
# file2 is previous baseline file to compare

function usageErr() {
	echo 'usage: baseline.sh [-d path] <file1> [<file2>]'
	echo 'creates or compares baseline from path'
	echo 'default for path is /'
	exit 2
} >& 2

function dosumming() {
	find "${DIR[@]}" -type f | xargs -d '\n' sha1sum
}

function parseArgs() {
	while getopts "d:" MYOPT
	do
		DIR+=( "$OPTARG" )
	done

	shift $((OPTIND-1))
	SHIFTS=$((OPTIND-1))

	(( $# == 0 || $# > 2 )) && usageErr
	(( ${#DIR[*]} == 0 )) && DIR=( "/" )
}

declare -a DIR

parseArgs $@
shift $SHIFTS

BASE="$1"
B2ND="$2"

#if only 1 arg supplied, create baseline
if (( $# == 1 ))
then
	dosumming > "$BASE"
	exit
fi

#if 2 args supplied but 1st does not exist, give error
if [[ ! -r "$BASE" ]]
then
	usageErr
fi

#if 2nd file exists compare the two, else create and fill it
if [[ ! -e "$B2ND" ]]
then
	echo creating "$B2ND"
	dosumming > "$B2ND"
fi

declare -A BYPATH BYHASH INUSE 

#load first file
while read HNUM FN
do
	BYPATH["$FN"]=$HNUM
	BYHASH[$HNUM]="$FN"
	INUSE["$FN"]="X"
done < "$BASE"

printf '<filesystem host="%s" dir="%s">\n' "$HOSTNAME" "${DIR[*]}"

while read HNUM FN
do
	WASHASH="${BYPATH[${FN}]}"
	if [[ -z $WASHASH ]]
	then
		ALTFN="${BYHASH[$HNUM]}"
		if [[ -z $ALTFN ]]
		then
			printf '    <new>%s</new>\n' "$FN"
		else
			printf '  <relocated orig="%s">%s</relocated>\n' "$ALTFN" "$FN"
			INUSE["$ALTFN"]='_' #mark as seen
		fi
	else
		INUSE["$FN"]='_'
		if [[ $HNUM == $WASHASH ]]
		then
			continue
		else
			printf ' <changed>%s</changed>\n' "$FN"
		fi
	fi
done < "$B2ND"

for FN in "${!INUSE[@]}"
do
	if [[ "${INUSE[$FN]}" == 'X' ]]
	then
		printf '    <removed>%s</removed>\n' "$FN"
	fi
done

printf '</filesystem>\n'

