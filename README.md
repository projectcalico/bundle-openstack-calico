# Basic OpenStack Cloud with Calico L3 networking

This bundle deploys a basic OpenStack Cloud (Liberty release) on Ubuntu 14.04 LTS with Layer 3 networking by [Project Calico][], providing Dashboard, Compute, Network, Block Storage, Identity and Image services.

## Requirements

This bundle is designed to run on bare metal using Juju with [MAAS][] (Metal-as-a-Service); you will need to have setup a [MAAS][] deployment with a minimum of 9 physical servers prior to using this bundle.

Servers should have:

 - A minimum of 4GB of physical RAM.
 - Enough CPU cores to support your capacity requirements.

## Deployment

    juju quickstart u/project-calico/openstack-calico

## Components

 - 1 Node for each OpenStack controller service.
 - 2 Nodes for Nova Compute.

Neutron Api, Nova Compute and Etcd services are designed to be horizontally scalable.

To horizontally scale Nova Compute:

    juju add-unit nova-compute # Add one more unit
    juju add-unit -n5 nova-compute # Add 5 more units

To horizontally scale Neutron Api:

    juju add-unit neutron-api # Add one more unit
    juju add-unit -n2 neutron-api # Add 2 more unitsa

To horizontally scale Etcd:

    juju add-unit etcd # Add one more unit
    juju add-unit -n2 etcd # add 2 more units

**Note:** Other services in this bundle can be scaled in-conjunction with the hacluster charm to produce scalable, highly avaliable services - that will be covered in a different bundle.

## Ensuring it's working

To ensure your cloud is functioning correctly, download this bundle and then run through the following sections.

All commands are executed from within the expanded bundle.

### Install OpenStack client tools

In order to configure and use your cloud, you'll need to install the appropriate client tools:

    sudo apt-get -y install python-novaclient python-keystoneclient \
        python-glanceclient python-neutronclient

### Accessing the cloud

Check that you can access your cloud from the command line:

    source novarc
    keystone catalog

You should get a full listing of all services registered in the cloud which should include identity, compute, image and network.

### Configuring an image

In order to run instances on your cloud, you'll need to upload an image to boot instances from:

    mkdir -p ~/images
    wget -O ~/images/trusty-server-cloudimg-amd64-disk1.img \
        http://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img
    glance image-create --name="trusty" --is-public=true --progress \
        --container-format=bare --disk-format=qcow2 \
        < ~/images/trusty-server-cloudimg-amd64-disk1.img

### Configure networking

For the purposes of a quick test, we'll setup a network on an internal subnet.

    neutron net-create --shared calico-net
    neutron subnet-create calico-net 10.208.168.0/21 --name calico-subnet

This will allow VMs to communicate with each other; the easiest way to allow external connectivity is to add a route to that subnet pointed at any of the nova-compute instances.

In a production deployment you'd want to BGP peer your router into the deployed route reflector.  For more information please consult the [Calico External Connectivity][] documentation.

### Booting an instance

First generate a SSH keypair so that you can access your instances once you've booted them:

    nova keypair-add mykey > ~/.ssh/id_rsa_cloud

**Note:** you can also upload an existing public key to the cloud rather than generating a new one:

    nova keypair-add --pub-key ~/.ssh/id_rsa.pub mykey

You can now boot an instance on your cloud:

    nova boot --image trusty --flavor m1.small --key-name mykey \
        trusty-test

### Attaching a volume

First, create a volume in cinder:

    cinder create 10 # Create a 10G volume

then attach it to the instance we just booted in nova:

    nova volume-attach trusty-test <uuid-of-volume> /dev/vdc

The attached volume will be accessible once you login to the instance (see below).  It will need to be formatted and mounted!

## What next?

Configuring and managing services on an OpenStack cloud is complex; take a look a the [OpenStack Admin Guide][] for a complete reference on how to configure an OpenStack cloud for your requirements.

## Useful Cloud URL's

 - OpenStack Dashboard: http://openstack-dashboard_ip/horizon

[Project Calico]: http://projectcalico.org
[MAAS]: http://maas.ubuntu.com/docs
[Calico External Connectivity]: http://docs.projectcalico.org/en/latest/opens-external-conn.html
[Simplestreams]: https://launchpad.net/simplestreams
[OpenStack Admin Guide]: http://docs.openstack.org/admin-guide-cloud

