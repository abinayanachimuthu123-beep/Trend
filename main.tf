terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

# VPC
resource "aws_vpc" "trend_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "trend-vpc"
  }
}

# Subnet
resource "aws_subnet" "trend_subnet" {
  vpc_id            = aws_vpc.trend_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-2a"
  tags = {
    Name = "trend-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "trend_igw" {
  vpc_id = aws_vpc.trend_vpc.id
  tags = {
    Name = "trend-igw"
  }
}

# Security Group
resource "aws_security_group" "trend_sg" {
  vpc_id = aws_vpc.trend_vpc.id
  name   = "trend-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
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
    Name = "trend-sg"
  }
}

# IAM Role for EC2
resource "aws_iam_role" "trend_ec2_role" {
  name = "trend-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "trend_ec2_policy" {
  role       = aws_iam_role.trend_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_instance_profile" "trend_profile" {
  name = "trend-ec2-profile"
  role = aws_iam_role.trend_ec2_role.name
}

# EC2 Instance with Jenkins
resource "aws_instance" "trend_jenkins" {
  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.trend_subnet.id
  vpc_security_group_ids = [aws_security_group.trend_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.trend_profile.name

  user_data = <<-EOF
    #!/bin/bash
    sudo apt-get update -y
    sudo apt-get install -y openjdk-17-jdk
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y jenkins
    sudo systemctl start jenkins
    sudo systemctl enable jenkins
  EOF

  tags = {
    Name = "trend-jenkins-ec2"
  }
}

output "jenkins_public_ip" {
  value = aws_instance.trend_jenkins.public_ip
}
