#!/bin/bash

echo "Adding shard to cluster"

count=0

while true; do
	res=`mongo --port ${mongos_port} --quiet --eval 'db.getSiblingDB("admin").runCommand( { addShard: "${shardReplSetName}/${shardHosts}", name: "${shardName}" })'`

	ok=`echo $res | grep '"ok" : 1' | wc -l`
	[ $ok -eq 1 ] && break
    if [ $count -eq 60 ]; then
      echo "ERROR: failed to add shard to cluster: $res"
      exit 1
    fi
	count=$((count+1))
	sleep 1
done

echo "Completed adding shard to cluster"