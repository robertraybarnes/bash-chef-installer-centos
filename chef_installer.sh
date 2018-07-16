#!/usr/bin/env bash

chefinstallurl="https://packages.chef.io/files/stable/chef-server/12.17.33/el/7/chef-server-core-12.17.33-1.el7.x86_64.rpm"
chefdkinstallurl="https://packages.chef.io/files/stable/chefdk/3.0.36/el/7/chefdk-3.0.36-1.el7.x86_64.rpm"
service="firewalld"
declare -a prereqs=("wget" "setroubleshoot-server" "selinux-policy-devel")
declare -a ports=("80" "443")

function prereqchecker {
    for app in "${prereqs[@]}";
    do
        yum install $app -y > /dev/null
        echo "all pre-requisites are installed"
    done
}

function installchefserver {
    if yum list installed chef-server-core 2>&1 > /dev/null;
    then
        echo "chef-server-core is already installed"
    else
        wget -O chef-server-core.rpm $chefinstallurl
        sudo rpm -Uhv chef-server-core.rpm
        chef-server-ctl reconfigure
    fi
    
}

function installchefdk {
    if yum list installed chefdk 2>&1 > /dev/null;
    then
        echo "chefdk is already installed"
    else
        wget -O chefdk.rpm https://packages.chef.io/files/stable/chefdk/3.0.36/el/7/chefdk-3.0.36-1.el7.x86_64.rpm
        sudo rpm -Uhv chefdk.rpm
    fi
}

function installchefmanage {
    if yum list installed chef-manage 2>&1 > /dev/null;
    then
        echo "chef manage is already installed"
    else
        sudo chef-server-ctl install chef-manage
        sudo chef-server-ctl reconfigure
        sudo chef-manage-ctl reconfigure --accept-license
    fi

}

function systemsecurity {
    if ps ax | grep -v grep | grep $service > /dev/null;
    then
        if firewall-cmd --list-all-zones |grep http > /dev/null;
        then
            echo "firewall is already running with the correct rules"
        else
            sudo firewall-cmd --zone=public --add-service=http --permanent
            sudo firewall-cmd --zone=public --add-service=https --permanent
            sudo firewall-cmd --reload
        fi
    else
        sudo systemctl start firewalld && systemctl enable firewalld > /dev/null
        sudo firewall-cmd --zone=public --add-service=http --permanent > /dev/null
        sudo firewall-cmd --zone=public --add-service=https --permanent > /dev/null
        sudo firewall-cmd --reload
    fi

    if sudo cat /etc/selinux/config |grep ^SELINUX=permissive > /dev/null;
    then
        sudo sed -i '/^SELINUX=permissive/SELINUX=enforcing/g' /etc/selinux/config
    else
        echo "SELinux config file is already set to enforcing"
    fi

    if sestatus |grep "Current mode"|grep enforcing > /dev/null;
    then
        echo "SELinux is enforcing"
    else
        sudo setenforce 1
    fi

    for port in "${ports[@]}";
    do
        if sudo semanage port -l | grep -w http_port_t | grep -w $port;
        then
            echo "port $port has already been added to the http_port_t type"
        else
            sudo semanage port -a -t http_port_t -p tcp $port
        fi
    done

}

prereqchecker
installchefserver
installchefdk
installchefmanage
systemsecurity