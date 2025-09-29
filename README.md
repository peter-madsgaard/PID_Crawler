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
