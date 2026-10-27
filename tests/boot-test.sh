#!/usr/bin/env bash
# Boot the ISO in QEMU (UEFI) and wait for the live desktop: the serial
# console must show the Foxtail session starting and the shell loading its
# configuration. Saves the serial log and a screenshot to tests/out/.
#   tests/boot-test.sh out/foxtail-*.iso [timeout-seconds]
set -uo pipefail
ISO=${1:?usage: boot-test.sh <iso> [timeout]}
TIMEOUT=${2:-600}
cd "$(dirname "$0")"
mkdir -p out
OVMF=$(ls /usr/share/OVMF/OVMF_CODE*.fd /usr/share/edk2/x64/OVMF_CODE*.fd /usr/share/ovmf/x64/OVMF_CODE.fd 2>/dev/null | head -1)
[ -n "$OVMF" ] || { echo "OVMF (UEFI firmware) not found"; exit 1; }
KVM=""; [ -w /dev/kvm ] && KVM="-enable-kvm -cpu host"

rm -f out/serial.log
qemu-system-x86_64 $KVM -m 4096 -smp 2 -machine q35 \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF" \
    -cdrom "$ISO" -boot d -vga virtio -display none \
    -serial file:out/serial.log -monitor unix:out/monitor.sock,server,nowait \
    -no-reboot &
QEMU=$!
trap 'kill $QEMU 2>/dev/null' EXIT

# The live ISO logs these to the serial console (see archiso/airootfs:
# foxtail-boot-report.service).
ok=0
for _ in $(seq "$TIMEOUT"); do
    if grep -q "FOXTAIL-BOOT: shell ready" out/serial.log 2>/dev/null; then ok=1; break; fi
    if grep -qE "Kernel panic|FOXTAIL-BOOT: failed" out/serial.log 2>/dev/null; then break; fi
    kill -0 $QEMU 2>/dev/null || break
    sleep 1
done
echo "screendump out/screen.ppm" | socat - UNIX-CONNECT:out/monitor.sock >/dev/null 2>&1 \
    && command -v convert >/dev/null && convert out/screen.ppm out/screen.png
grep "FOXTAIL-BOOT" out/serial.log
if [ $ok = 1 ]; then echo "PASS: the live desktop started"; exit 0; fi
echo "FAIL: the desktop didn't start within ${TIMEOUT}s (see tests/out/serial.log)"
exit 1
