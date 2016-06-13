#!/bin/bash
set -u

logfile=/tmp/extensions.log
jenkins_url=http://localhost:8080/

exec > >(tee -ia ${logfile})
exec 2>&1

log()
{
    echo "====================================================="
    echo "$1"
    echo "====================================================="
}


init()
{
    # See https://github.com/Azure/azure-linux-extensions/issues/154
    # See https://github.com/Azure/WALinuxAgent/issues/178
    yum -y update --exclude=WALinuxAgent
    yum -y install zip unzip wget vim
}


install_git()
{
    log "Installing Git"
    yum -y install curl-devel expat-devel gettext-devel openssl-devel zlib-devel perl-ExtUtils-MakeMaker wget gcc
    wget -P /usr/local/src https://www.kernel.org/pub/software/scm/git/git-$1.tar.gz
    tar zfx /usr/local/src/git-$1.tar.gz -C /usr/local/src
    make -C /usr/local/src/git-$1 prefix=/usr/local all
    make -C /usr/local/src/git-$1 prefix=/usr/local install
    git --version
}


install_openjdk()
{
    log "Installing OpenJDK $1"
    yum -y install java-$1-openjdk-devel
}


install_maven()
{
    log "Installing Maven $1"
    wget -v -P /opt https://archive.apache.org/dist/maven/maven-3/$1/binaries/apache-maven-$1-bin.tar.gz
    tar xzf /opt/apache-maven-$1-bin.tar.gz -C /opt
    rm -f /opt/apache-maven-$1-bin.tar.gz
}


install_japanese_font()
{
    log "Installing Japanese Fonts"
    yum -y install vlgothic-p-fonts vlgothic-fonts ibus-kkc
}


install_firefox()
{
    log "Installing Firefox"
    yum -y install firefox
}


install_xvfb()
{
    log "Installing Xvfb"
    yum -y install xorg-x11-server-Xvfb
}


install_jenkins()
{
    log "Installing Jenkins"
    wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat/jenkins.repo
    rpm --import http://pkg.jenkins-ci.org/redhat/jenkins-ci.org.key
    yum -y install http://pkg.jenkins-ci.org/redhat/jenkins-$1-1.1.noarch.rpm
}


start_jenkins()
{
    log "Starting Jenkins"
    systemctl start jenkins
}


install_jenkins_cli()
{
    log "Installing Jenkins CLI"
    sleep 5

    local http_response_code=503
    while [ $http_response_code -ne 200 ]
    do
        http_response_code=`curl -LI ${jenkins_url}jnlpJars/jenkins-cli.jar -o /dev/null -w '%{http_code}' -s`
        echo $http_response_code
        sleep 5
    done
    wget -t 5 --waitretry 5 -O /tmp/jenkins-cli.jar ${jenkins_url}jnlpJars/jenkins-cli.jar
}


update_jenkins_updatecenter()
{
    log "Update Jenkins updatecenter"
    curl -L http://updates.jenkins-ci.org/update-center.json | sed '1d;$d' > /var/lib/jenkins/updates/default.json
}


install_jenkins_plugins()
{
    log "Installing Jenkins Plugins"
    sleep 5
    plugins=("git" "checkstyle" "xvfb" "timestamper" "build-pipeline-plugin" "warnings" "mask-passwords" "saferestart" "websphere-deployer")

    for plugin_name in ${plugins[@]}; do
        java -jar /tmp/jenkins-cli.jar -s ${jenkins_url} list-plugins | awk '{print $1}' | grep ^${plugin_name}
        rc=$?
        if [ $rc = 0 ]; then
            echo ${plugin_name} is installed.
        else
            java -jar /tmp/jenkins-cli.jar -s ${jenkins_url} install-plugin ${plugin_name}
        fi
    done
}


restart_jenkins()
{
    log "Restarting Jenkins"
    java -jar /tmp/jenkins-cli.jar -s ${jenkins_url} safe-restart
}


init
install_openjdk "1.6.0"
install_openjdk "1.8.0"
install_git "2.8.2"
install_maven "3.2.5"
install_maven "3.3.9"
install_jenkins "1.658"
start_jenkins
install_jenkins_cli
update_jenkins_updatecenter
install_jenkins_plugins
restart_jenkins
install_japanese_font
install_firefox
install_xvfb

exit 0
