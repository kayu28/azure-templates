#!/bin/bash
set -eu

log()
{
    echo "====================================================="
    echo "$1"
    echo "====================================================="
}

logfile=/tmp/install-chef-client.log
exec > >(tee -ia ${logfile})
exec 2>&1

# parameters
if [[ $# -lt 2 ]] ; then
    echo 'invalid argument.'
    exit 1
fi

git_version=$1
chefdk_version=$2

# system update
yum -y update --exclude=WALinuxAgent

# set local time
mv /etc/localtime /etc/localtime.bak
ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

# install git
log "Install Git"
yum -y install curl-devel expat-devel gettext-devel openssl-devel zlib-devel perl-ExtUtils-MakeMaker wget gcc
wget -P /usr/local/src https://www.kernel.org/pub/software/scm/git/git-$git_version.tar.gz
tar zfx /usr/local/src/git-$git_version.tar.gz -C /usr/local/src
make -s -C /usr/local/src/git-$git_version prefix=/usr/local all
make -s -C /usr/local/src/git-$git_version prefix=/usr/local install
rm -f /usr/local/src/git-$git_version.tar.gz
git --version

# install chef
log "Install Chef"
curl -L https://omnitruck.chef.io/install.sh | bash -s -- -v 12.10.24
chef-client -v

# create chef-repo
log "Create chef repository"
mkdir /var/chef
wget -O - 'http://github.com/opscode/chef-repo/tarball/master' | tar zxvf - -C /var/chef
mv /var/chef/chef-chef-repo* /var/chef/chef-repo

mkdir /var/chef/chef-repo/.chef

cat > /var/chef/chef-repo/.chef/client.rb << EOF
log_level     :info
log_location  STDOUT
chef_server_url "https://127.0.0.1:8889"
cookbook_path [ '/var/chef/chef-repo/cookbooks' ]
node_path     [ '/var/chef/chef-repo/nodes' ]
local_mode    'true'
node_name     'node01'
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
yum -y install https://packages.chef.io/stable/el/7/chefdk-$chefdk_version-1.el7.x86_64.rpm

log "Create node list"
cd /var/chef/chef-repo
env HOME=/var/chef chef-client -z -c /var/chef/chef-repo/.chef/client.rb

exit 0
