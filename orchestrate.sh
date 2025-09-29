#!/bin/bash

export file_time_append=$(date +%Y%m%d_%H%M%S)
export file_time_append="20240611_153000"  # for testing

export base_dir='/Users/peter/Documents/PID_Crawler'

# generate_process_chains.sh
export base_chain_outfile="$base_dir/process_chains_$file_time_append.csv"

# aggregate_process_chains.sh
export aggregate_chain_outfile="$base_dir/aggregated_process_chains_$file_time_append.csv"

# classify_commands.sh
export classify_outfile="$base_dir/process_chains_with_predictions_$file_time_append.csv"
export command_python_script="$base_dir/Python/classify_command.py"

bash "$base_dir/Bin/generate_process_chains.sh" 
bash "$base_dir/Bin/aggregate_process_chains.sh"
bash "$base_dir/Bin/classify_commands.sh"
