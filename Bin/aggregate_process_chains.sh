#!/bin/bash

# Input/output directories
infile=$base_chain_outfile
outfile=$aggregate_chain_outfile

# Ensure directory exists
mkdir -p "$base_dir"

if [ ! -f "$infile" ]; then
    echo "ERROR: input file not found: $infile" >&2
    exit 1
fi

# Temp file
tmpfile=$(mktemp)

# Skip header and aggregate with awk
awk -F, '
NR > 1 {
    chain_start_pid=$11
    bottom_pid_max=$9
    key=chain_start_pid "|" bottom_pid_max

    # Cache fixed attributes
    chain_user[key]=$13
    chain_date[key]=$12

    # Totals
    total_cpu[key]+=$7
    total_mem[key]+=$6
    total_proc[key]++

    # Users (exclude root and ?)
    if ($3 != "?" && $3 != "root") {
        if (!(users[key] ~ "\\b" $3 "\\b")) {
            if (users[key] != "") users[key]=users[key]"|" $3
            else users[key]=$3
        }
    }

    # Realusers (exclude root and ?)
    if ($5 != "?" && $5 != "root") {
        if (!(realusers[key] ~ "\\b" $5 "\\b")) {
            if (realusers[key] != "") realusers[key]=realusers[key]"|" $5
            else realusers[key]=$5
        }
    }

    # Commands (unique)
    cmd=$14
    gsub(/^"|"$/, "", cmd)   # remove surrounding quotes
    if (cmd != "" && !(commands[key] ~ "\\Q" cmd "\\E")) {
        if (commands[key] != "") commands[key]=commands[key]"||"cmd
        else commands[key]=cmd
    }
}
END {
    OFS=","
    for (k in total_cpu) {
        split(k, parts, "|")
        cpid=parts[1]
        bpid=parts[2]
        print cpid, bpid, chain_user[k], chain_date[k], total_cpu[k], total_mem[k], total_proc[k], users[k], realusers[k], commands[k]
    }
}
' "$infile" \
| sort -t, -k6,6nr \
> "$tmpfile"

# Write header + sorted body
echo "CHAIN_START_PID,BOTTOM_PID_MAX,CHAIN_START_USER,CHAIN_START_DATETIME,TOTAL_CPU,TOTAL_MEM,TOTAL_PROCESSES,USERS,REALUSERS,COMMANDS" > "$outfile"
cat "$tmpfile" >> "$outfile"

rm -f "$tmpfile"

echo "Aggregation complete. Results written to $outfile (sorted by TOTAL_MEM descending, header included)"
