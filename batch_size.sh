#!/bin/bash

out=$1
script=$2
eth1=$3
eth2=$4

sizes=(2 4 8 16 32 64 128 256 512)

for s in "${sizes[@]}"
do
	echo "build/MoonGen $script $eth1 $eth2 $s"
	build/MoonGen $script $eth1 $eth2 $s |
		awk '/^\[counterSlave\] Received [0-9]*\.[0-9]*/ {print $3}' >> ${out}-tmp
done

cat ${out}-tmp | tr '\n' '  ' > ${out}

rm ${out}-tmp
