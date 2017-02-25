#!/bin/bash +x

# Cloud Infrastructure Provisioning - Amazon Web Services

# Networking: VPC
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.240.0.0/16 | \
  jq -r '.Vpc.VpcId')

aws ec2 create-tags \
  --resources ${VPC_ID} \
  --tags Key=Name,Value=kubernetes

aws ec2 modify-vpc-attribute \
  --vpc-id ${VPC_ID} \
  --enable-dns-support '{"Value": true}'

aws ec2 modify-vpc-attribute \
  --vpc-id ${VPC_ID} \
  --enable-dns-hostnames '{"Value": true}'

# Networking: DHCP Option Sets
DHCP_OPTION_SET_ID=$(aws ec2 create-dhcp-options \
  --dhcp-configuration "Key=domain-name,Values=us-west-2.compute.internal" \
    "Key=domain-name-servers,Values=AmazonProvidedDNS" | \
  jq -r '.DhcpOptions.DhcpOptionsId')

aws ec2 create-tags \
  --resources ${DHCP_OPTION_SET_ID} \
  --tags Key=Name,Value=kubernetes

aws ec2 associate-dhcp-options \
  --dhcp-options-id ${DHCP_OPTION_SET_ID} \
  --vpc-id ${VPC_ID}

# Networking: Subnets 
SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id ${VPC_ID} \
  --cidr-block 10.240.0.0/24 | \
  jq -r '.Subnet.SubnetId')

aws ec2 create-tags \
  --resources ${SUBNET_ID} \
  --tags Key=Name,Value=kubernetes

# Networking: Internet Gateway 
INTERNET_GATEWAY_ID=$(aws ec2 create-internet-gateway | \
  jq -r '.InternetGateway.InternetGatewayId')

aws ec2 create-tags \
  --resources ${INTERNET_GATEWAY_ID} \
  --tags Key=Name,Value=kubernetes

aws ec2 attach-internet-gateway \
  --internet-gateway-id ${INTERNET_GATEWAY_ID} \
  --vpc-id ${VPC_ID}

# Networking: Route Tables 
ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id ${VPC_ID} | \
  jq -r '.RouteTable.RouteTableId')

aws ec2 create-tags \
  --resources ${ROUTE_TABLE_ID} \
  --tags Key=Name,Value=kubernetes

aws ec2 associate-route-table \
  --route-table-id ${ROUTE_TABLE_ID} \
  --subnet-id ${SUBNET_ID}

aws ec2 create-route \
  --route-table-id ${ROUTE_TABLE_ID} \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id ${INTERNET_GATEWAY_ID}


# Networking: Firewall Rules
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
  --group-name kubernetes \
  --description "Kubernetes security group" \
  --vpc-id ${VPC_ID} | \
  jq -r '.GroupId')

aws ec2 create-tags \
  --resources ${SECURITY_GROUP_ID} \
  --tags Key=Name,Value=kubernetes

aws ec2 authorize-security-group-ingress \
  --group-id ${SECURITY_GROUP_ID} \
  --protocol all

aws ec2 authorize-security-group-ingress \
  --group-id ${SECURITY_GROUP_ID} \
  --protocol all \
  --port 0-65535 \
  --cidr 10.240.0.0/16

aws ec2 authorize-security-group-ingress \
  --group-id ${SECURITY_GROUP_ID} \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id ${SECURITY_GROUP_ID} \
  --protocol tcp \
  --port 6443 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id ${SECURITY_GROUP_ID} \
  --protocol all \
  --source-group ${SECURITY_GROUP_ID}

 
# Networking: Load Balancer
aws elb create-load-balancer \
  --load-balancer-name kubernetes \
  --listeners "Protocol=TCP,LoadBalancerPort=6443,InstanceProtocol=TCP,InstancePort=6443" \
  --subnets ${SUBNET_ID} \
  --security-groups ${SECURITY_GROUP_ID}
 
# Virtual Machines: Instance IAM Policies
cat > kubernetes-iam-role.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect": "Allow", "Principal": { "Service": "ec2.amazonaws.com"}, "Action": "sts:AssumeRole"}
  ]
}
EOF

aws iam create-role \
  --role-name kubernetes \
  --assume-role-policy-document file://kubernetes-iam-role.json

cat > kubernetes-iam-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect": "Allow", "Action": ["ec2:*"], "Resource": ["*"]},
    {"Effect": "Allow", "Action": ["elasticloadbalancing:*"], "Resource": ["*"]},
    {"Effect": "Allow", "Action": ["route53:*"], "Resource": ["*"]},
    {"Effect": "Allow", "Action": ["ecr:*"], "Resource": "*"}
  ]
}
EOF

aws iam put-role-policy \
  --role-name kubernetes \
  --policy-name kubernetes \
  --policy-document file://kubernetes-iam-policy.json

aws iam create-instance-profile \
  --instance-profile-name kubernetes

aws iam add-role-to-instance-profile \
  --instance-profile-name kubernetes \
  --role-name kubernetes

