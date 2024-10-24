
provider "aws" {
 region = "us-east-1"
}

resource "aws_security_group" "instance1" {
    name = "instance1_SG"

    ingress {
        from_port = "8080"
        to_port = "8080"
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "AWS Security Group"
    }
    
}

resource "aws_instance" "instance1" {
  ami = "ami-06b21ccaeff8cd686"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance1.id]
  
  tags =  {
    Name = "TestInstance"
  }
}

output "publicip" {
    value = "aws_instance.instance1.public_ip"
}



