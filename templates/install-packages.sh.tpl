#!/bin/bash

echo "Starting package install"

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

echo "Completed package install"