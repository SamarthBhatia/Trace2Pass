#!/bin/bash
# Test insertCellFast with instrumentation-aware diagnoser

cd /Users/samarthbhatia/Developer/Systems/Trace2Pass/diagnoser

python3 diagnose.py full-pipeline \
  ../evaluation/testcases/production-sqlite-insertcell.c \
  'test_dummy_placeholder_{binary}' \
  --use-instrumentation \
  --optimization-level=-O2
