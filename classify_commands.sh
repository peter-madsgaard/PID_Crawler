#!/bin/bash

# ==== Config ====
INPUT_FILE=$aggregate_chain_outfile
OUTPUT_FILE=$classify_outfile
PYTHON_SCRIPT=$command_python_script

# ==== Check files ====
if [ ! -f "$INPUT_FILE" ]; then
    echo "ERROR: Input file not found: $INPUT_FILE" >&2
    exit 1
fi
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "ERROR: classify_command.py not found at $PYTHON_SCRIPT" >&2
    exit 1
fi

# ==== Process ====
echo "==> Reading from $INPUT_FILE"
echo "==> Writing to $OUTPUT_FILE"

# Write header + new column
head -n 1 "$INPUT_FILE" | awk -F, '{print $0",predicted_class"}' > "$OUTPUT_FILE"

# Process each row (skip header)
tail -n +2 "$INPUT_FILE" | while IFS= read -r line; do
    # Extract last column (COMMANDS), preserving commas inside
    cmd=$(echo "$line" | awk -F, '{print $NF}')
    
    # Call Python classifier
    predicted=$(python3 "$PYTHON_SCRIPT" "$cmd")
    
    # Append row with prediction
    echo "$line,$predicted" >> "$OUTPUT_FILE"
done

echo "✅ Done. Predictions written to $OUTPUT_FILE"
