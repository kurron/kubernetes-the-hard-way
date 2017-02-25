#!/bin/bash -x

# Virtual Machines: Instances
KUBERNETES_HOSTS=(controller0 controller1 controller2 worker0 worker1 worker2)

for host in ${KUBERNETES_HOSTS[*]}; do
  INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${host}" | \
    jq -j '.Reservations[].Instances[].InstanceId')
  aws ec2 terminate-instances --instance-ids ${INSTANCE_ID}
done
 
# Virtual Machines: SSH Keys
aws ec2 delete-key-pair --key-name kubernetes
 
# Virtual Machines: Instance IAM Policies
aws iam remove-role-from-instance-profile \
  --instance-profile-name kubernetes \
  --role-name kubernetes

aws iam delete-instance-profile \
  --instance-profile-name kubernetes

aws iam delete-role-policy \
  --role-name kubernetes \
  --policy-name kubernetes

aws iam delete-role --role-name kubernetes

# need to wait until all the instances are removed or you get failures
echo 'Waiting for instances to terminate before proceeding to remaining clean up'
sleep 90

# Networking: Load Balancer
aws elb delete-load-balancer \
  --load-balancer-name kubernetes

# I got an error so lets wait a bit before moving on
echo 'Waiting for load balancer to terminate before proceeding to remaining clean up'
sleep 60

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


