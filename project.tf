# Provider configuration

provider "aws" {
  region = "us-east-1"
}

# Fetch the Elastic IP

data "aws_eip" "elastic_ip" {
  filter {
    name   = "tag:Project"
    values = ["NetSPI_EIP"]
  }
}

# Create S3 bucket

resource "aws_s3_bucket" "private_bucket" {
  bucket = "netspi-project-testing-1"

  tags = {
    Name = "NetSPI_S3"
  }
}

# Create VPC

resource "aws_vpc" "vpc" {
  cidr_block = "10.100.0.0/16"

  tags = {
    Name = "NetSPI_VPC"
  }
}

# Create Subnet

resource "aws_subnet" "subnet" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.100.1.0/24"

  tags = {
    Name = "NetSPI_Subnet"
  }
}

# Create Internet Gateway

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

# Route table for Internet Gateway
resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "NetSPI_RouteTable"
  }
}

# Associate route table with subnet

resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.rtb.id
}

# Security Group to allow SSH

resource "aws_security_group" "ec2_sg" {
  name   = "netspi_sg"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "NetSPI_Security_Group"
  }
}

# Create Key Pair

resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key_pair" {
  key_name   = "NetSPI_Key"
  public_key = tls_private_key.key.public_key_openssh
}

# Save the private key to a file

resource "local_file" "private_key" {
  content  = tls_private_key.key.private_key_pem
  filename = "${path.module}/NetSPI_Key.pem"
  file_permission = "0400"
}

# Create EFS file system

resource "aws_efs_file_system" "efs" {
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "NetSPI_EFS"
  }
}

# EFS Mount Target

resource "aws_efs_mount_target" "mount_target" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = aws_subnet.subnet.id
  security_groups = [aws_security_group.ec2_sg.id]  # Use security group ID
}

# Create an EC2 instance

resource "aws_instance" "ec2_instance" {
  ami                         = "ami-0e54eba7c51c234f6" 
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.key_pair.key_name
  subnet_id                   = aws_subnet.subnet.id
  security_groups             = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true

  # EFS mount command on boot

  user_data = <<-EOF
              #!/bin/bash
              yum install -y amazon-efs-utils
              mkdir -p /data/test
              mount -t efs ${aws_efs_file_system.efs.id}:/ /data/test
              EOF

  tags = {
    Name = "NetSPI_EC2"
  }

  depends_on = [aws_security_group.ec2_sg]
}

# Associate Elastic IP with EC2 instance

resource "aws_eip_association" "ec2_eip" {
  instance_id   = aws_instance.ec2_instance.id
  allocation_id = data.aws_eip.elastic_ip.id
}

# IAM role and policy for S3 access from EC2

resource "aws_iam_role" "s3_access_role" {
  name = "NetSPI_S3AccessRole"

  assume_role_policy = <<EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Principal": {
            "Service": "ec2.amazonaws.com"
          },
          "Effect": "Allow",
          "Sid": ""
        }
      ]
    }
  EOF
}

resource "aws_iam_role_policy_attachment" "s3_read_write_access" {
  role       = aws_iam_role.s3_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Attach IAM Role to EC2 instance

resource "aws_iam_instance_profile" "s3_instance_profile" {
  name = "NetSPI_S3Profile"
  role = aws_iam_role.s3_access_role.name
}

# Output for the required resources

output "s3_bucket_id" {
  value = aws_s3_bucket.private_bucket.id
}

output "efs_volume_id" {
  value = aws_efs_file_system.efs.id
}

output "ec2_instance_id" {
  value = aws_instance.ec2_instance.id
}

output "security_group_id" {
  value = aws_security_group.ec2_sg.id
}

output "subnet_id" {
  value = aws_subnet.subnet.id
}

# Output the path to the private key
output "private_key_path" {
  value = local_file.private_key.filename
}

