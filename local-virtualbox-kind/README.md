# local-virtualbox-kind

## overview
this is a **Windows-11** setup - running inside a virtualbox and utilizing two network interfaces - one for internet access (NAT) and one for host-access (Host-Only Interface)

once the VM is created, the `autoinstall/kind.sh` will be run. this will create a `kind` cluster utilizing cilium in `direct-routing` mode.

you can check the progress of the script by looking at `/var/log/cloud-init-output.log` like so - once the machine is up and you're connected:

```bash
tail -f /var/log/cloud-init-output.log
```

connecting to the machine should be possible via the `Host Only Network` interface - the setup assumes the VM to be at `192.168.56.10` - so using the user **virtualbox** with a password of **virtualbox** should allow to connect to the machine:

```bash
ssh virtualbox@192.168.56.10
```

since this machine is setup with **hard-disk encryption** via LUKS - you need to unlock the VM each time you restart it with the encryption password **virtualbox**

## prerequisites

* you need the latest virtualbox installed with default settings - aka. make sure the host-only network is 192.168.56.0/24
* you need WSL debian / ubuntu if you want to re-generate the autoinstall files

## running the setup

you would open a windows CMD.exe terminal and run `create_ubuntu_vm.cmd`

this will configure a virtualbox virtual machine, download the Ubuntu ISO image needed (on first run only) and bootstrap a machine with it.

please follow the on-screen menus - as you have to interact twice with the machine (choose install in grub menu and type "yes" upon installation)

since we use a poor-mans approach to automating this setup, manual intervention is preferred here as other solutions would involve re-building the ISO image. see below sources for more information.

## how to re-build configuration of ubuntu-autoinstaller
* [ubuntu-22.04 - autoinstall explained](https://www.jimangel.io/posts/automate-ubuntu-22-04-lts-bare-metal/) - you will find how to re-generate `seed.iso` at the end of this link
* how to re-generate the seed.iso file:

```bash
apt-get install genisoimage
genisoimage -output seed.iso -volid cidata -joliet -rock user-data meta-data
```

* if you want to alter the installation of the kind-cluster, you can manipulate the `autoinstall/kind.sh` file - but make sure you base64 encode the content of the script and add it to `autoinstall/user-data` and re-generate the `seed.iso` file to make your changes getting rolled out via bringing up the VM