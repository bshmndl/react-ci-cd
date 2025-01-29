provider "aws" {
  region = "us-east-1" # Specify the AWS region
}

# Create a key pair (replace with your actual key pair name if you have one)
resource "aws_key_pair" "deployer" {
  key_name   = "minikube-key"
  public_key = file("~/.ssh/id_rsa.pub") # Path to your public SSH key
}

# Define a security group
resource "aws_security_group" "minikube_sg" {
  name_prefix = "minikube-sg-"

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an Ubuntu EC2 instance
resource "aws_instance" "minikube_instance" {
  ami           = "ami-08c40ec9ead489470" # Ubuntu 22.04 LTS AMI ID (update to match your region)
  instance_type = "t2.medium"             # Adjust based on your requirements
  key_name      = aws_key_pair.deployer.key_name
  security_groups = [
    aws_security_group.minikube_sg.name,
  ]

  # Install Minikube via user data script
  user_data = <<-EOF
    #!/bin/bash
    # Update packages and install dependencies
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

    # Install Docker
    apt-get install -y docker.io
    sudo systemctl enable docker
    sudo systemctl start docker

    # Install Minikube
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    chmod +x minikube-linux-amd64
    mv minikube-linux-amd64 /usr/local/bin/minikube

    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/kubectl

    # Start Minikube
    minikube start --driver=none

    # Enable bash completion for kubectl
    echo 'source <(kubectl completion bash)' >>~/.bashrc
  EOF

  tags = {
    Name = "Minikube-Ubuntu-Instance"
  }
}

output "instance_public_ip" {
  value       = aws_instance.minikube_instance.public_ip
  description = "Public IP of the EC2 instance where Minikube is installed"
}
