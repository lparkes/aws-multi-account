# AWSTemplateFormatVersion: '2010-09-09'
# Description: Setup CIP VPC network - VPC, isolated subnet, application subnet, generic NACL, 2 Route Tables, NATGateway
# Parameters:
#   VPCAZA:
#     Type: AWS::EC2::AvailabilityZone::Name
#     Description: primary availability zone
#     Default: ap-southeast-2a
#   VPCAZB:
#     Type: AWS::EC2::AvailabilityZone::Name
#     Description: secondary availability zone
#     Default: ap-southeast-2b
#   VPCTenOctet:
#     Type: Number
#     Description: The Class B block to use for the VPC (0-255).
#     MaxValue: 255
#     MinValue: 0
#     Default: 0
#   VPCName:
#     Type: String
#     Description: Name for the VPC
#     Default: ATFL-VPC
#   Environment:
#     Type: String
#     Description: Envrionment of this VPC
#     AllowedValues:
#       - dev
#       - production
#       - staging
#       - uat
#       - test

# cidr_block = "10.0.0.0/16"

resource "aws_vpc" "dev" {

  cidr_block = var.cidr_block
  
  enable_dns_hostnames = true
  
  tags = {
    Name = var.vpc_name
    Environment = var.env
  }
}

locals {
  subnets = {
    1 = { zone = "a", purpose = "application" },
    2 = { zone = "b", purpose = "application" },
    3 = { zone = "a", purpose = "isolated" },
    4 = { zone = "b", purpose = "isolated" },
    5 = { zone = "a", purpose = "public" },
    6 = { zone = "b", purpose = "public" },
  }

  gatewayed = { for k,v in local.subnets : k => v if v.purpose != "isolated" }
  #public = { for k,v in local.subnets : k => v if v.purpose == "public" }
  #app    = { for k,v in local.subnets : k => v if v.purpose == "application" }
}



resource  "aws_subnet" "net" {
  for_each = local.subnets

  vpc_id = aws_vpc.dev.id
  cidr_block = cidrsubnet(var.cidr_block, 8, each.key)
  availability_zone = "${var.aws_region}${each.value.zone}"
  map_public_ip_on_launch = each.value.purpose == "public"
  
  tags = {
    Name = "${var.env}-subnet-${each.value.purpose}-${each.value.zone}"
    Environment = var.env
  }

}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.dev.id

  tags = {
    Name = var.igw_name
  }
}

resource "aws_eip" "nat_a" {
  vpc = true

  depends_on = [ aws_internet_gateway.gw ]
}

resource "aws_eip" "nat_b" {
  vpc = true
  
  depends_on = [ aws_internet_gateway.gw ]
}

resource "aws_nat_gateway" "gw_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.net[5].id

  depends_on = [ aws_internet_gateway.gw ]

  tags = {
    Name        = "${var.env}-nat-a"
    Environment = var.env
  }
}

resource "aws_nat_gateway" "gw_b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.net[6].id

  depends_on = [ aws_internet_gateway.gw ]

  tags = {
    Name        = "${var.env}-nat-b"
    Environment = var.env
  }
}

# We really should only have three route tables because we only have
# three destinations. All public subnets can (and should) share the
# same route table.
# One problem with that is that the attribute used to specify the
# destination differs depending on what sort of destination it is.
resource "aws_route_table" "rt" {
  for_each = local.gatewayed

  vpc_id = aws_vpc.dev.id

  # No inline routes because I'm not smart enough to drive that in
  # the presence of for_each.
  # Inline routes and aws_route resources can't be mixed and matched.
  
  tags = {
    Name        = "${var.env}-rt-${each.value.purpose}-sn-${each.value.zone}"
    Environment = var.env
  }
}

resource "aws_route_table_association" "a" {
  for_each = local.gatewayed

  subnet_id      = aws_subnet.net[each.key].id
  route_table_id = aws_route_table.rt[each.key].id
}

# The for_each ran out of steam here.
# A smarter set of subnet local variables is needed.
resource "aws_route" "r5" {
  route_table_id         = aws_route_table.rt[5].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route" "r6" {
  route_table_id         = aws_route_table.rt[6].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route" "r1" {
  route_table_id         = aws_route_table.rt[1].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.gw_a.id
}

resource "aws_route" "r2" {
  route_table_id         = aws_route_table.rt[2].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.gw_b.id
}

# Outputs:
#   VpcId:
#     Description: ID of the VPC
#     Value: !Ref VPC
#     Export:
#       Name: !Sub '${AWS::StackName}:VpcId'
#   VpcCidr:
#     Description: Cidr of the VPC
#     Value:
#       Fn::GetAtt:
#         - VPC
#         - CidrBlock
#     Export:
#       Name: !Sub '${AWS::StackName}:VpcCidr'
#   PublicSubnetA:
#     Description: ID of the application subnet on AZ A
#     Value: !Ref PublicSubnetA
#     Export:
#       Name: !Sub '${AWS::StackName}:PublicSubnetA'
#   PublicSubnetB:
#     Description: ID of the application subnet on AZ B
#     Value: !Ref PublicSubnetB
#     Export:
#       Name: !Sub '${AWS::StackName}:PublicSubnetB'
#   ApplicationSubnetA:
#     Description: ID of the application subnet on AZ A
#     Value: !Ref ApplicationSubnetA
#     Export:
#       Name: !Sub '${AWS::StackName}:ApplicationSubnetA'
#   ApplicationSubnetB:
#     Description: ID of the application subnet on AZ B
#     Value: !Ref ApplicationSubnetB
#     Export:
#       Name: !Sub '${AWS::StackName}:ApplicationSubnetB'
#   IsolatedSubnetA:
#     Description: ID of the isolated subnet on AZ A
#     Value: !Ref IsolatedSubnetA
#     Export:
#       Name: !Sub '${AWS::StackName}:IsolatedSubnetA'
#   IsolatedSubnetB:
#     Description: ID of the isolated subnet on AZ B
#     Value: !Ref IsolatedSubnetB
#     Export:
#       Name: !Sub '${AWS::StackName}:IsolatedSubnetB'
