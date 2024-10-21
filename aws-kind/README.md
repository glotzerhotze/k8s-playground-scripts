# AWS KIND setup

If you `terraform apply` these scripts, you will get a VM in AWS running a kind-cluster using cilium.

This is the deprecated version of this setup, as we still rely on `metalLB` and `kuberouter` to make direct-routing via cilium possible.

Since cilium now allows to run this mode without metalLB and kuberouter - this setup is just for educational purposes and should not be used.

## How to use

Run the terraform scripts, wait for the machine to provision.

Once you get the public IP, ssh to the machine like that:

```bash
ssh ubuntu@your.public.ip.address
```