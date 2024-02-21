#!/usr/bin/env bash

# grobal definition.
base_url="https://cdn.amazonlinux.com/os-images"
release="$(curl -D - -s  -o /dev/null "${base_url}/latest/" | grep location | awk -F/ '{print $(NF-1)}')"
qcow2_name="$(curl -s ${base_url}/${release}/kvm/SHA256SUMS|awk '{print $2}')"
qcow2_digest="$(curl -s ${base_url}/${release}/kvm/SHA256SUMS|awk '{print $1}')"
kvm_url="${base_url}/${release}/kvm/${qcow2_name}"
public_key="$(cat ~/.lima/_config/user.pub)"
fuse_sshfs="https://kojipkgs.fedoraproject.org//packages/fuse-sshfs/2.10/1.el7/x86_64/fuse-sshfs-2.10-1.el7.x86_64.rpm"

# get qcow2 image binary.
[[ -f "./${qcow2_name}" ]] || wget "${kvm_url}"

# generate meta-date
install -d cidata
echo "local-hostname: localhost.localdomain" >> cidata/meta-data

# generate cloud-init user-data file.
cat << __EOF__ > cidata/user-data
#cloud-config
# vim:syntax=yaml

growpart:
  mode: auto
  devices: ['/']

users:
# A user by the name ec2-user is created in the image by default.
# add lima user.
  - default
  - name: ${whoami}
    groups: wheel
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    plain_text_passwd: lima
    ssh-authorized-keys:
      - "${public_key}"
    lock_passwd: false

chpasswd:
  list: |
    root:lima
    $(whoami):lima
  expire: False

write_files:
 - content: |
      #!/bin/sh
      set -eux
      LIMA_CIDATA_MNT="/mnt/lima-cidata"
      LIMA_CIDATA_DEV="/dev/disk/by-label/cidata"
      mkdir -p -m 700 "${LIMA_CIDATA_MNT}"
      mount -o ro,mode=0700,dmode=0700,overriderockperm,exec,uid=0 "${LIMA_CIDATA_DEV}" "${LIMA_CIDATA_MNT}"
      export LIMA_CIDATA_MNT
      exec "${LIMA_CIDATA_MNT}"/boot.sh
   owner: root:root
   path: /var/lib/cloud/scripts/per-boot/00-lima.boot.sh
   permissions: '0755'

# This has no effect on systems using systemd-resolved, but is used
# on e.g. Alpine to set up /etc/resolv.conf on first boot.
manage_resolv_conf: true

resolv_conf:
  nameservers:
  - 1.1.1.1

ca-certs:
  remove_defaults: false
  trusted:

# Disable root password reset process at startup by cloud-init
runcmd:
  - yum -y update
  - yum -y install ${fuse_sshfs}
  - yum clean all
  - find /var/log -type f -exec cp -f /dev/null {} \;
  - rm -rf /tmp/*
  - rm -rf /etc/udev/rules.d/70-presistent-net.rules
  - rm -rf /root/.bash_history
  - history -c
  - export HISTSIZE=0
  - eject --cdrom
  - poweroff
__EOF__

# generate cidata iso images.
[[ -f "./cidata.iso" ]] && rm cidata.iso
mkisofs -output cidata.iso -volid cidata -joliet -rock cidata

# CreateVM and Starting for Amazon Linux 2.
vm_name="amznlinux-${release}"
qemu-system-x86_64 \
  -name "${vm_name}" \
  -machine q35 \
  -cpu max \
  -m 8G \
  -vga virtio \
  -boot menu=on \
  -cdrom cidata.iso \
  -drive file=${qcow2_name},format=qcow2,if=virtio \
  -net nic,model=virtio \
  -net user,hostfwd=tcp::2222-:22

# generate lima configuration yaml file.
cat << __EOF__ > amzn2.yaml
# This template requires Lima v0.7.0 or later.
vmType: "qemu"
arch: "x86_64"
cpus: 2
memory: "8Gib"
images:
  - location: "$(pwd)/${qcow2_name}"
    arch: "x86_64"
    digest: "sha256:$(sha256sum ${qcow2_name}|awk '{print $1}')"
mounts:
  - location: "~"
  - location: "/tmp/lima"
    writable: true
containerd:
  system: false
  user: false
firmware:
  legacyBIOS: true
cpuType:
  # Workaround for "vmx_write_mem:" mmu_gva_to_qpa XXXXXXXXXXXXXXXX failed" on Intel Mac
  # https://bugs.launchpad.net/qemu/+bug/1838390
  x86_64: "Haswell-v4"
__EOF__
