#!/bin/bash

set -x

# Deploy bundle with Calico and Mitaka OpenStack code on Xenial machines.
# juju deploy mitaka.yaml

# Network modelling prep.  Use the machine running the mgmt network RR (bird/0)
# as the network node.  Client nodes will be the compute nodes and the ToRs.
L2TP_SH=/home/neil/calico/l2tp/l2tp.sh
NET=bird/0
TOR1=bird-tor1/0
TOR2=bird-tor2/0
COMP1=nova-compute/0
COMP2=nova-compute/1
for unit in ${NET} ${TOR1} ${TOR2} ${COMP1} ${COMP2}; do
    juju ssh ${unit} sudo apt-get update
    juju ssh ${unit} sudo apt-get -y install linux-image-extra-virtual
done
for unit in ${NET} ${TOR1} ${TOR2} ${COMP1} ${COMP2}; do
    juju scp ${L2TP_SH} ${unit}:
    juju ssh ${unit} chmod a+x l2tp.sh
done

# Generate the IP address file, and install it on all nodes.
L2TP_ADDRS_SH=l2tp_addrs.sh
rm -f ${L2TP_ADDRS_SH}
echo NET_IP=`juju run --unit ${NET} "unit-get private-address"` >> ${L2TP_ADDRS_SH}
echo CLIENT_IP[1]=`juju run --unit ${TOR1} "unit-get private-address"` >> ${L2TP_ADDRS_SH}
echo CLIENT_IP[2]=`juju run --unit ${TOR2} "unit-get private-address"` >> ${L2TP_ADDRS_SH}
echo CLIENT_IP[3]=`juju run --unit ${COMP1} "unit-get private-address"` >> ${L2TP_ADDRS_SH}
echo CLIENT_IP[4]=`juju run --unit ${COMP2} "unit-get private-address"` >> ${L2TP_ADDRS_SH}
for unit in ${NET} ${TOR1} ${TOR2} ${COMP1} ${COMP2}; do
    juju scp ${L2TP_ADDRS_SH} ${unit}:
done
. ${L2TP_ADDRS_SH}

RR=${NET}
RR_IP=${NET_IP}

# Connectivity test.
for unit in ${NET} ${TOR1} ${TOR2} ${COMP1} ${COMP2}; do
    juju ssh ${unit} ./l2tp.sh ping
done

# Model subnets between...
# ...nova-compute/0 and bird-tor1/0:
juju ssh ${NET} sudo ./l2tp.sh network 1 3 1
juju ssh ${COMP1} sudo ./l2tp.sh client 1 3
juju ssh ${TOR1} sudo ./l2tp.sh client 1 1
# ...nova-compute/0 and bird-tor2/0:
juju ssh ${NET} sudo ./l2tp.sh network 2 3 2
juju ssh ${COMP1} sudo ./l2tp.sh client 2 3
juju ssh ${TOR2} sudo ./l2tp.sh client 2 2
# ...nova-compute/1 and bird-tor1/0:
juju ssh ${NET} sudo ./l2tp.sh network 3 4 1
juju ssh ${COMP2} sudo ./l2tp.sh client 3 4
juju ssh ${TOR1} sudo ./l2tp.sh client 3 1
# ...nova-compute/1 and bird-tor2/0:
juju ssh ${NET} sudo ./l2tp.sh network 4 4 2
juju ssh ${COMP2} sudo ./l2tp.sh client 4 4
juju ssh ${TOR2} sudo ./l2tp.sh client 4 2

# Virtual network connectivity test.
juju ssh ${COMP1} ping -c 1 10.1.0.1
juju ssh ${TOR1} ping -c 1 10.1.0.3
juju ssh ${COMP1} ping -c 1 10.2.0.2
juju ssh ${TOR2} ping -c 1 10.2.0.3
juju ssh ${COMP2} ping -c 1 10.3.0.1
juju ssh ${TOR1} ping -c 1 10.3.0.4
juju ssh ${COMP2} ping -c 1 10.4.0.2
juju ssh ${TOR2} ping -c 1 10.4.0.4

function gen_global_bird_conf {
    router_id=$1
    as=$2
    cat <<EOF
router id ${router_id};

filter export_data {
  if ( (ifname ~ "tap*") || (ifname ~ "l2tpeth*") ) then {
    if net ~ 11.0.0.0/8 then reject;
    if net != 0.0.0.0/0 then accept;
  }
  reject;
}

filter export_mgmt {
  if ( (ifname ~ "tap*") || (ifname ~ "eth*") ) then {
    if net ~ 11.0.0.0/8 then accept;
  }
  reject;
}

protocol kernel {
  learn;          # Learn all alien routes from the kernel
  persist;        # Don't remove routes on bird shutdown
  scan time 2;    # Scan kernel routing table every 2 seconds
  import all;
  graceful restart;
  export all;     # Default is export none
  merge paths on;
}

protocol device {
  scan time 2;    # Scan interfaces every 2 seconds
}

protocol direct {
   debug all;
   interface "eth*", "l2tpeth*";
}

template bgp bgp_template {
  debug { states };
  local as ${as};
  multihop;
  import all;
  next hop self;
  add paths on;
  graceful restart;
}
EOF
}

