#!/bin/bash

###	initiate replicaset

echo "Initiating replica set"

count=0

while true; do
	res=`mongo --port ${port} --quiet --eval 'rs.initiate(${rs_config})'`
	ok=`echo $res | grep '"ok" : 1' | wc -l`
	[ $ok -eq 1 ] && break
    if [ $count -eq 60 ]; then
      echo "ERROR: failed to initiate replica set: $res"
      exit 1
    fi
	count=$((count+1))
	sleep 1
done

echo "Replica set initialized"