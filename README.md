# amzn2-lima

## Amazon Linux 2 virtual machine images building for Lima.

[Lima](https://github.com/lima-vm/lima) launches Linux Virtual Machines.

This repo contains the scripts and tools to build an ISO image for Lima to be used by [Amazon Linux 2 virtual machine images](https://cdn.amazonlinux.com/os-images/latest/).

## Architecture

This repo supports the amazon linux 2 images for different architectures. 
Only `x86_64` have been tested but other architectures can also be generated.

## Build the images.

Simply run build.sh to build the image.

```bash
bash build.sh
```

To invoke the image, simply pass the generated yaml as the argument to lima.
Select `> Proceed with the current configuration` and press Enter to start up.

```bash
❯ limactl start amzn2.yaml
? Creating an instance "amzn2"  [Use arrows to move, type to filter]
> Proceed with the current configuration
  Open an editor to review or modify the current configuration
  Choose another template (docker, podman, archlinux, fedora, ...)
  Exit
```

That's all.
