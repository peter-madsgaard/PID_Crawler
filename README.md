```MARKDOWN
# PURPOSE:
Generate report of resource usage for complex process trees in macOS and Linux that cross personal and non-personal IDs.

# MAIN PROCESS:
1. generate_process_chains.sh
- ps -eo pid=,ppid=,user=,tty=,%mem=,%cpu=,lstart
- generate graph of PID <-> PPID
- associate terminals with users for each PID
- generate bottom-most and top-most PIDs in each chain
- get earliest PID with non-root user in each chain
2. aggregate_process_chains.sh
- for each chain, get:
  - total CPU
  - total MEM
  - PID count
  - list of users
  - list of commands
3. classify_commands.sh
- for each command, trigger classify_command.py
- classiy_command.py sends command into model that predicts command category

# NOTEBOOKS
1. command_classifier.ipynb
- sends each command into llama3.1:latest and asks it to give a short string classification
- sends list of classifications back into llama3:1.latest and asks it to normalize into a simplified list
- sends each command back along with simplified list and asks it to select appropriate classification

2. model_training_with_looping.ipynb
- trains LogisticRegression text classifier on the command/classification pairs
- loops through range of class size thresholds, ngram ranges, and frequency values
- outputs model and model performance for each loop
- preferred model based on performance can be selected in classify_commands.sh
```


```TEXT
pseudo-DAG:

PID_Crawler/
├── Bin/
│   ├── orchestrate.sh
│   │
│   │--[calls]--> generate_process_chains.sh
│   │                |
│   │                |--[outputs]--> process_chains_<timestamp>.csv
│   │
│   │--[calls]--> aggregate_process_chains.sh
│   │                |
│   │                |--[inputs]--> process_chains_<timestamp>.csv
│   │                |--[outputs]--> aggregated_process_chains_<timestamp>.csv
│   │
│   │--[calls]--> classify_commands.sh
│   │                |
│   │                |--[inputs]--> aggregated_process_chains_<timestamp>.csv
│   │                |--[calls]--> Python/classify_command.py
│   │                |                |
│   │                |                |--[loads]--> models/command_classifier_exp_337.pkl
│   │                |                |--[predicts]--> command class for each command
│   │                |--[outputs]--> process_chains_with_predictions_<timestamp>.csv
│   │
│   ├── generate_process_chains.sh
│   ├── aggregate_process_chains.sh
│   └── classify_commands.sh
├── Python/
│   └── classify_command.py
├── models/
│   └── command_classifier_exp_337.pkl
├── Notebooks/
│   ├── command_classifier_v2.ipynb
│   │     |--[reads/writes]--> Data/command_classifications.txt
│   │     |--[trains/saves]--> models/command_classifier_exp_XXX.pkl
│   │
│   └── model_training_with_looping.ipynb
│         |--[reads/writes]--> Data/command_normalized_classifications.txt
│         |--[trains/saves]--> models/command_classifier_exp_XXX.pkl
├── Data/
│   ├── command_classifications.txt
│   ├── command_normalized_classifications.txt
│   └── experiment_results.csv
```
