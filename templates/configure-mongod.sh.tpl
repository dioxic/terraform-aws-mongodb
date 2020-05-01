#!/bin/bash

# -------------------------------------------------------------------------------------------------------------------------------------
#                                                    Prerequisites
# -------------------------------------------------------------------------------------------------------------------------------------

mount_data_directory() {
	echo "Mounting data directory"

	mkfs -t xfs ${data_block_device}
	mkdir ${mount_point}
	echo "UUID=`blkid ${data_block_device} -sUUID -ovalue`  ${mount_point}  xfs  defaults,noatime  0  2" >> /etc/fstab
	mount -av
}

set_readahead() {
	echo "Setting readahead"

	cat > /etc/systemd/system/readahead.service << EOF
[Unit]
Description=Set readahead for MongoDB block device

[Service]
Type=simple
ExecStart=/bin/sh -c "blockdev --setra 8  ${data_block_device}"

[Install]
WantedBy=multi-user.target
EOF

	sudo systemctl daemon-reload
	sudo systemctl start readahead
	sudo systemctl enable readahead
}


# -------------------------------------------------------------------------------------------------------------------------------------
#                                                    ReplicaSet Configuration
# -------------------------------------------------------------------------------------------------------------------------------------

initiate_replica_set() {
	echo "Initializing replica set"
	
	%{ for node in rs_hosts ~}
	wait_for_node ${node}
	%{ endfor ~}

	# try to initiate the replica set
	local res=`mongo --port ${mongod_port} --quiet --eval 'JSON.stringify(rs.initiate(${rs_config}))' | tail -n 1`
	local ok=`echo $res | jq '.ok // 0'`
	
	if [ $ok -eq 0 ]; then
		code=`echo $res | jq '.code // -1'`

		# if the replicaset is already initiated, try reconfiguring
		if [ $code -eq 23 ]; then
			echo "Replica set is already initialized!"
			reconfigure_replica_set
		else
			msg=`echo $res | jq '{ ok: .ok, code: .code, errmsg: .errmsg}'`
			echo "ERROR: failed to initiate replica set: $msg"
			exit 1
		fi
	fi
}

reconfigure_replica_set() {
	echo "Reconfiguring replica set"

	# tail -n1 is a hack to workaround SERVER-27159 and just get the latest line
	local res=`mongo "${rs_uri}" --quiet --eval 'JSON.stringify(rs.reconfig(${rs_config}))' | tail -n 1`
	local ok=`echo $res | jq '.ok // 0'`
	if [ $ok -eq 0 ]; then
		msg=`echo $res | jq '{ ok: .ok, code: .code, errmsg: .errmsg}'`
		echo "ERROR: failed to initiate replica set: $msg"
		exit 1
	fi
}

# -------------------------------------------------------------------------------------------------------------------------------------
#                                                    Sharding Configuration
# -------------------------------------------------------------------------------------------------------------------------------------

add_shard() {
	echo "Adding shard to cluster"

	count=0

	while true; do
		res=`mongo "${router_uri}" --quiet --eval 'db.getSiblingDB("admin").runCommand( { addShard: "${rs_name}/${rs_hosts_csv}", name: "${shard_name}" })'`

		ok=`echo $res | grep '"ok" : 1' | wc -l`
		[ $ok -eq 1 ] && break
		if [ $count -eq 60 ]; then
		echo "ERROR: failed to add shard to cluster: $res"
		exit 1
		fi
		count=$((count+1))
		sleep 1
	done
}


# -------------------------------------------------------------------------------------------------------------------------------------
#                                                             mongod
# -------------------------------------------------------------------------------------------------------------------------------------

configure_os_settings() {
	mount_data_directory
	set_ulimits
	set_sysctl_variables
	disable_thp
	set_readahead
}

configure_mongod() {
	echo "Configuring mongod.conf"

	cat > /etc/mongod.conf << 'EOF'
${mongod_conf}
EOF

	echo "Creating data directory"

	mkdir -p ${db_path}
	chown mongod: -R ${db_path}
}

start_mongod() {
	wait_for_local_dns

	# Start MongoDB and enable on startup
	echo "Starting mongod service"
	if systemctl >/dev/null 2>&1; then
		systemctl daemon-reload
		systemctl enable mongod
		systemctl start mongod
	else
		if chkconfig >/dev/null 2>&1; then
			chkconfig --add mongod	# do we need to add to chkconfig?
			chkconfig mongod on
		else
			update-rc.d mongod enable
		fi
		service mongod start
	fi
}


# -------------------------------------------------------------------------------------------------------------------------------------
#                                                             Run
# -------------------------------------------------------------------------------------------------------------------------------------

configure_os_settings
configure_mongod
start_mongod