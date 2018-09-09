#! /bin/bash

# TODO: 
# - distribution of csv files to TA's is not currently handled
#   what is blocking: figure out the best way to enter grades
# - groepcheck is disabled
#   what is blocking: figure out the best way to handle grades/feedback in bs
#   for the user(s) that did not submit the original file
# - assigning students to fixed TA's
#   what is blocking: figure out how to use group info provided by BrightSpace

# ---------------------- configuratie ------------------------#

typeset -A email
email[marc]="mschool@science.ru.nl"
#email[ko]="kstoffelen@science.ru.nl"
#email[pol]="paubel@science.ru.nl"

SUBJECT="`whoami` could not be bothered to configure SUBJECT"

# ---------------------- end of config -----------------------#

# this script takes care of the distribution of workload over
# all the teaching assistants, after downloading the zip

shopt -s nullglob
set -e

MYDIR="${0%/*}"
PATH="${PATH}:${MYDIR}"

for ta in "${!email[@]}"; do
	if [ ! -z "`ls "$ta" 2>/dev/null`" ]; then
		echo $ta exists. Clean up first.
		exit
	fi
done

CSV=""
for csv in *.csv; do
	echo "Assuming student info is in $csv"
	if [ "$CSV" ]; then
		echo "Please select which .csv file to use."
		select csv in *.csv; do
			test ! -e "$csv" && continue
			CSV="$csv"
			break
		done
		break
	fi
	CSV="$csv"
done

for zip in *.zip; do
	echo "Which .zip file contains the assignments?"
	select zip in *.zip; do
		test ! -e "$zip" && continue
		echo Unbrightspacing "$zip"
		"$MYDIR"/bsunzip.sh "$zip"
		break
	done
	break
done
assignment="${zip%%Download*}"

if [ -z "$zip" ]; then
	echo Please download a .zip before trying to distribute one.
	exit 37
fi

echo Trying to adjust for student creativity.
"$MYDIR"/antifmt.sh */

if [ "$CSV" ]; then
	echo Identifying submissions
	"$MYDIR"/identify.sh "$CSV" */
fi

echo 
echo Trial compilation
"$MYDIR"/trialc.sh */

echo
echo Doing a rough plagiarism check
"$MYDIR"/dupes.sh */

echo

# first read a list of students that are assigned fixed ta's (group_$name); the format of this file
# can be the same as the userlist-file, but only the first column matters
#for ta in "${!email[@]}"
#do
#    listfile="$MYDIR/group_${ta}"
#    test -e "$listfile" || continue
#    echo "Distributing workload to $ta"
#    mkdir -p "$ta"
#    while read stud trailing; do
#	[ -e "$stud" ] && mv "$stud" "$ta"
#    done < "$listfile"
#done

test "${!email[@]}"

echo Randomly distributing workload 
"$MYDIR"/hak3.sh "${!email[@]}" 

humor=$(iching.sh)
for ta in "${!email[@]}"
do
    cp -n "$MYDIR"/{pol.sh,rgrade.sh,collectplag.sh} "$ta"
    if [ "$CSV" ]; then
	cp "$CSV" "$ta/grades.csv"
	sed -f - "$MYDIR"/mailto.sh > "${ta}/mailto.sh" <<-...
	    /^FROM=/c\
	    FROM="${email[$ta]}"
	    /^PREFIX=/c\
	    PREFIX="${SUBJECT}: $assignment"
	...
	chmod +x "${ta}"/mailto.sh
    fi
    if [ "${email[$ta]}" ]; then
	echo Mailing "$ta"
	pkt="$ta-${zip%.zip}.7z"
	7za a -ms=on -mx=9 "$pkt" "$ta" > /dev/null
	#echo "$humor" | mailx -n -s "${SUBJECT} ${zip%.zip}" -a "$pkt" "${email[$ta]}" 
	echo "$humor" | mutt -s "${SUBJECT}: ${zip%.zip}" -a "$pkt" -- "${email[$ta]}" 
	rm -f "$pkt"
    fi
done
