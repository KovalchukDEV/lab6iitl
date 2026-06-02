
# 1. Визначаємо провайдера та версію
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 2. Налаштування провайдера AWS
provider "aws" {
  region = var.aws_region
}

# ============================================================
# ЗМІННІ
# ============================================================

variable "aws_region" {
  description = "AWS регіон для розгортання інфраструктури"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "Тип EC2 інстансу"
  type        = string
  default     = "t3.micro" 
}

variable "ami_id" {
  description = "Amazon Machine Image ID (Amazon Linux 2023, us-east-1)"
  type        = string
  default     = "ami-0c7217cdde317cfec" # Amazon Linux 2023 (us-east-1)
}

variable "key_name" {
  description = "Назва SSH ключа, завантаженого в AWS"
  type        = string
  # Значення передається через змінну середовища TF_VAR_key_name
  # або через terraform.tfvars
}

variable "app_port" {
  description = "Порт, на якому працює застосунок (Docker контейнер)"
  type        = number
  default     = 3000
}

# ============================================================
# SECURITY GROUP
# ============================================================

resource "aws_security_group" "app_sg" {
  name        = "lab-terraform-sg"
  description = "Security Group for lab EC2 instance"

  # SSH доступ
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP (80) — для nginx або прямого доступу
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS (443)
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Порт застосунку (Docker)
  ingress {
    description = "App port"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Весь вихідний трафік дозволено
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "Lab-Terraform-SG"
    Environment = "Education"
  }
}

# ============================================================
# EC2 ІНСТАНС
# ============================================================

resource "aws_instance" "web_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  # User Data — автоматична установка Docker при першому запуску
  user_data = <<-EOF
    #!/bin/bash
    # Оновлення пакетів
    yum update -y

    # Встановлення Docker
    yum install -y docker
    systemctl start docker
    systemctl enable docker

    # Додаємо ec2-user до групи docker (щоб не потрібен sudo)
    usermod -aG docker ec2-user

    # Встановлення Docker Compose
    curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
      -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
  EOF

  tags = {
    Name        = "Lab-Terraform-Instance"
    Environment = "Education"
  }
}

# ============================================================
# OUTPUTS — дані після створення інфраструктури
# ============================================================

output "instance_public_ip" {
  description = "Публічна IP-адреса створеного сервера"
  value       = aws_instance.web_server.public_ip
}

output "instance_public_dns" {
  description = "Публічний DNS-запис сервера"
  value       = aws_instance.web_server.public_dns
}

output "instance_id" {
  description = "ID створеного EC2 інстансу"
  value       = aws_instance.web_server.id
}

output "ssh_command" {
  description = "Команда для підключення до сервера по SSH"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${aws_instance.web_server.public_ip}"
}

output "security_group_id" {
  description = "ID Security Group"
  value       = aws_security_group.app_sg.id
}
