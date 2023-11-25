output "ip" {
  value = aws_instance.kind.public_ip
}

output "dns" {
  value = aws_instance.kind.public_dns
}
