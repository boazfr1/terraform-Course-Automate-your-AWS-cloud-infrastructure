provider "aws" {
  region = "us-east-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

variable "access_key" {
  description = "aws access_key"
  type = string
}

variable "secret_key" {
  description = "aws secret_key"
  type = string
}

resource "aws_vpc" "prod_vpc" {
  cidr_block       = "10.0.0.0/16"

  tags = {
    Name = "prod_vpc"
  }
}

resource "aws_internet_gateway" "prod_gw" {
  vpc_id = aws_vpc.prod_vpc.id

  tags = {
    Name = "prod_gw"
  }
}

resource "aws_route_table" "prod_route_table" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod_gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.prod_gw.id
  }

  tags = {
    Name = "prod_route_table"
  }
}

resource "aws_subnet" "prod_subnet" {
  vpc_id     = aws_vpc.prod_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod_subnet"
  }
}

resource "aws_route_table_association" "association_to_subnet" {
  subnet_id      = aws_subnet.prod_subnet.id
  route_table_id = aws_route_table.prod_route_table.id
}

resource "aws_security_group" "allow_spcific_port_for_web" {
  name        = "allow_spcific_port_for_web"
  description = "Allow for 443, 80, 22"
  vpc_id      = aws_vpc.prod_vpc.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_web"
  }
}

resource "aws_network_interface" "web_interface" {
  subnet_id       = aws_subnet.prod_subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_spcific_port_for_web.id]
}

resource "aws_eip" "elastic_ip_addres" {
    depends_on = [ aws_internet_gateway.prod_gw, aws_instance.web ]
    domain = "vpc"
    network_interface = aws_network_interface.web_interface.id
    associate_with_private_ip = "10.0.1.50"
}


resource "aws_instance" "web" {
  ami           = "ami-080e1f13689e07408" 
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "terraform-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web_interface.id
  }


  user_data = <<-EOF
                !/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo hello boaz > /var/www/html/index.html'
                EOF

  tags = {
    Name = "HelloWorld"
  }
}

