data "aws_route_table" "kind" {
  vpc_id = aws_default_vpc.kind.id
}

resource aws_route "igw" {
  route_table_id = data.aws_route_table.kind.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.kind.id
}
