#!/bin/bash

# print help
function usage {
  echo ""
  echo "This will rebuild a compute host."
  echo "You will need the HOSTNAME (not FQDN) of the host"
  echo "./${0} <location-compute-number>"
  echo ""
  exit 1
}

if ! [[ ${1} =~ ^[A-Za-z0-9._]+[-]+["compute"]+[-]+[A-Za-z0-9._] ]]; then
  echo "Usage:"
  echo "You will need the compute HOSTNAME (not FQDN) of the host"
  echo "./${0} <location-compute-number>"
  echo ""
  exit 1
fi

host=$1

# Use hostname not fqdn
if [[ $host == *.* ]] ; then
  usage
fi

IFS='-' read -r -a hostname <<< "$host"
location=${hostname[0]}

read -p "Are your sure you want to rebuild ${host}? " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 1
fi
echo

sudo ansible-playbook -e "myhosts=${host}" lib/check_for_running_instances.yaml || exit 1
sudo ansible-playbook -e "myhosts=${host}" lib/fix_uefi_bootorder.yaml # FIXME
sudo ansible-playbook -e "myhosts=${location}-proxy-02 sensu_expire=72000 install_host=${host}" lib/reinstall.yaml
#sudo ansible-playbook -e "myhosts=${location}-proxy-02 sensu_expire=7200 install_host=${host}" lib/reinstall.yaml
sudo ansible-playbook -e "myhosts=${host}" lib/reboot.yaml
sleep 120
sudo ansible-playbook -e "myhosts=${host} name=iptables" lib/systemd_restart.yaml
sudo ansible-playbook -e "myhosts=${host} name=ip6tables" lib/systemd_restart.yaml
sudo ansible-playbook -e "myhosts=${host}" lib/fix_for_new_instance_disk_special.yaml
sudo ansible-playbook -e "myhosts=${host}" lib/puppetrun.yaml
sudo ansible-playbook -e "myhosts=${host}" lib/reinstall_nova-common.yaml
sudo ansible-playbook -e "myhosts=${host}" lib/push_secrets.yaml
sudo ansible-playbook -e "myhosts=${host} ip_version=ipv6" lib/flush_iptables.yaml
## Special for new instance disk
## This will run wipefs on /dev/sdb, run puppet and reinstall openstack-nova-common
#sudo ansible-playbook -e "myhosts=${host}" lib/restart_compute_services.yaml
sudo ansible-playbook -e "myhosts=${host}" lib/puppetrun.yaml
# FIXME: ip6tables issue must be solved in puppet code
#sudo ansible -u iaas -a 'ip6tables -I INPUT 10 -p udp -m multiport --dports 3784,3785,4784,4785 -m comment --comment "912 bird allow bfd ipv6" -m state --state NEW -j ACCEPT' -m shell ${host}
#sudo ansible-playbook -e "myhosts=${host} patchfile=${HOME}/ansible/files/patches/python-nova-newton-centos-7.3.0-discard.diff dest=/usr/lib/python2.7/site-packages/nova/virt/libvirt/driver.py" lib/patch.yaml
sudo ansible-playbook -e "myhosts=${host} name=openstack-nova-compute.service" lib/systemd_restart.yaml
sudo ansible-playbook -e "myhosts=${host} name=openstack-nova-metadata-api.service" lib/systemd_restart.yaml
sudo ansible-playbook -e "myhosts=${host} name=calico-felix" lib/systemd_restart.yaml
sleep 20
sudo ansible-playbook -e "myhosts=${host} name=calico-dhcp-agent" lib/systemd_restart.yaml
#sudo ansible-playbook -e "myhosts=${host} name=openstack-nova-compute.service" lib/systemd_restart.yaml
#sudo ansible-playbook -e "myhosts=${host}" lib/downgrade_etcd.yaml
# Fix for nova missing nvram flag when rebuilding from a uefi image
sudo ansible-playbook -e "myhosts=${host} patchfile=../files/patches/nova-libvirt-rebuild.diff dest=/usr/lib/python3.6/site-packages/nova/virt/libvirt/guest.py" lib/patch.yaml
sudo ansible-playbook -e "myhosts=${host} name=openstack-nova-compute" lib/systemd_restart.yaml
