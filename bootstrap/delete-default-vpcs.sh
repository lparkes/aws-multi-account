#!/bin/sh

set -e

if [ "$1" = "" ]
then
    echo You must specify the AWS profile name 
    exit 1
fi

export AWS_PROFILE="$1"

regions=$(aws ec2 describe-regions  | jq -r '.Regions[].RegionName')

for r in $regions
do
   
    for vpc in $(aws ec2 describe-vpcs --region $r --filters Name=isDefault,Values=true | jq -r '.Vpcs[].VpcId')
    do
	# subnets
	for subnet in $(aws ec2 describe-subnets --region $r --filters Name=vpc-id,Values=$vpc | jq -r '.Subnets[].SubnetId')
	do
	    aws ec2 delete-subnet --subnet-id $subnet --region $r
	done
			   
	# security groups
	# nacls
	# igw
	for igw in $(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$vpc --region $r | jq -r '.InternetGateways[].InternetGatewayId')
	do
	    aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $vpc --region $r
	    aws ec2 delete-internet-gateway --internet-gateway-id $igw --region $r
	done
	# aws ec2 delete-internet-gateway --internet-gateway-id igw-9fff58f7
	# egress only igw
	# route tables
	
	# network interfaces
	# peering connections
	# endpoints
	aws ec2 delete-vpc --vpc-id $vpc --region $r

    done

    echo $r

done
