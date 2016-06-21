#!/bin/bash
set -eu

log()
{
    echo "====================================================="
    echo "$1"
    echo "====================================================="
}

bash chef-client.sh "2.8.2" "0.14.25"

logfile=/tmp/install-db2expc.log
exec > >(tee -ia ${logfile})
exec 2>&1

# parameters
if [[ $# -lt 2 ]] ; then
    echo 'invalid argument.'
    exit 1
fi

installer_url=$1
database_name=$2
chefrepo=/var/chef/chef-repo

cat > ${chefrepo}/Berksfile << EOF
source "https://api.berkshelf.com"
cookbook "db2", github: "kayu28/chef-db2expc"
EOF

log "Download cookbook"
cd ${chefrepo}
env HOME=/var/chef berks vendor cookbooks

log "Add run list"
env HOME=/var/chef knife node run_list add -z `knife node list -z` recipe[db2::default]

cat > ${chefrepo}/cookbooks/db2/attributes/normal.rb << EOF
normal['db2']['installer_url']    = "$installer_url"
normal['db2']['sample_database']  = "false"
normal['db2']['database']['name'] = "$database_name"
EOF

log "Run chef client"
env HOME=/var/chef chef-client -z -c ${chefrepo}/.chef/client.rb

# firewall setting
if [ -e /usr/lib/firewalld ]; then
    cat > /usr/lib/firewalld/services/db2expc.xml << EOF
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>db2expc</short>
  <port protocol="tcp" port="50000"/>
</service>
EOF
    systemctl restart firewalld
    firewall-cmd --add-service=db2expc
fi

exit 0