function gen_peer_bird_conf {
    name=$1
    desc=$2
    peer_ip=$3
    peer_as=$4
    filter=$5
    cat <<EOF

protocol bgp '${name}' from bgp_template {
  description "${desc}";
  neighbor ${peer_ip} as ${peer_as};
  export filter export_${filter};
}
EOF
}

# Generate BIRD config for ${COMP1}
gen_global_bird_conf ${CLIENT_IP[3]} 65003 >bird.conf
gen_peer_bird_conf T1 "Peer with TOR1" 10.1.0.1 65001 data >>bird.conf
gen_peer_bird_conf T2 "Peer with TOR2" 10.2.0.2 65002 data >>bird.conf
gen_peer_bird_conf RR "Peer with Mgmt" ${RR_IP} 64511 mgmt >>bird.conf
juju scp bird.conf ${COMP1}:
juju ssh ${COMP1} sudo cp -f bird.conf /etc/bird/
juju ssh ${COMP1} sudo service bird restart

# Generate BIRD config for ${COMP2}
gen_global_bird_conf ${CLIENT_IP[4]} 65004 >bird.conf
gen_peer_bird_conf T1 "Peer with TOR1" 10.3.0.1 65001 data >>bird.conf
gen_peer_bird_conf T2 "Peer with TOR2" 10.4.0.2 65002 data >>bird.conf
gen_peer_bird_conf RR "Peer with Mgmt" ${RR_IP} 64511 mgmt >>bird.conf
juju scp bird.conf ${COMP2}:
juju ssh ${COMP2} sudo cp -f bird.conf /etc/bird/
juju ssh ${COMP2} sudo service bird restart

# Generate BIRD config for ${TOR1}
gen_global_bird_conf ${CLIENT_IP[1]} 65001 >bird.conf
gen_peer_bird_conf C1 "Peer with COMP1" 10.1.0.3 65003 data >>bird.conf
gen_peer_bird_conf C2 "Peer with COMP2" 10.3.0.4 65004 data >>bird.conf
juju scp bird.conf ${TOR1}:
juju ssh ${TOR1} sudo cp -f bird.conf /etc/bird/
juju ssh ${TOR1} sudo service bird restart

# Generate BIRD config for ${TOR2}
gen_global_bird_conf ${CLIENT_IP[2]} 65002 >bird.conf
gen_peer_bird_conf C1 "Peer with COMP1" 10.2.0.3 65003 data >>bird.conf
gen_peer_bird_conf C2 "Peer with COMP2" 10.4.0.4 65004 data >>bird.conf
juju scp bird.conf ${TOR2}:
juju ssh ${TOR2} sudo cp -f bird.conf /etc/bird/
juju ssh ${TOR2} sudo service bird restart

# Generate BIRD config for the Mgmt network RR
gen_global_bird_conf $RR_IP 64511 >bird.conf
gen_peer_bird_conf C1 "Peer with COMP1" ${CLIENT_IP[3]} 65003 mgmt >>bird.conf
gen_peer_bird_conf C2 "Peer with COMP2" ${CLIENT_IP[4]} 65004 mgmt >>bird.conf
juju scp bird.conf ${RR}:
juju ssh ${RR} sudo cp -f bird.conf /etc/bird/
juju ssh ${RR} sudo service bird restart

### Need to manually fix the BIRD config on RR NB can't have RR clients because
### all nodes are in different ASs.  Not sure how important this is yet.

### NB metadata race issue

function get_aws_instance_ids {
    juju machines | awk '/started/ {print $4;}'
}

function get_aws_instance_security_groups {
    instance=$1
    aws ec2 describe-instance-attribute --instance-id ${instance} --attribute groupSet | awk '/ sg-/ {print $2;}'
}

function set_aws_instance_security_groups {
    instance=$1
    shift
    aws ec2 modify-instance-attribute --instance-id ${instance} --groups $*
}

function disable_aws_instance_src_dst_check {
    instance=$1
    aws ec2 modify-instance-attribute --instance-id ${instance} --no-source-dest-check
}

openstack_services_id=sg-729ebf0a

aws_ids=`get_aws_instance_ids`
for id in $aws_ids; do
    existing_groups=`get_aws_instance_security_groups $id`
    case "$existing_groups" in

	*${openstack_services_id}* )
	    echo $id already has openstack-services group
	    ;;

	* )
	    set_aws_instance_security_groups $id $existing_groups ${openstack_services_id}
	    echo Added openstack-services group to $id
	    ;;

    esac
    disable_aws_instance_src_dst_check $id
done
