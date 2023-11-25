resource "aws_instance" "kind" {

  ami                         = var.ami
  associate_public_ip_address = true
  availability_zone           = aws_subnet.public.availability_zone
  cpu_core_count              = 2
  cpu_threads_per_core        = 2

  credit_specification {
    cpu_credits = "unlimited"
  }

  disable_api_stop        = false
  disable_api_termination = false
  ebs_optimized           = true

  enclave_options {
    enabled = false
  }

  get_password_data                    = false
  hibernation                          = false
  iam_instance_profile                 = ""
  instance_initiated_shutdown_behavior = "stop"
  instance_type                        = var.instance_type
  ipv6_address_count                   = 1
  key_name                             = aws_key_pair.kind.key_name

  maintenance_options {
    auto_recovery = "default"
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "optional"
    instance_metadata_tags      = "enabled"
  }

  private_dns_name_options {
    enable_resource_name_dns_a_record    = true
    enable_resource_name_dns_aaaa_record = true
  }

  root_block_device {
    delete_on_termination = true
    encrypted             = false
    iops                  = 3000
    kms_key_id            = ""
    tags                  = {}
    throughput            = 125
    volume_size           = 64
    volume_type           = "gp3"
  }

  security_groups   = []
  source_dest_check = false
  subnet_id         = aws_subnet.public.id

  tags = {
    Name = "kind"
  }

  tags_all = {
    Name = "kind"
  }

  provisioner "file" {
    source      = "user-data/kind/kind-cluster.yaml"
    destination = "/home/ubuntu/kind-cluster.yaml"

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "ssh"
      user = "ubuntu"
    }
  }

  provisioner "file" {
    content = templatefile("${path.module}/user-data/startup.sh.tftpl",
      {
        ssh-key       = file("~/.ssh/id_rsa")
        dollar        = "$"
      }
    )
    destination = "/home/ubuntu/startup.sh"

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "ssh"
      user = "ubuntu"
    }
  }

  provisioner "file" {
    source      = "user-data/cilium/cilium-1.12.0-direct-routing-kind.yaml"
    destination = "/home/ubuntu/cilium-1.12.0-direct-routing.yaml"

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "ssh"
      user = "ubuntu"
    }
  }

  provisioner "file" {
    source      = "user-data/metallb/metallb-native.yaml"
    destination = "/home/ubuntu/metallb-native.yaml"

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "ssh"
      user = "ubuntu"
    }
  }

  provisioner "file" {
    source      = "user-data/metallb/metallb.pool.yaml"
    destination = "/home/ubuntu/metallb.pool.yaml"

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "ssh"
      user = "ubuntu"
    }
  }

  provisioner "file" {
    source      = "user-data/metallb/metallb.bgppeer.yaml"
    destination = "/home/ubuntu/metallb.bgppeer.yaml"

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "ssh"
      user = "ubuntu"
    }
  }

  provisioner "file" {
    source      = "user-data/metallb/metallb.bgpadvertisement.yaml"
    destination = "/home/ubuntu/metallb.bgpadvertisement.yaml"

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "ssh"
      user = "ubuntu"
    }
  }

  provisioner "file" {
    source      = "user-data/metallb/metallb.l2advertisement.yaml"
    destination = "/home/ubuntu/metallb.l2advertisement.yaml"

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "ssh"
      user = "ubuntu"
    }
  }

  provisioner "file" {
    source      = "user-data/kube-router/generic-kuberouter-only-advertise-routes.yaml"
    destination = "/home/ubuntu/generic-kuberouter-only-advertise-routes.yaml"

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "ssh"
      user = "ubuntu"
    }
  }

  provisioner "file" {
    source      = "user-data/frr/frr.conf"
    destination = "/home/ubuntu/frr.conf"

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "ssh"
      user = "ubuntu"
    }
  }

  provisioner "file" {
    source      = "user-data/frr/daemons"
    destination = "/home/ubuntu/daemons"

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "ssh"
      user = "ubuntu"
    }
  }

  lifecycle {
    ignore_changes = [
      user_data,
      key_name
    ]
  }

  tenancy                     = "default"
  user_data                   = file("./user-data/user-data.sh")
  user_data_replace_on_change = false
  vpc_security_group_ids      = [ aws_default_security_group.default.id ]
}
