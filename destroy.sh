#!/bin/bash -x

# Networking: Load Balancer
aws elb delete-load-balancer \
  --load-balancer-name kubernetes

# I got an error so lets wait a bit before moving on
sleep 10

# Networking: Internet Gateway
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=kubernetes" | \
  jq -r '.Vpcs[].VpcId')

INTERNET_GATEWAY_ID=$(aws ec2 describe-internet-gateways \
  --filters "Name=tag:Name,Values=kubernetes" | \
  jq -r '.InternetGateways[].InternetGatewayId')

aws ec2 detach-internet-gateway \
  --internet-gateway-id ${INTERNET_GATEWAY_ID} \
  --vpc-id ${VPC_ID}

aws ec2 delete-internet-gateway \
  --internet-gateway-id ${INTERNET_GATEWAY_ID}

# Networking: Security Groups
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=kubernetes" | \
  jq -r '.SecurityGroups[].GroupId')

aws ec2 delete-security-group \
  --group-id ${SECURITY_GROUP_ID}


# Networking: Subnets
SUBNET_ID=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=kubernetes" | \
  jq -r '.Subnets[].SubnetId')

aws ec2 delete-subnet --subnet-id ${SUBNET_ID}

# Networking: Route Tables
ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=kubernetes" | \
  jq -r '.RouteTables[].RouteTableId')

aws ec2 delete-route-table --route-table-id ${ROUTE_TABLE_ID}

# Networking: VPC
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=kubernetes" | \
  jq -r '.Vpcs[].VpcId')

aws ec2 delete-vpc --vpc-id ${VPC_ID}

# Networking: DHCP Option Sets
DHCP_OPTION_SET_ID=$(aws ec2 describe-dhcp-options \
  --filters "Name=tag:Name,Values=kubernetes" | \
  jq -r '.DhcpOptions[].DhcpOptionsId')

aws ec2 delete-dhcp-options \
  --dhcp-options-id ${DHCP_OPTION_SET_ID}
