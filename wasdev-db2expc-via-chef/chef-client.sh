#!/bin/bash
set -eu

BOLD=$(tput bold)
NORM=$(tput sgr0)

log()
{
    echo "====================================================="
    echo "`date`: $1"
    echo "====================================================="
}

usage()
{
    echo "This script installs Chef-client and ChefDK on your virtual machine."
    echo "Usage: "
    echo "Parameters:"
    echo "-g git version"
    echo "-c chef-client version"
    echo "-d chefdk version"
    echo "-n chef node name"
    echo "-l log file"
    echo "-h help"
}

# Default Parameters
GIT_VERSION="2.8.2"
CHEFDK_VERSION="0.14.25"
NODE_NAME="node01"
LOG_FILE=/tmp/install-chef-client.log

# Loop through options passed
while getopts :g:c:d:n:l:h optname; do
  echo "Option $optname set"
  case $optname in
    g)
      GIT_VERSION=${OPTARG}
      ;;
    c)
      CHEF_VERSION=${OPTARG}
      ;;
    d)
      CHEFDK_VERSION=${OPTARG}
      ;;
    n)
      NODE_NAME=${OPTARG}
      ;;
    l)
      LOG_FILE=${OPTARG}
      ;;
    h)
      usage
      exit 2
      ;;
    \?)
      echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
      usage
      exit 1
      ;;
    :)
      echo -e \\n"Option -${BOLD}$OPTARG${NORM} requires an argument."
      usage
      exit 1
      ;;
  esac
done

exec > >(tee -ia ${LOG_FILE})
exec 2>&1

# system update
yum -y update --exclude=WALinuxAgent

# set local time
mv /etc/localtime /etc/localtime.bak
ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

# install git
log "Install Git"
yum -y install curl-devel expat-devel gettext-devel openssl-devel zlib-devel perl-ExtUtils-MakeMaker wget gcc
wget -P /usr/local/src https://www.kernel.org/pub/software/scm/git/git-$GIT_VERSION.tar.gz
tar zfx /usr/local/src/git-$GIT_VERSION.tar.gz -C /usr/local/src
make -s -C /usr/local/src/git-$GIT_VERSION prefix=/usr/local all
make -s -C /usr/local/src/git-$GIT_VERSION prefix=/usr/local install
rm -f /usr/local/src/git-$GIT_VERSION.tar.gz
git --version

# install chef
log "Install Chef"
if [[ -v CHEF_VERSION ]] ; then
    curl -L https://omnitruck.chef.io/install.sh | bash -s -- -v ${CHEF_VERSION}
else
    curl -L https://omnitruck.chef.io/install.sh | bash
fi
chef-client -v

# create chef-repo
log "Create chef repository"
mkdir -p /var/chef
wget -O - 'http://github.com/opscode/chef-repo/tarball/master' | tar zxvf - -C /var/chef
mv /var/chef/chef-chef-repo* /var/chef/chef-repo

mkdir -p /var/chef/chef-repo/.chef

cat > /var/chef/chef-repo/.chef/client.rb << EOF
log_level     :info
log_location  STDOUT
chef_server_url "https://127.0.0.1:8889"
cookbook_path [ '/var/chef/chef-repo/cookbooks' ]
node_path     [ '/var/chef/chef-repo/nodes' ]
local_mode    'true'
node_name     '${NODE_NAME}'
file_cache_path "/var/chef/cache"
EOF

cat > /var/chef/chef-repo/.chef/knife.rb << EOF
log_level     :info
log_location  STDOUT
cookbook_path [ '/var/chef/chef-repo/cookbooks' ]
node_path     [ '/var/chef/chef-repo/nodes' ]
chef_server_url 'http://127.0.0.1:8889'
local_mode    'true'
EOF

chmod +rx /var/chef

# install chefdk
log "Install ChefDK"
yum -y install https://packages.chef.io/stable/el/7/chefdk-$CHEFDK_VERSION-1.el7.x86_64.rpm

log "Create node list"
cd /var/chef/chef-repo
env HOME=/var/chef chef-client -z -c /var/chef/chef-repo/.chef/client.rb

exit 0
