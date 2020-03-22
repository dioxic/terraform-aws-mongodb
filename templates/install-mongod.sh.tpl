#!/bin/bash

###  Get mongodb package
if [[ ${mongodb_community} == true ]]; then
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
  sudo yum -y check-update
	sudo yum -y update

  echo "Installing MongoDB packages"
  sudo yum install -y $mongodb_package
elif [[ ! -z $APT_GET ]]; then
  echo "Debian/Ubuntu system detected"
  echo "Performing updates and installing prerequisites"
  sudo apt-get -y update

	echo "Installing MongoDB packages"
	sudo apt-get -y $mongodb_package
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

# Start MongoDB and enable on startup
echo "Starting MongoDB service"
if systemctl >/dev/null 2>&1; then
	systemctl daemon-reload
	systemctl enable mongod
	systemctl start mongod
else
	if chkconfig >/dev/null 2>&1; then
		chkconfig --add mongod  # do we need to add to chkconfig?
		chkconfig mongod on
	else
		update-rc.d mongod enable
	fi
	service mongod start
fi