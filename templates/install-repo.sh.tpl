#!/bin/bash

### Configuration

mongodb_version=${mongodb_version}

# determine url based on os and arch
arch=`uname -m`
OS=`uname`
os=`echo $OS | tr '[:upper:]' '[:lower:]'`

if [[ $os != linux* ]]; then
	echo "$OS not supported by setup script"
	exit 0
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

### Install MongoDB
echo "Installing package repository $mongodb_package for $distro_id-$distro_version"
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
		exit
		;;
esac