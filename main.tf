provider "aws" {
  region = "us-east-1" 
}

# VPC
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name        = "demo_vpc"
    Environment = "demo_environment"
    Terraform   = "true"
    region      = "us-east-1"
  }
}

# Security Groups

# Security group for EC2 instance
resource "aws_security_group" "ingress-ssh" {
  name   = "ingress-ssh"
  vpc_id = aws_vpc.vpc.id
  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow Port 8080 for Minikube"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Open Port 30080 for Minikube NodePort
  ingress {
    description = "Allow NodePort 30080 for Minikube"
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# public subnet
resource "aws_subnet" "public_subnets" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name      = "public_subnets"
    Terraform = "true"
  }
}
# route table associations
resource "aws_route_table_association" "public" {
  depends_on     = [aws_subnet.public_subnets]
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnets.id
}

# Internet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "demo_igw"
  }
}
#route tables for public  subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  tags = {
    Name      = "demo_public_rtb"
    Terraform = "true"
  }
}

resource "aws_instance" "minikube-server" {
  ami                         = "ami-04b4f1a9cf54c11d0" # Ubuntu AMI
  instance_type               = "t2.medium"
  subnet_id                   = aws_subnet.public_subnets.id
  security_groups             = [aws_security_group.ingress-ssh.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.generated.key_name
  root_block_device {
    volume_size = 30  
    volume_type = "gp3"  
    delete_on_termination = true
  }
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.generated.private_key_pem
    host        = self.public_ip
  }

  provisioner "local-exec" {
    command = "chmod 600 ${local_file.private_key_pem.filename}"
  }

 
  provisioner "remote-exec" {

    inline = [
      "sudo apt-get update -y",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release",

      # Install Docker
      "sudo apt-get install -y docker.io",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo usermod -aG docker $USER",

      # Install Minikube
      "curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64",
      "chmod +x minikube-linux-amd64",
      "sudo mv minikube-linux-amd64 /usr/local/bin/minikube",

      
      "curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl",
      "chmod +x kubectl",
      "sudo mv kubectl /usr/local/bin/kubectl",

      
      "sudo minikube start --driver=none",
      "minikube start",

      
      "echo 'source <(kubectl completion bash)' >> ~/.bashrc"
    ]
  }
  tags = {
    Name = "Minikube EC2 Server"
  }

  lifecycle {
    ignore_changes = [security_groups]
  }


}

resource "tls_private_key" "generated" {
  algorithm = "RSA"
}
resource "local_file" "private_key_pem" {
  content  = tls_private_key.generated.private_key_pem
  filename = "MyAWSKey.pem"
}
resource "aws_key_pair" "generated" {
  key_name   = "MyAWSKey"
  public_key = tls_private_key.generated.public_key_openssh

  lifecycle {
    ignore_changes = [key_name]
  }
}


output "instance_public_ip" {
  value = aws_instance.minikube-server.public_ip
}
