These are the basic needed files and folders to build CachyOS system.

### buildiso

buildiso is used to build CachyOS ISO.

#### Arguments

~~~
$ ./buildiso.sh -h
Usage: buildiso [options]
    -c                 Disable clean work dir
    -r                 Disable building in RAM on systems with more than 23GB RAM
    -w                 Remove build directory (not the ISO) after ISO file is built
    -h                 This help
    -p <profile>       Buildset or profile [default: desktop]
    -v                 Verbose output to log file, show profile detail (-q)
~~~

* Uses the same signature that normal repo and has no mirrors package to install.

```bash
sudo pacman -Syy
```

### Install necessary packages:
```bash
sudo pacman -S archiso mkinitcpio-archiso git squashfs-tools grub --needed
```

### Clone:
```bash
git clone https://github.com/cachyos/cachyos-live-iso.git cachyos-archiso
cd cachyos-archiso
```

### Build
```bash
sudo ./buildiso.sh -p desktop -v -w
```

As the result iso appears at the `out` folder

## MacBookPro13,2 (2016 13" Touch Bar) fork

This fork adds MacBookPro13,2-specific hardware support, built into the ISO so
both the live environment and the installed system work out of the box:

- **WiFi (BCM43602)**: `brcmfmac` with `feature_disable=0x82000`, `iwd` as the
  NetworkManager backend, US regulatory domain.
- **Touch Bar / iBridge (T1)**: `parport0/mbp-t1-touchbar-driver`, built against
  `linux-cachyos` and loaded at boot (also enables the FaceTime camera). Rebuilt
  automatically via a pacman hook on kernel upgrades.
- **Audio (Cirrus CS8409/CS42L83 codec)**: `davidjo/snd_hda_macbookpro` patch to
  the in-kernel `snd-hda-codec-cs8409` driver, installed via DKMS (auto-rebuilds
  on kernel upgrades).

All of the above is built from source inside `archiso/airootfs/root/customize_airootfs.sh`
during the ISO build (see `.github/workflows/build.yml`, runnable on demand via
`workflow_dispatch`).

**Not covered** (no good upstream Linux fix exists for this model): Touch ID,
hibernation, and fine-grained suspend/wake tuning. Standard `s2idle` suspend
works but battery drain during sleep may be higher than on macOS.
