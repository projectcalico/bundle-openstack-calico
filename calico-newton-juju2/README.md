# OpenStack Cloud with Calico Networking

This bundle deploys a small OpenStack Cloud (Newton release) on Ubuntu 16.04
LTS (Xenial) with Layer 3 networking by [Project Calico][], providing
Dashboard, Compute, Network, Block Storage, Identity and Image services.

## Requirements

This bundle deploys to Juju-managed VMs and/or bare metal servers; it requires
at least 9 VMs and/or bare metal servers.

Servers should have:

 - A minimum of 4GB of physical RAM.
 - Enough CPU cores to support your capacity requirements.

## Deployment

    juju quickstart u/project-calico/openstack-calico

## Components

By default this bundle deploys:

- 1 node for each OpenStack controller service
- 2 compute nodes.

Neutron API, Nova Compute and Etcd services are designed to be horizontally
scalable.

To scale Nova Compute:

    juju add-unit nova-compute # Add one more unit
    juju add-unit -n5 nova-compute # Add 5 more units

To scale Neutron API:

    juju add-unit neutron-api # Add one more unit
    juju add-unit -n2 neutron-api # Add 2 more unitsa

To scale Etcd:

    juju add-unit etcd # Add one more unit
    juju add-unit -n2 etcd # add 2 more units

## Ensuring it's working

To ensure your cloud is functioning correctly, deploy this bundle and then run
through the following sections.

All commands are executed from within the expanded bundle.

### Install OpenStack client tools

In order to configure and use your cloud, you'll need to install the
appropriate client tools:

    sudo apt-get -y install python-novaclient python-keystoneclient \
        python-glanceclient python-neutronclient

### Accessing the cloud

Check that you can access your cloud from the command line:

    source novarc
    keystone catalog

You should get a full listing of all services registered in the cloud - which
should include identity, compute, image and network.

### Configuring an image

In order to run instances on your cloud, you'll need to install an image to
boot instances from:

    mkdir -p ~/images
    wget -O ~/images/trusty-server-cloudimg-amd64-disk1.img \
        http://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img
    glance image-create --name="trusty" --visibility=public --progress \
        --container-format=bare --disk-format=qcow2 \
        < ~/images/trusty-server-cloudimg-amd64-disk1.img

### Configure networking

For the purposes of a quick test, we'll setup a network on an internal subnet.

    neutron net-create --shared calico-net
    neutron subnet-create calico-net 10.208.168.0/21 --name calico-subnet

This will allow VMs to communicate with each other; the easiest way to allow
external connectivity is to add a route to that subnet pointed at any of the
nova-compute instances.

In a production deployment you'd want to BGP peer your router into the deployed
route reflector.  For more information please consult the
[Calico External Connectivity][] documentation.

### Booting an instance

First generate a SSH keypair so that you can access your instances once you've
booted them:

    nova keypair-add mykey > ~/.ssh/id_rsa_cloud

**Note:** you can also upload an existing public key to the cloud rather than
generating a new one:

    nova keypair-add --pub-key ~/.ssh/id_rsa.pub mykey

You can now boot an instance on your cloud:

    nova boot --image trusty --flavor m1.small --key-name mykey \
        trusty-test

## What next?

Configuring and managing services on an OpenStack cloud is complex; take a look
a the [OpenStack Admin Guide][] for a complete reference on how to configure an
OpenStack cloud for your requirements.

## Useful Cloud URLs

 - OpenStack Dashboard: http://openstack-dashboard_ip/horizon

[Project Calico]: http://projectcalico.org
[Calico External Connectivity]: http://docs.projectcalico.org/en/latest/opens-external-conn.html
[OpenStack Admin Guide]: http://docs.openstack.org/admin-guide-cloud
