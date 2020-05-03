#!/bin/bash

# -------------------------------------------------------------------------------------------------------------------------------------
#                                                                     Helpers
# -------------------------------------------------------------------------------------------------------------------------------------

wait_for_local_dns() {
	echo "Waiting for local DNS..."
	
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

wait_for_node() {
	local count=0
	echo "Waiting for node $1"
	while true; do
		mongo $1 --eval 'rs.isMaster()' >/dev/null
		if [ $? -eq 0 ]; then
			break
		fi
		if [ $count -eq 60 ]; then
			echo "ERROR: Could not connect to MongoDB at $1"
			exit 1
		fi
		count=$((count+1))
		sleep 5
	done
}


# -------------------------------------------------------------------------------------------------------------------------------------
#                                                       OS Configuration
# -------------------------------------------------------------------------------------------------------------------------------------

set_hostname() {
	echo "Setting hostname"

	echo "`hostname -i`       ${hostname}" >> /etc/hosts

	hostnamectl set-hostname ${hostname}

	if test -f /etc/cloud/cloud.cfg; then
		sed -i 's/^preserve_hostname:.*/preserve_hostname: true/' /etc/cloud/cloud.cfg
	fi
}

set_ulimits() {
	echo "Setting ulimits..."

	cat > /etc/security/limits.d/99-mongodb-nproc.conf << 'EOF'
mongod        -   nproc    64000
mongod        -   nofile   64000
mongod        -   fsize    unlimited
mongod        -   cpu      unlimited
mongod        -   as       unlimited
mongod        -   memlock  unlimited
EOF
}

disable_thp() {
	echo "Disabling THP"

	cat > /etc/systemd/system/disable-thp.service << 'EOF'
[Unit]
Description=Disable Transparent Huge Pages (THP)

[Service]
Type=simple
ExecStart=/bin/sh -c "echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled && echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag"

[Install]
WantedBy=multi-user.target
EOF

	sudo systemctl daemon-reload
	sudo systemctl start disable-thp
	sudo systemctl enable disable-thp
}

set_sysctl_variables(){
	echo "Modifying sysctl variables"

	cat > /etc/sysctl.d/90-mongod.conf << 'EOF'
vm.swappiness=1
vm.zone_reclaim_mode=0
EOF

	sysctl -p /etc/sysctl.d/90-mongod.conf
}


# -------------------------------------------------------------------------------------------------------------------------------------
#                                                       Packages
# -------------------------------------------------------------------------------------------------------------------------------------

install_repo() {
	echo "Installing MongoDB repository setup"

	mongodb_version=${mongodb_version}

	# determine url based on os and arch
	arch=`uname -m`
	OS=`uname`
	os=`echo $OS | tr '[:upper:]' '[:lower:]'`

	if [[ $os != linux* ]]; then
		echo "$OS not supported by setup script"
		exit 1
	fi

	###  Get distribution info

	if lsb_release >/dev/null 2>&1; then
		# If the lsb_release(1) tool is installed, use it.
		distro_id=`lsb_release -si`
		distro_version=`lsb_release -sr`
		distro_codename=`lsb_release -sc`
	elif test -f /etc/os-release; then
		# Suse, opensuse, amazon linux, centos (but not redhat), ubuntu
		distro_id=$(sed -ne 's/^ID=//p' /etc/os-release | sed -e 's/^["'"'"']//' -e 's/["'"'"']$//' -e 's/\\\(.\)/\1/g')
		distro_version=$(sed -ne 's/^VERSION_ID=//p' /etc/os-release | sed -e 's/^["'"'"']//' -e 's/["'"'"']$//' -e 's/\\\(.\)/\1/g' -e 's/\..*//')
		distro_codename=$(sed -ne 's/^VERSION_CODENAME=//p' /etc/os-release | sed -e 's/^["'"'"']//' -e 's/["'"'"']$//' -e 's/\\\(.\)/\1/g')
	elif test -f /etc/lsb-release; then
		# In the case where the distro provides an /etc/lsb-release file, but the lsb_release(1) util isn't installed.
		distro_id=$(sed -ne 's/^DISTRIB_ID=//p' /etc/lsb-release | sed -e 's/^["'"'"']//' -e 's/["'"'"']$//' -e 's/\\\(.\)/\1/g' -e 's/\..*//')
		distro_version=$(sed -ne 's/^DISTRIB_RELEASE=//p' /etc/lsb-release | sed -e 's/^["'"'"']//' -e 's/["'"'"']$//' -e 's/\\\(.\)/\1/g')
	elif test -f /etc/debian_version; then
		# Debian generally doesn't install lsb_release(1) or a /etc/lsb-release file, so we figure it out manually.
		distro_codename=$(sed 's/\/.*//' /etc/debian_version)
		distro_id=debian
	fi

	distro_id=`echo "$distro_id" | tr '[:upper:]' '[:lower:]'`
	distro_version=`echo "$distro_version" | tr '[:upper:]' '[:lower:]'`
	distro_codename=`echo "$distro_codename" | tr '[:upper:]' '[:lower:]'`
	distro_major_version=`echo "$distro_version" | sed 's/\..*//'`

	###  Get distribution info
	if ${mongodb_community}; then
		mongodb_repo="repo.mongodb.org"
		mongodb_package="mongodb-org"
	else
		mongodb_repo="repo.mongodb.com"
		mongodb_package="mongodb-enterprise"
	fi

	### Install MongoDB Repo
	echo "Installing repository $mongodb_package for $distro_id-$distro_version"
	case "$distro_id" in
		sles|opensuse)
			rpm --import https://www.mongodb.org/static/pgp/server-4.2.asc
			zypper addrepo --gpgcheck "https://$mongodb_repo/zypper/suse/$distro_major_version/$mongodb_package/$mongodb_version/x86_64/" mongodb
			zypper -n install $mongodb_package
			;;
		fedora|centos|redhatenterpriseserver|rhel)
			cat > /etc/yum.repos.d/$mongodb_package-$mongodb_version.repo <<- EOF
				[$mongodb_package-$mongodb_version]
				name=MongoDB Repository
				baseurl=https://$mongodb_repo/yum/redhat/\$releasever/$mongodb_package/$mongodb_version/x86_64/
				gpgcheck=1
				enabled=1
				gpgkey=https://www.mongodb.org/static/pgp/server-$mongodb_version.asc
			EOF
			;;
		ubuntu)
			apt-get install gnupg -y
			wget -qO - https://www.mongodb.org/static/pgp/server-$mongodb_version.asc | apt-key add -
			echo "deb [ arch=amd64,arm64 ] https://$mongodb_repo/apt/ubuntu $distro_codename/$mongodb_package/$mongodb_version multiverse" \
			> /etc/apt/sources.list.d/$mongodb_package-$mongodb_version.list
			;;
		debian)
			apt-get install gnupg -y
			wget -qO - https://www.mongodb.org/static/pgp/server-$mongodb_version.asc | apt-key add -
			echo "deb http://$mongodb_repo/apt/debian $distro_codename/$mongodb_package/$mongodb_version main" \
			> /etc/apt/sources.list.d/$mongodb_package-$mongodb_version.list
			;;
		amzn)
			if [[ $distro_version != 2 ]]; then
				distro_version="2013.03"
			fi
			cat > /etc/yum.repos.d/$mongodb_package-$mongodb_version.repo <<- EOF
				[$mongodb_package-$mongodb_version]
				name=MongoDB Repository
				baseurl=https://$mongodb_repo/yum/amazon/$distro_version/$mongodb_package/$mongodb_version/x86_64/
				gpgcheck=1
				enabled=1
				gpgkey=https://www.mongodb.org/static/pgp/server-$mongodb_version.asc
			EOF
			;;
		* )
			echo "No repo configured for $distro_id-$distro_version"
			exit 1
			;;
	esac	
}

install_packages() {
	echo "Installing packages"

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
		sudo yum -y -q install jq

		echo "Installing MongoDB packages"
		sudo yum install -y -q $mongodb_package
	elif [[ ! -z $APT_GET ]]; then
		echo "Debian/Ubuntu system detected"
		echo "Performing updates and installing prerequisites"
		sudo apt-get -qq update
		sudo apt-get -qq install jq

		echo "Installing MongoDB packages"
		sudo apt-get -qq $mongodb_package
	elif [[ ! -z $ZYPPER ]]; then
		echo "SUSE system detected"
		echo "Performing updates and installing prerequisites"
		sudo zypper -n update
		sudo zypper -n install jq

		echo "Installing MongoDB packages"
		sudo zypper -n install $mongodb_package
	else
		echo "Prerequisites not installed due to OS detection failure"
		exit 1;
	fi
}