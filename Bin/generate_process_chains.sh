#!/bin/bash

outfile=$base_chain_outfile

# Temporary files
meta_tmp=$(mktemp)
map_tmp=$(mktemp)
cmd_tmp=$(mktemp)
child_map_tmp=$(mktemp)
top_cache=$(mktemp)
bottom_max_cache=$(mktemp)

# Verify ps works
if ! ps -eo pid= >/dev/null 2>&1; then
    echo "ERROR: 'ps' command not available or failed" >&2
    exit 1
fi

# 1. Collect process metadata into real CSV (no quotes around lstart)
ps -eo pid=,ppid=,user=,tty=,%mem=,%cpu=,lstart= \
| awk 'BEGIN {OFS=","} {
    start=$7" "$8" "$9" "$10" "$11;
    print $1,$2,$3,$4,$5,$6,start
}' > "$meta_tmp"

if [ ! -s "$meta_tmp" ]; then
    echo "ERROR: no process metadata collected from ps" >&2
    exit 1
fi

# 2. PID->PPID map
awk -F, '{print $1 "," $2}' "$meta_tmp" > "$map_tmp"

# 3. PPID->PID map (children)
awk -F, '{print $2 "," $1}' "$map_tmp" > "$child_map_tmp"

# 4. PID + COMMAND
ps -eo pid=,command= > "$cmd_tmp"

# Header
echo "PID,PPID,USER,TTY,REALUSER,%MEM,%CPU,START,BOTTOM_PID_MAX,TOP_PID,CHAIN_START_PID,CHAIN_START_DATETIME,CHAIN_START_USER,COMMAND" > "$outfile"

# Resolve top-most ancestor (with cache)
resolve_top() {
    local pid=$1
    if [ -z "$pid" ]; then
        echo "?"
        echo "WARN: resolve_top called with empty PID" >&2
        return
    fi
    local cached=$(awk -F, -v p="$pid" '$1==p {print $2; exit}' "$top_cache")
    if [ -n "$cached" ]; then
        echo "$cached"
        return
    fi
    local original=$pid
    while true; do
        local ppid=$(awk -F, -v p="$pid" '$1==p {print $2; exit}' "$map_tmp")
        if [ -z "$ppid" ] || [ "$ppid" -eq 0 ] || [ "$ppid" = "$pid" ]; then
            echo "$pid"
            echo "$original,$pid" >> "$top_cache"
            return
        fi
        pid=$ppid
    done
}

# Bottom-most via max PID in subtree (traverse all children, cached)
resolve_bottom_max() {
    local pid=$1
    if [ -z "$pid" ]; then
        echo "?"
        echo "WARN: resolve_bottom_max called with empty PID" >&2
        return
    fi
    local cached=$(awk -F, -v p="$pid" '$1==p {print $2; exit}' "$bottom_max_cache")
    if [ -n "$cached" ]; then
        echo "$cached"
        return
    fi
    local max_pid=$pid
    local children=$(awk -F, -v p="$pid" '$1==p {print $2}' "$child_map_tmp")
    for child in $children; do
        local sub_max=$(resolve_bottom_max "$child")
        [ "$sub_max" -gt "$max_pid" ] && max_pid=$sub_max
    done
    echo "$pid,$max_pid" >> "$bottom_max_cache"
    echo "$max_pid"
}

