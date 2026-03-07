#!/bin/bash
# Continue most recent Aside conversation if it's less than 10 minutes old,
# otherwise start a new one.

latest=$(aside ls -n 1 2>/dev/null)
if [ -z "$latest" ]; then
    aside query --mic
    exit 0
fi

id=$(echo "$latest" | awk '{print $1}')
age=$(echo "$latest" | awk '{print $2}')

# Parse age string (e.g. "4m", "1h", "30s") into minutes
minutes=999
if [[ "$age" =~ ^([0-9]+)s$ ]]; then
    minutes=0
elif [[ "$age" =~ ^([0-9]+)m$ ]]; then
    minutes=${BASH_REMATCH[1]}
elif [[ "$age" =~ ^([0-9]+)h$ ]]; then
    minutes=$(( ${BASH_REMATCH[1]} * 60 ))
fi

if [ "$minutes" -lt 10 ]; then
    aside reply "$id" --mic
else
    aside query --mic
fi
