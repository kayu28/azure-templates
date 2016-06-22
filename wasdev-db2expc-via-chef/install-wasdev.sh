#!/bin/bash
set -eu

log()
{
    echo "====================================================="
    echo "`date`: $1"
    echo "====================================================="
}

bash chef-client.sh -g 2.8.2 -c 12.10.24 -d 0.14.25

logfile=/tmp/install-wasdev.log
exec > >(tee -ia ${logfile})
exec 2>&1

# parameters
if [[ $# -lt 7 ]] ; then
    echo 'invalid argument.'
    exit 1
fi

installer_url=$1
ibmuser=$2
ibmpassword=$3
db2driver_url=$4
db_hostname=$5
ap_hostname=$6
database_name=$7
chefrepo=/var/chef/chef-repo

# set hostname
if [ $ap_hostname != "" ]; then
    hostnamectl set-hostname $ap_hostname
    hostname
fi

cat > ${chefrepo}/Berksfile << EOF
source "https://api.berkshelf.com"
cookbook "was", github: "kayu28/chef-wasdev"
EOF

log "Download cookbook"
cd ${chefrepo}
env HOME=/var/chef berks vendor cookbooks

log "Add run list"
env HOME=/var/chef knife node run_list add -z `knife node list -z` recipe[was::default]

cat > ${chefrepo}/cookbooks/was/attributes/normal.rb << EOF
normal['was']['installer_url']             = "$installer_url"
normal['was']['ibmuser']                   = "$ibmuser"
normal['was']['ibmpassword']               = "$ibmpassword"
normal['was']['profile']['hostName']       = "$ap_hostname"
normal['was']['provider']['db2driver_url'] = "$db2driver_url"
normal['was']['datasource']['hostname']    = "$db_hostname"
normal['was']['datasource']['database']    = "$database_name"
EOF

log "Run chef client"
env HOME=/var/chef chef-client -z -c ${chefrepo}/.chef/client.rb

rm -f ${chefrepo}/cookbooks/was/attributes/normal.rb

# firewall setting
if [ -e /usr/lib/firewalld ]; then
    cat > /usr/lib/firewalld/services/wasdev.xml << EOF
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>wasdev</short>
  <port protocol="tcp" port="9080"/>
  <port protocol="tcp" port="9043"/>
  <port protocol="tcp" port="8880"/>
</service>
EOF
    chmod 640 /usr/lib/firewalld/services/wasdev.xml
    systemctl restart firewalld
    firewall-cmd --add-service=wasdev --zone=public --permanent
    firewall-cmd --reload
    firewall-cmd --list-services --zone=public --permanent
fi

exit 0
