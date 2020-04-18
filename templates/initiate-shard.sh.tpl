#!/bin/bash

###	initiate replicaset

echo "Adding shard to cluster"

count=0

while true; do
	ok=`mongo --port ${port}--quiet --eval 'rs.initiate(${rs_config})' | grep '"ok" : 1' | wc -l`
	[ $ok -eq 1 ] && break
	[ $count -eq 60 ] && exit 1
	echo "attempt $count failed to initiate replicaset...retrying"
	count=$((count+1))
	sleep 1
done

echo "Completed adding shard to cluster"