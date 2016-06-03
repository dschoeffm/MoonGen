#!/bin/bash

out=$1
script=$2
eth1=$3
eth2=$4

batch_size="128"

cpu_freqs=(1.2 1.4 1.6 1.8 2.0 2.2 2.4 3.2)
max_freq="3.2"

for i in `seq 0 11`;
do
	cpufreq-set -g userspace -c $i
done

for i in `seq 0 11`;
do
	cpufreq-set -f ${max_freq}Ghz -c $i
done

for c in "${cpu_freqs[@]}"
do
	echo "CPU frqeuency: $c"
	for i in `seq 0 11`;
	do
		cpufreq-set -f ${c}Ghz -c $i
	done

	build/MoonGen $script $eth1 $eth2 $batch_size |
		awk '/^\[counterSlave\] Received [0-9]*\.[0-9]*/ {print $3}' >> ${out}-tmp
done

cat ${out}-tmp | tr '\n' '  ' > ${out}

rm ${out}-tmp
