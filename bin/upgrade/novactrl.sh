#!/bin/bash

function usage {
  echo ""
  echo "This will upgrade novactrl in a location, including deps"
  echo "./${0} <location> --<opt>"
  echo "Example: ./${0} test01 --check"
  echo ""
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi

loc=$1

if [ -z $2 ]; then
  opt=""
else
  opt="$2"
fi

sudo ansible-playbook $opt -e "myhosts=${loc}-identity-01" lib/puppetrun.yaml
sudo ansible $opt "${loc}-proxy-02" --become -m shell -a '. /root/openrc && for id in `openstack endpoint list -f json | jq -r ".[] | select(.\"Service Name\" == \"novav3\") | .ID"`; do openstack endpoint delete $id; done'
sudo ansible-playbook $opt -e "myhosts=${loc}-db-02" lib/puppetrun.yaml
sudo ansible-playbook $opt -e "myhosts=${loc}-db-02" lib/puppetrun.yaml
sudo ansible-playbook $opt -e "myhosts=${loc}-novactrl-01" lib/upgrade/compute.yaml
