#!/bin/bash


echo "Configuring mongos.conf"

cat > /etc/mongos.conf << EOF
${mongos_conf}
EOF

cat > /usr/lib/systemd/system/mongos.service << EOF
${mongos_service}
EOF

wait_for_dns

# Start MongoDB and enable on startup
echo "Starting mongos service"
if systemctl >/dev/null 2>&1; then
	systemctl daemon-reload
	systemctl enable mongos
	systemctl start mongos
else
	if chkconfig >/dev/null 2>&1; then
		chkconfig --add mongos	# do we need to add to chkconfig?
		chkconfig mongos on
	else
		update-rc.d mongos enable
	fi
	service mongos start
fi

echo "Complete"