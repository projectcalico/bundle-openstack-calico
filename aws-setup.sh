#!/bin/bash

function get_aws_instance_ids {
    juju machines | awk '/started|pending/ {print $4;}'
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