# Find first non-root user/realuser PID in the chain
resolve_chain_start() {
    local pid=$1
    while [ "$pid" != "0" ] && [ -n "$pid" ]; do
        line=$(awk -F, -v p="$pid" '$1==p {print $0; exit}' "$meta_tmp")
        if [ -z "$line" ]; then
            echo "?,?,?"
            echo "WARN: missing metadata for PID=$pid" >&2
            return
        fi

        usr=$(echo "$line" | cut -d, -f3)
        tty=$(echo "$line" | cut -d, -f4)
        start=$(echo "$line" | cut -d, -f7-)

        # Resolve REALUSER
        case "$tty" in
            pts/*|ttys*|tty*) dev="$tty" ;;
            *) dev="" ;;
        esac
        if [ -n "$dev" ]; then
            if stat -f %Su /dev/$dev >/dev/null 2>&1; then
                realuser=$(stat -f %Su /dev/$dev)
            else
                realuser=$(stat -c %U /dev/$dev 2>/dev/null)
            fi
        else
            realuser="?"
        fi

        # Skip root / ? and pick chain starter
        if { [ "$realuser" != "?" ] && [ "$realuser" != "root" ]; } || \
           { [ "$usr" != "?" ] && [ "$usr" != "root" ]; }; then

            # Format datetime
            if date -j -f "%a %b %d %T %Y" "$start" "+%Y-%m-%d %H:%M:%S" >/dev/null 2>&1; then
                formatted=$(date -j -f "%a %b %d %T %Y" "$start" "+%Y-%m-%d %H:%M:%S")
            else
                formatted=$(date -d "$start" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
            fi
            if [ -z "$formatted" ]; then
                echo "?,?,?"
                echo "WARN: could not parse chain start date for PID=$pid raw='$start'" >&2
                return
            fi

            # Pick chain_start_user (prefer realuser)
            if [ "$realuser" != "?" ] && [ "$realuser" != "root" ]; then
                chosen_user=$realuser
            elif [ "$usr" != "?" ] && [ "$usr" != "root" ]; then
                chosen_user=$usr
            else
                chosen_user="?"
            fi

            echo "$pid,$formatted,$chosen_user"
            return
        fi

        # Step up to parent
        pid=$(awk -F, -v p="$pid" '$1==p {print $2; exit}' "$map_tmp")
    done
    echo "?,?,?"
}

# Iterate through metadata
while IFS=, read -r pid ppid user tty mem cpu start_rest; do
    start="$start_rest"

    # Format start time
    if date -j -f "%a %b %d %T %Y" "$start" "+%Y-%m-%d %H:%M:%S" >/dev/null 2>&1; then
        start_fmt=$(date -j -f "%a %b %d %T %Y" "$start" "+%Y-%m-%d %H:%M:%S")
    else
        start_fmt=$(date -d "$start" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
    fi
    if [ -z "$start_fmt" ]; then
        echo "WARN: could not parse start datetime for PID=$pid raw='$start'" >&2
        start_fmt="?"
    fi

    # Resolve REALUSER via tty
    case "$tty" in
        pts/*|ttys*|tty*) dev="$tty" ;;
        *) dev="" ;;
    esac
    if [ -n "$dev" ]; then
        if stat -f %Su /dev/$dev >/dev/null 2>&1; then
            realuser=$(stat -f %Su /dev/$dev)
        else
            realuser=$(stat -c %U /dev/$dev 2>/dev/null)
        fi
    else
        realuser="?"
    fi

    # Resolve ancestry & chain info
    top_pid=$(resolve_top "$pid")
    bottom_pid_max=$(resolve_bottom_max "$pid")
    chain_info=$(resolve_chain_start "$pid")
    chain_start_pid=$(echo "$chain_info" | cut -d, -f1)
    chain_start_datetime=$(echo "$chain_info" | cut -d, -f2)
    chain_start_user=$(echo "$chain_info" | cut -d, -f3)

    # Lookup command
    command=$(awk -v p="$pid" '$1==p { $1=""; sub(/^ /,""); print; exit }' "$cmd_tmp")
    if [ -z "$command" ]; then
        echo "WARN: no command found for PID=$pid" >&2
        command="?"
    fi
    command=$(printf '%s' "$command" | sed 's/"/""/g')

    # Output CSV row
    echo "$pid,$ppid,$user,$tty,$realuser,$mem,$cpu,$start_fmt,$bottom_pid_max,$top_pid,$chain_start_pid,$chain_start_datetime,$chain_start_user,\"$command\"" >> "$outfile"

done < "$meta_tmp"

# Cleanup
rm -f "$meta_tmp" "$map_tmp" "$cmd_tmp" "$child_map_tmp" "$top_cache" "$bottom_max_cache"
