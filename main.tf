provider "google" {
  credentials = file("developer-706a111207f1.json")
  project     = "developer-111120"
  region      = "asia-southeast1"
}
provider "aws" {
  region = "ap-south-1"
  profile = "eks"
  alias = "sonu"

}
##############################################################
resource "google_compute_subnetwork" "network-with-private-secondary-ip-ranges" {
  name          = "lab1"
  ip_cidr_range = "10.0.2.0/24"
  region        = "asia-southeast1"
  network       = google_compute_network.custom-test.id
 }

resource "google_compute_network" "custom-test" {
  name                    = "dev-vpc"
  auto_create_subnetworks = false
}

resource "google_container_cluster" "primary" {
  location = "asia-southeast1"
  name   = "gaurav-sonu"
  initial_node_count = 1
  project = "${var.project_name}"
  network = google_compute_network.custom-test.id
  subnetwork = "lab1"
  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }
  node_config {
    disk_size_gb = "${var.nodes_disk_size}"
    machine_type = "${var.machine_type_k8s_nodes}"
    
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
    timeouts {
    create = "30m"
    update = "40m"
  }
}
#########################################################

resource "aws_vpc" "main" {
  provider = aws.sonu
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "sonu-vpc"
  }
}

resource "aws_subnet" "subnet-1" {
  provider = aws.sonu
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "public-sonu-vpc-subnet"
  }
}
resource "aws_subnet" "subnet-2" {
  provider = aws.sonu
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "public-sonu-vpc-subnet"
  }
}


######### public SG
resource "aws_security_group" "allow_tls" {
  provider = aws.sonu
  name        = "public_sonu_vpc"
  description = "ssh,MySQL"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    description = "MySQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
    description = "ssh"
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
    Name = "public_sonu_vpc_SG"
  }
}

##### Internet Gateways
resource "aws_internet_gateway" "gw" {
  provider = aws.sonu
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "sonu-vpc-gateways"
  }
}
##### routing tables #######
resource "aws_route_table" "r" {
  provider = aws.sonu
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

   tags = {
    Name = "public_routing_tables"
  }
  depends_on = [
    aws_internet_gateway.gw
  ]
}

######## subnet association###
resource "aws_route_table_association" "a" {
  provider = aws.sonu
  subnet_id      = "${aws_subnet.subnet-1.id}"
  route_table_id = "${aws_route_table.r.id}"
  
  depends_on = [
    aws_subnet.subnet-1
       
  ]
}

resource "aws_route_table_association" "b" {
  provider = aws.sonu
  subnet_id      = "${aws_subnet.subnet-2.id}"
  route_table_id = "${aws_route_table.r.id}"
  
  depends_on = [
    aws_subnet.subnet-2
       
  ]

}
######################################## 

resource "aws_db_subnet_group" "mariadb-subnet" {
provider = aws.sonu
name = "mariadb-subnet"
description = "RDS subnet group"
subnet_ids = ["${aws_subnet.subnet-1.id}","${aws_subnet.subnet-2.id}"]
}

resource "aws_db_instance" "default" {
  allocated_storage    = 5
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "db_gcp"
  username             = "root"
  password             = "Redhat2019"
  parameter_group_name = "default.mysql5.7"
  db_subnet_group_name = "${aws_db_subnet_group.mariadb-subnet.name}"
  vpc_security_group_ids = ["${aws_security_group.allow_tls.id}"]
  publicly_accessible  = true
  provider = aws.sonu
  depends_on = [
    aws_security_group.allow_tls
  ]
}