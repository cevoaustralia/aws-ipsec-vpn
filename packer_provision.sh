#!/bin/bash
set -eux

echo "update and upgrade packages"
sudo yum -y update
sudo yum -y upgrade

echo "installing aws cli tools"
sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
sudo yum install -y awscli jq

echo "installing libreswan ipsec vpn"
sudo yum install -y libreswan

echo "moving ipsec.conf into place and restore permissions"
sudo mv /tmp/ipsec.conf /etc/ipsec.conf
sudo restorecon -R -v /etc/ipsec.conf

echo "configuring ipsec.secrets"
sudo tee /etc/ipsec.secrets << EOF
# libreswan /etc/ipsec.secrets
XXX_LOCAL_IP_XXX %any : PSK "XXX_PSK_XXX"
EOF

echo "enabling ip forwarding"
# enable ip forwarding
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -A INPUT -p UDP --dport 500 -j ACCEPT
sudo iptables -A INPUT -p UDP --dport 4500 -j ACCEPT
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables-save

echo "configuring SElinux"
# allow chkpwd in selinux
# this is so ipsec can auth against local accounts
sudo tee /tmp/chkpwd.te << EOF
module chkpwd 1.0;

require {
        type chkpwd_t;
        class capability dac_read_search;
}

#============= chkpwd_t ==============
allow chkpwd_t self:capability dac_read_search;
EOF

checkmodule -M -m -o /tmp/chkpwd.mod /tmp/chkpwd.te
semodule_package -m /tmp/chkpwd.mod -o /tmp/chkpwd.pp
sudo semodule -i /tmp/chkpwd.pp
sudo rm /tmp/chkpwd.pp /tmp/chkpwd.mod /tmp/chkpwd.te

echo "installing packages for directory services"
sudo yum -y install sssd realmd krb5-workstation
sudo yum -y install samba-common-tools

echo " Hardening instance"
sudo yum -y remove libnfsidmap nfs-utils rpcbind
sudo tee /etc/profile.d/autologout.sh << EOF
TMOUT=3600
readonly TMOUT
export TMOUT
EOF
sudo chmod go-rwx /home/*
sudo tee --append /root/.bash_profile <<< "umask 077"
sudo tee /etc/securetty <<< "console"
sudo tee --append /etc/sysctl.conf <<< "# Disable ICMP Redirect Acceptance"
sudo tee --append /etc/sysctl.conf <<< "net.ipv4.conf.all.accept_redirects = 0"
sudo tee --append /etc/sysctl.conf <<< "net.ipv4.conf.all.secure_redirects = 0"
sudo shred -u /etc/ssh/*_key /etc/ssh/*_key.pub
#rm ~/.ssh/authorized_keys
