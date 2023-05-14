provider "aws" {
  region = "us-east-1"
}
resource "aws_s3_bucket" "my-ff_bucket" {
  bucket ="my-fgfd-bucket"

  tags = {
    Name = "FBucket"
  }
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = { 
    Name = "fp-vpc"
  }
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "my-fp-igw"
  }
}

# public subnet - AZ-a
resource "aws_subnet" "public_subnet_a" {
  vpc_id = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-a"
  }
}

# public subnet - AZ-b
resource "aws_subnet" "public_subnet_b" {
  vpc_id = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-b"
  }
}

# private subnet-AZ-a
resource "aws_subnet" "private_subnet_a" {
  vpc_id = aws_vpc.my_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "private-subnet-a"
  }
}

#Private Subnet - AZ-b
resource "aws_subnet" "private_subnet_b" {
  vpc_id = aws_vpc.my_vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "private-subnet-b"
  }
}

resource "aws_eip" "nat_a" {
  vpc = true
  tags = {
    Name = "eip-nat-a"
  }
}

resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id = aws_subnet.public_subnet_a.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "public_rt"
  }
}

# route table with public subnet in AZ-a
resource "aws_route_table_association" "public_assoc_a" {
  subnet_id = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

# Associate public route table with public subnet in AZ-b
resource "aws_route_table_association" "public_assoc_b" {
  subnet_id = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

# Create a route to the internet gateway
resource "aws_route" "internet_gateway_route" {
  route_table_id            = aws_route_table.public_rt.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.my_igw.id
}

# Create private route table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "private_rt"
}
}

# Associate private route table with private subnet in AZ-b
resource "aws_route_table_association" "private_assoc_a" {
  subnet_id = aws_subnet.private_subnet_b.id
  route_table_id = aws_route_table.private_rt.id
}

# Associate private route table with private subnet in AZ-b
resource "aws_route_table_association" "private_assoc_b" {
  subnet_id = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.private_rt.id
}
# Associate private route table with NAT-gateway in AZ-b
# Create a route to the NAT gateway in the private route table
resource "aws_route" "private_nat_gateway_route" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_a.id
}

# Retrieve the IP address of the machine running Terraform
data "http" "icanhazip" {
  url = "http://ipv4.icanhazip.com/"
}

# Create security group for Bastion host
resource "aws_security_group" "bastion_sg" {
  name_prefix = "BastionSG"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.icanhazip.body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create security group for Private instances
resource "aws_security_group" "private_sg" {
  name_prefix = "PrivateSG"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    
    self = true

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create security group for Public Web
resource "aws_security_group" "public_web_sg" {
  name_prefix = "PublicWebSG"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.icanhazip.body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
/*
# Create key pair
resource "aws_key_pair" "ssh_key" {
  key_name   = "final_project"
  public_key = file("~/.ssh/id_rsa.pub")
}
*/
# Create instances
resource "aws_instance" "bastion" {
  ami           = "ami-0aa2b7722dc1b5612" # Ubuntu 20.04 LTS official AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet_a.id

  key_name      = "final_project1"
  vpc_security_group_ids = ["${aws_security_group.bastion_sg.id}"]
  tags = {
    Name = "ec2-bastion"
  }
}

resource "aws_instance" "jenkins" {
  ami           = "ami-0aa2b7722dc1b5612" # Ubuntu 20.04 LTS official AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnet_a.id
  key_name      = "final_project1"
  vpc_security_group_ids = ["${aws_security_group.private_sg.id}"]
  tags = {
    Name = "ec2-jenkins"
  }
}

resource "aws_instance" "app" {
  ami           = "ami-0aa2b7722dc1b5612" # Ubuntu 20.04 LTS official AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnet_a.id

  key_name      = "final_project1"
  vpc_security_group_ids = ["${aws_security_group.private_sg.id}"]
  tags = {
    Name = "ec2-app"
  }
}

/*
# Create ssh config file for ProxyJump
locals {
  ssh_config = <<-EOF
    Host bastion
      Hostname ${aws_instance.bastion.public_ip}
      User ubuntu
      IdentityFile file("~/.ssh/id_rsa")

    Host jenkins
      Hostname ${aws_instance.jenkins.private_ip}
      User ubuntu
      IdentityFile file("~/.ssh/id_rsa")
      ProxyJump bastion
    Host app
      Hostname ${aws_instance.app.private_ip}
      User ubuntu
      IdentityFile file("~/.ssh/id_rsa")
      ProxyJump bastion
  EOF
}

# Write ssh config file
resource "local_file" "ssh_config" {
  filename = "~/.ssh/config"
  content  = "${local.ssh_config}"
}

resource "aws_lb" "my_alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.private_sg.id}"]
  subnets            = ["aws_subnet.public_subnet_a.id"]

  tags = {
    Name = "my-alb"
  }
}

resource "aws_lb_listener" "jenkins_listener" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins_target_group.arn
  }
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_group.arn
  }
}

resource "aws_lb_target_group" "jenkins_target_group" {
  name     = "jenkins-target-group"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id

  health_check {
    path = "/"
  }
}

resource "aws_lb_target_group" "app_target_group" {
  name     = "app-target-group"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id

  health_check {
    path = "/"
  }
}

resource "aws_lb_target_group_attachment" "jenkins_target_group_attachment" {
  target_group_arn = aws_lb_target_group.jenkins_target_group.arn
  target_id        = "i-06f7163b19c22ed0f"
  port             = 8080
}

resource "aws_lb_target_group_attachment" "app_target_group_attachment" {
  target_group_arn = aws_lb_target_group.app_target_group.arn
  target_id        = "i-018069e5937032d18"
  port             = 8080
}
*/
