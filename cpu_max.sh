#!/bin/bash

max_freq="3.2"

for i in `seq 0 11`;
do
	cpufreq-set -g userspace -c $i
done

for i in `seq 0 11`;
do
	cpufreq-set -f ${max_freq}Ghz -c $i
done

