resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.app}-vpc"
  }
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id = aws_vpc.vpc.id
  cidr_block = each.key
  availability_zone = each.value
  tags = {
    Name = "${var.app}-private"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id = aws_vpc.vpc.id
  cidr_block = each.key
  availability_zone = each.value
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.app}-public"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.app}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.app}-routing-table-public"
  }
}

resource "aws_route" "public" {
  route_table_id = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  for_each = var.public_subnets

  subnet_id = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  for_each = var.private_subnets

  tags = {
    Name = "${var.app}-nat-eip"
    subnet = each.key
  }
  vpc = true
  depends_on = [
    aws_internet_gateway.main
  ]
}

resource "aws_nat_gateway" "nat" {
  for_each = var.private_subnets

  allocation_id = aws_eip.nat[each.key].id
  subnet_id = aws_subnet.public[var.private_subnet_nat_map[each.key]].id

  tags = {
    Name = "${var.app}-nat-gw"
    subnet = each.key
  }
}

resource "aws_route_table" "private" {
  for_each = var.private_subnets

  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.app}-routing-table-private"
    subnet = each.key
  }
}

resource "aws_route" "private" {
  for_each = var.private_subnets

  route_table_id = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat[each.key].id
}

resource "aws_route_table_association" "private" {
  for_each = var.private_subnets

  subnet_id = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

output "vpc_id" {
  value = aws_vpc.vpc.id
}
