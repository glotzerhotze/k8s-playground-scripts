#!/usr/bin/env bash

# setup for latest ubuntu-lts-release aka. jammy
export VMNAME="Ubuntu-2204-jammy"
export ISOURL="https://releases.ubuntu.com/22.04.3/"
export ISONAME="ubuntu-22.04.3-live-server-amd64.iso"

## currently broken on MacOS virtualbox-7.0.12
## lunar
#export VMNAME="Ubuntu-2304-lunar"
#export ISOURL="https://releases.ubuntu.com/lunar/"
#export ISONAME="ubuntu-23.04-live-server-amd64.iso"
## mantic
#export VMNAME="Ubuntu-2310-mantic"
#export ISOURL="https://releases.ubuntu.com/mantic/"
#export ISONAME="ubuntu-23.10-live-server-amd64.iso"

export OSTYPE="Ubuntu_64"
export ISOPATH="${HOME}/Downloads"
export FORMAT="VDI"
export RAM=8192
export VRAM=16
export CPUCOUNT=1
export VMPATH="${HOME}/virtual-machines"

echo "checking if the virtual machines folder exists"
if [ -e "${VMPATH}" ]; then
  echo "${VMPATH} folder already exists"
else
  mkdir -p ${VMPATH}
fi

echo "checking if a download of ${ISONAME} is needed"
if [ -e ${ISOPATH}/${ISONAME} ]; then
  echo "ISO file exists"
else
  echo "ISO file doesn't exist - downloading ${ISONAME} to ${ISOPATH}"
  curl -o ${ISOPATH}/${ISONAME} ${ISOURL}/${ISONAME}
fi

if not VBoxManage; then
	echo ""
	echo "VirtualBox is not installed, please download and install it"
	echo "https://www.virtualbox.org/wiki/Downloads"
	echo ""
fi

echo delete the old VM
VBoxManage controlvm "${VMNAME}" poweroff
VBoxManage unregistervm --delete "${VMNAME}"
rm -rf  "${VMPATH}/${VMNAME}"

echo create a new VM
VBoxManage createvm --name "${VMNAME}" --ostype "${OSTYPE}" --register
VBoxManage storagectl "${VMNAME}" --name "SATA" --add sata --controller IntelAHCI --portcount 4 --bootable on

echo "configure hardware settings"
VBoxManage modifyvm "${VMNAME}" --cpus "${CPUCOUNT}" --firmware efi --graphicscontroller vmsvga --pae off
VBoxManage modifyvm "${VMNAME}" --memory "${RAM}" --vram "${VRAM}"
VBoxManage modifyvm "${VMNAME}" --mouse ps2 --keyboard ps2 --audio-enabled off --clipboard-mode bidirectional --usb-ehci off --usb-ohci off --usb-xhci off

echo "modify networking to have NAT on enp0s3 and hostonly networking on enp0s8"
VBoxManage modifyvm "${VMNAME}" --nic1 nat --nictype1 virtio
VBoxManage modifyvm "${VMNAME}" --nic2 hostonlynet --nic-type2 virtio --host-only-net2 "HostNetwork"

echo "modify storage to mount root device, install ISO and VBoxGuest tools"
VBoxManage createmedium disk --filename "${VMPATH}/${VMNAME}/${VMNAME}" --size 65536 --format ${FORMAT} --variant Standard
VBoxManage storageattach "${VMNAME}" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "${VMPATH}/${VMNAME}/${VMNAME}.vdi"
VBoxManage storageattach "${VMNAME}" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium "${ISOPATH}/${ISONAME}"
VBoxManage storageattach "${VMNAME}" --storagectl "SATA" --port 2 --device 0 --type dvddrive --medium "autoinstall/seed.iso"
## TODO: get path for guest-additions and implement roll-out
#VBoxManage storageattach "${VMNAME}" --storagectl "SATA" --port 3 --device 0 --type dvddrive --medium "${VBOXGUEST}"

echo "start the configured VM"
VBoxManage startvm "${VMNAME}"
