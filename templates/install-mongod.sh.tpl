#!/bin/bash

###	Get mongodb package
if ${mongodb_community}; then
	mongodb_package="mongodb-org"
else
	mongodb_package="mongodb-enterprise"
fi

# Detect package management system.
YUM=$(which yum 2>/dev/null)
APT_GET=$(which apt-get 2>/dev/null)
ZYPPER=$(which zypper 2>/dev/null)

if [[ ! -z $YUM ]]; then
	echo "RHEL/CentOS system detected"
	echo "Performing updates and installing prerequisites"
	sudo yum -y -q check-update
	sudo yum -y -q update

	echo "Installing MongoDB packages"
	sudo yum install -y $mongodb_package
elif [[ ! -z $APT_GET ]]; then
	echo "Debian/Ubuntu system detected"
	echo "Performing updates and installing prerequisites"
	sudo apt-get -qq update

	echo "Installing MongoDB packages"
	sudo apt-get -qq $mongodb_package
elif [[ ! -z $ZYPPER ]]; then
	echo "SUSE system detected"
	echo "Performing updates and installing prerequisites"
	sudo zypper -n update

	echo "Installing MongoDB packages"
	sudo zypper -n install $mongodb_package
else
	echo "Prerequisites not installed due to OS detection failure"
	exit 1;
fi

echo "Install complete"

echo "Configuring mongod.conf"

cat > /etc/mongod.conf << EOF
${mongod_conf}
EOF

# Start MongoDB and enable on startup
echo "Starting MongoDB service"
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