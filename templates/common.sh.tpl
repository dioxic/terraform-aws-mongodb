#!/bin/bash

wait_for_dns() {
	local count=0
	local hostname=$(hostname)
	local ip=$(hostname -I)

	while true; do
		local resolved=`nslookup -type=a $hostname | grep $ip | wc -l`
		[ $resolved -eq 1 ] && break
		if [ $count -eq 60 ]; then
			echo "ERROR: Could not resolve DNS entry for $hostname to local ip ($ip)"
			exit 1
		fi
		count=$((count+1))
		sleep 5
	done
  
}