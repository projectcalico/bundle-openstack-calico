#!/bin/bash

usage() {
    cat <<EOF
# Usage:
#
# ./gen-bundle.sh <openstack_release> [<calico-origin>]
# ./gen-bundle.sh --help | -h
#
# <openstack_release> must be either kilo or liberty, and must be specified.
#
# <calico-origin> can be specified to indicate an alternate Calico code PPA,
# e.g. for testing or pre-release code.  Otherwise the bundle will use the
# stable Calico PPA for the chosen OpenStack release.
EOF
    exit $1
}

# No args: print usage and exit with bad status.
if [ $# -lt 1 ]; then
    usage -1
fi

# Process args.
case $1 in
    -h | --help )
	# Help: print usage and exit successfully.
	usage 0
	;;

    kilo | liberty )
	# Valid OpenStack release.
	openstack_release=$1
	calico_origin=$2
	;;

    * )
	# Anything else: bad usage.
	usage -1
	;;
esac

# Generate bundle.
cat <<EOF
services:
  bird:
    charm: "cs:trusty/bird"
    num_units: 1
    annotations:
      "gui-x": "750"
      "gui-y": "500"
  cinder:
    charm: "cs:trusty/cinder"
    num_units: 1
    annotations:
      "gui-x": "0"
      "gui-y": "500"
    options:
      "openstack-origin": "cloud:trusty-${openstack_release}"
  etcd:
    charm: "cs:trusty/etcd"
    num_units: 1
    annotations:
      "gui-x": "750"
      "gui-y": "250"
  glance:
    charm: "cs:trusty/glance"
    num_units: 1
    annotations:
      "gui-x": "0"
      "gui-y": "0"
    to: [ bird ]
    options:
      "openstack-origin": "cloud:trusty-${openstack_release}"
  keystone:
    charm: "cs:trusty/keystone"
    num_units: 1
    annotations:
      "gui-x": "500"
      "gui-y": "250"
    options:
      "admin-password": "openstack"
      "openstack-origin": "cloud:trusty-${openstack_release}"
  mysql:
    charm: "cs:trusty/mysql"
    num_units: 1
    annotations:
      "gui-x": "250"
      "gui-y": "0"
  "neutron-api":
    charm: "cs:~openstack-charmers-next/trusty/neutron-api"
    num_units: 1
    options:
EOF

[ -n "${calico_origin}" ] && cat <<EOF
      "calico-origin": "${calico_origin}"
EOF

cat <<EOF
      "neutron-plugin": Calico
      "neutron-security-groups": true
      "openstack-origin": "cloud:trusty-${openstack_release}"
    annotations:
      "gui-x": "500"
      "gui-y": "0"
  "neutron-calico":
    charm: "cs:~project-calico/trusty/neutron-calico"
    num_units: 0
    annotations:
      "gui-x": "500"
      "gui-y": "500"
    options:
EOF

[ -n "${calico_origin}" ] && cat <<EOF
      "calico-origin": "${calico_origin}"
EOF

cat <<EOF
      "openstack-origin": "cloud:trusty-${openstack_release}"
  "nova-cloud-controller":
    charm: "cs:trusty/nova-cloud-controller"
    num_units: 1
    options:
      "network-manager": Neutron
      "openstack-origin": "cloud:trusty-${openstack_release}"
    annotations:
      "gui-x": "250"
      "gui-y": "250"
  "nova-compute":
    charm: "cs:trusty/nova-compute"
    num_units: 2
    annotations:
      "gui-x": "0"
      "gui-y": "250"
    options:
      "cpu-mode": "none"
      "openstack-origin": "cloud:trusty-${openstack_release}"
      "virt-type": "qemu"
  "openstack-dashboard":
    charm: "cs:trusty/openstack-dashboard"
    num_units: 1
    options:
      "ubuntu-theme": "no"
      "openstack-origin": "cloud:trusty-${openstack_release}"
    annotations:
      "gui-x": "750"
      "gui-y": "0"
    to: [ bird ]
  "rabbitmq-server":
    charm: "cs:trusty/rabbitmq-server"
    num_units: 1
    annotations:
      "gui-x": "250"
      "gui-y": "500"
    to: [ bird ]
relations:
  - - "nova-cloud-controller:image-service"
    - "glance:image-service"
  - - "neutron-calico:etcd-proxy"
    - "etcd:proxy"
  - - "neutron-api:etcd-proxy"
    - "etcd:proxy"
  - - "neutron-calico:amqp"
    - "rabbitmq-server:amqp"
  - - "neutron-calico:neutron-plugin-api"
    - "neutron-api:neutron-plugin-api"
  - - "openstack-dashboard:identity-service"
    - "keystone:identity-service"
  - - "neutron-calico:neutron-plugin"
    - "nova-compute:neutron-plugin"
  - - "nova-compute:cloud-compute"
    - "nova-cloud-controller:cloud-compute"
  - - "nova-compute:amqp"
    - "rabbitmq-server:amqp"
  - - "nova-cloud-controller:identity-service"
    - "keystone:identity-service"
  - - "cinder:cinder-volume-service"
    - "nova-cloud-controller:cinder-volume-service"
  - - "cinder:amqp"
    - "rabbitmq-server:amqp"
  - - "glance:image-service"
    - "cinder:image-service"
  - - "neutron-api:neutron-api"
    - "nova-cloud-controller:neutron-api"
  - - "neutron-api:amqp"
    - "rabbitmq-server:amqp"
  - - "neutron-calico:bgp-route-reflector"
    - "bird:bgp-route-reflector"
  - - "nova-cloud-controller:shared-db"
    - "mysql:shared-db"
  - - "nova-cloud-controller:amqp"
    - "rabbitmq-server:amqp"
  - - "nova-compute:image-service"
    - "glance:image-service"
  - - "glance:identity-service"
    - "keystone:identity-service"
  - - "mysql:shared-db"
    - "keystone:shared-db"
  - - "nova-compute:shared-db"
    - "mysql:shared-db"
  - - "glance:shared-db"
    - "mysql:shared-db"
  - - "mysql:shared-db"
    - "cinder:shared-db"
  - - "cinder:identity-service"
    - "keystone:identity-service"
  - - "neutron-api:shared-db"
    - "mysql:shared-db"
  - - "neutron-api:identity-service"
    - "keystone:identity-service"
series: trusty
EOF
