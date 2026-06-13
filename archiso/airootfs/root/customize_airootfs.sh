#!/usr/bin/env bash
#
# Runs once inside the live airootfs chroot during the ISO build (mkarchiso's
# _make_customize_airootfs hook) and is removed afterwards. Anything written
# here ends up in the squashed live root, which Calamares later uses as the
# base for the installed system.
#
# Builds MacBookPro13,2-specific out-of-tree kernel drivers against the
# linux-cachyos kernel that will ship on the ISO -- NOT the build host's
# kernel (uname -r inside this chroot is the CI runner's kernel).

set -e -u

# Find the kernel release that linux-cachyos-headers was installed for (the
# only /usr/lib/modules/* entry with a usable "build" tree).
KVER=""
for d in /usr/lib/modules/*; do
    if [[ -e "${d}/build" ]]; then
        KVER="$(basename "${d}")"
        break
    fi
done
if [[ -z "${KVER}" ]]; then
    echo "customize_airootfs: no kernel with headers found under /usr/lib/modules, aborting" >&2
    exit 1
fi
KDIR="/usr/lib/modules/${KVER}/build"
echo "==> Building MacBook drivers for kernel ${KVER}"

#### Touch Bar / iBridge (T1) driver ########################################

src=/usr/src/mbp-t1-touchbar-driver
git clone --depth 1 https://github.com/parport0/mbp-t1-touchbar-driver "${src}"

make -C "${KDIR}" M="${src}" modules
make -C "${KDIR}" M="${src}" INSTALL_MOD_PATH=/ modules_install
depmod "${KVER}"

# apple-ibridge-hid / apple-ib-touchbar (mainline) conflict with the
# apple-ibridge / apple-ib-tb modules above; let usbhid hand the iBridge
# device off to our driver instead.
install -Dm644 /dev/stdin /etc/modprobe.d/ibridge.conf <<'EOF'
blacklist apple-ibridge-hid
blacklist apple-ib-touchbar
options usbhid ignore_special_drivers=1 quirks=0x05ac:0x8600:0x4
EOF

# Load the Touch Bar driver and rebind the iBridge USB device (also exposes
# the FaceTime camera) at boot.
install -Dm644 /dev/stdin /etc/systemd/system/apple-ibridge.service <<'EOF'
[Unit]
Description=Activate Apple iBridge driver (Touch Bar + FaceTime camera)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/modprobe apple-ib-tb idle_timeout=-1 dim_timeout=-1 fnmode=2
ExecStart=/usr/bin/bash -c 'echo -n "1-3" > /sys/bus/usb/drivers/usb/unbind'
ExecStart=/usr/bin/bash -c 'echo -n "1-3" > /sys/bus/usb/drivers_probe'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl enable apple-ibridge.service

# This driver is a plain out-of-tree module (not DKMS), so on this rolling
# release it needs rebuilding whenever linux-cachyos / linux-cachyos-headers
# is updated. Re-run the same build via a pacman hook.
install -Dm755 /dev/stdin /usr/local/bin/rebuild-mbp-touchbar.sh <<'EOF'
#!/usr/bin/env bash
set -e -u

KVER=""
for d in /usr/lib/modules/*; do
    if [[ -e "${d}/build" ]]; then
        KVER="$(basename "${d}")"
        break
    fi
done
if [[ -z "${KVER}" ]]; then
    echo "rebuild-mbp-touchbar: no kernel with headers found under /usr/lib/modules" >&2
    exit 1
fi
KDIR="/usr/lib/modules/${KVER}/build"

src=/usr/src/mbp-t1-touchbar-driver
make -C "${KDIR}" M="${src}" clean
make -C "${KDIR}" M="${src}" modules
make -C "${KDIR}" M="${src}" INSTALL_MOD_PATH=/ modules_install
depmod "${KVER}"
EOF

install -Dm644 /dev/stdin /etc/pacman.d/hooks/91-mbp-touchbar-rebuild.hook <<'EOF'
[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Target = linux-cachyos
Target = linux-cachyos-headers

[Action]
Description = Rebuilding MacBookPro13,2 Touch Bar driver for new kernel...
When = PostTransaction
Exec = /usr/local/bin/rebuild-mbp-touchbar.sh
NeedsTargets
EOF
