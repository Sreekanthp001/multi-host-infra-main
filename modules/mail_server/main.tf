resource "aws_security_group" "mail_server" {
  name        = "${var.project_name}-mail-sg"
  description = "Security group for Business Mail Server"
  vpc_id      = var.vpc_id

  # SMTP
  ingress {
    from_port   = 25
    to_port     = 25
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Submission (SMTP over TLS)
  ingress {
    from_port   = 587
    to_port     = 587
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # IMAPS
  ingress {
    from_port   = 993
    to_port     = 993
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Should be restricted in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_eip" "mail_server" {
  domain = "vpc"
  tags = {
    Name = "${var.project_name}-mail-server-eip"
  }
}

resource "aws_instance" "mail_server" {
  ami                    = var.ami_id
  instance_type          = "t3.medium"
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.mail_server.id]
  key_name               = var.key_name

  tags = {
    Name = "${var.project_name}-mail-server"
  }
}

resource "aws_eip_association" "mail_server" {
  instance_id   = aws_instance.mail_server.id
  allocation_id = aws_eip.mail_server.id
}
