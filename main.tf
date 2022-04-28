resource "aws_vpc" "fcc_main" {
  cidr_block           = "10.3.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "fcc-tf"
  }
}

resource "aws_subnet" "fcc_public_subnet" {
  vpc_id                  = aws_vpc.fcc_main.id
  cidr_block              = "10.3.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1a"

  tags = {
    Name = "fcc-public-subnet"
  }
}

resource "aws_internet_gateway" "fcc_igw" {
  vpc_id = aws_vpc.fcc_main.id

  tags = {
    Name = "fcc IGW"
  }
}

resource "aws_route_table" "fcc_pub_route" {
  vpc_id = aws_vpc.fcc_main.id

  #Route for IGW
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.fcc_igw.id
  }

  tags = {
    Name = "fcc public route table"
  }
}

resource "aws_route_table_association" "fcc_rt_association" {
  subnet_id      = aws_subnet.fcc_public_subnet.id
  route_table_id = aws_route_table.fcc_pub_route.id
}


resource "aws_security_group" "fcc_vpc_sg" {
  name        = "fcc_sg"
  description = "Security group created for fcc project"
  vpc_id      = aws_vpc.fcc_main.id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]

  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "fcc_sg"
  }
}

resource "aws_key_pair" "fcc_auth" {
  key_name   = "fcc_key_pair"
  public_key = file("~/.ssh/fcc_key_pair.pub")
}

resource "aws_instance" "fcc_instance" {
  ami                    = data.aws_ami.server_ami.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.fcc_auth.id
  vpc_security_group_ids = [aws_security_group.fcc_vpc_sg.id]
  subnet_id              = aws_subnet.fcc_public_subnet.id
  user_data              = file("userdata.tpl")
  root_block_device {
    volume_size = 10
  }

  tags = {
    "Name" = "fcc_instance"
  }

  provisioner "local-exec" {
    command = templatefile("windows-ssh-config.tpl", {
      hostname     = self.public_ip,
      user         = "ubuntu",
      identityfile = "~/.ssh/fcc_key_pair"
    })
    interpreter = [
      "Powershell",
      "-Command"
    ]
  }

}
