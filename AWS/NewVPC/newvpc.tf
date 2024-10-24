
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.72.1"
    }
  }
}

provider "aws" {
  region  = "us-west-2"
  profile = "CustomerDemoBox"
}

resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"

  tags = {
    Name = "Test-VPC"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnet-1"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "Test-IGW"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

resource "aws_route_table_association" "public_subnet" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}


resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-2b"

  tags = {
    Name = "PrivateSubnet-1"
  }
}

resource "aws_eip" "nat-gateway-eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat-gateway-eip.id

  subnet_id = aws_subnet.public_subnet.id

  tags = {
    Name = "Test-NAT-Gateway"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name = "PrivateRouteTable"
  }
}

resource "aws_route_table_association" "private_subnet" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}





resource "aws_security_group" "Mongo_NATS_SG" {
  name   = "Mongo_NATS"
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "Mongo_NATS_SG"
  }

}

resource "aws_vpc_security_group_ingress_rule" "mongo" {
  security_group_id            = aws_security_group.Mongo_NATS_SG.id
  referenced_security_group_id = aws_security_group.pl.id
  from_port                    = "27017"
  to_port                      = "27017"
  ip_protocol                  = "tcp"
  description                  = "Allow Mongo from PL"
}

resource "aws_vpc_security_group_ingress_rule" "nats" {
  security_group_id            = aws_security_group.Mongo_NATS_SG.id
  referenced_security_group_id = aws_security_group.pl.id
  from_port                    = "4222"
  to_port                      = "4222"
  ip_protocol                  = "tcp"
  description                  = "Allow Nats from PL"
}

resource "aws_vpc_security_group_egress_rule" "out1" {
  security_group_id = aws_security_group.Mongo_NATS_SG.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 0
  to_port           = 0
  ip_protocol       = "-1"
}


resource "aws_instance" "mongo_nats" {
  subnet_id            = aws_subnet.private_subnet.id
  ami                  = "ami-07c5ecd8498c59db5"
  instance_type        = "t2.micro"
  key_name             = "ECS_TEST"
  security_groups      = [aws_security_group.Mongo_NATS_SG.id]
  iam_instance_profile = "SSM_EC2_Role"
user_data = <<-EOF
#!/bin/bash
sudo yum update -y

sudo tee /etc/yum.repos.d/mongodb-org-6.0.repo > /dev/null <<EOL
[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2023/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc
EOL

sudo yum install -y mongodb-org
sudo sed -i 's/^  bindIp: .*$/  bindIp: 0.0.0.0/' /etc/mongod.conf
sudo systemctl start mongod
sudo systemctl enable mongod

# Install NATS Streaming Server
cd /home/ec2-user
wget https://github.com/nats-io/nats-streaming-server/releases/download/v0.22.0/nats-streaming-server-v0.22.0-linux-amd64.zip
unzip nats-streaming-server-v0.22.0-linux-amd64.zip
cd nats-streaming-server-v0.22.0-linux-amd64
nohup ./nats-streaming-server -p 4222 &
EOF

  tags = {
    Name = "MONGO_NATS"
  }
}



resource "aws_security_group" "pl" {
  name   = "PL"
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "PL_SG"
  }
}

resource "aws_vpc_security_group_ingress_rule" "nginx" {
  security_group_id = aws_security_group.pl.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = "443"
  to_port           = "443"
  ip_protocol       = "tcp"
  description       = "Allow Ingress for Nginx"
}

resource "aws_vpc_security_group_ingress_rule" "ssh1" {
  security_group_id = aws_security_group.pl.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = "22"
  to_port           = "22"
  ip_protocol       = "tcp"
  description       = "Allow Ingress for SSH"
}

resource "aws_vpc_security_group_egress_rule" "out2" {
  security_group_id = aws_security_group.pl.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 0
  to_port           = 0
  ip_protocol       = "-1"
}

resource "aws_instance" "pl" {
  subnet_id            = aws_subnet.public_subnet.id
  ami                  = "ami-07c5ecd8498c59db5"
  instance_type        = "t2.micro"
  key_name             = "ECS_TEST"
  security_groups      = [aws_security_group.pl.id]
  iam_instance_profile = "SSM_EC2_Role"
  user_data            = <<EOF
#!/bin/bash 
yum update -y
yum install telnet
EOF 
  tags = {
    Name = "PL"
  }
}