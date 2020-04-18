#!/bin/bash

echo "Configuring mongod.conf"

cat > /etc/mongod.conf << EOF
${mongod_conf}
EOF

wait_for_dns

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

echo "Complete"