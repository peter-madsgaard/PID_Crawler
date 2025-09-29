#!/usr/bin/env python3
import sys, joblib

model = joblib.load("/Users/peter/Documents/PID_Crawler/models/command_classifier_exp_337.pkl")

if len(sys.argv) > 1:
    cmd = " ".join(sys.argv[1:])
else:
    cmd = sys.stdin.read().strip()

category = model.predict([cmd])[0]
print(category)
