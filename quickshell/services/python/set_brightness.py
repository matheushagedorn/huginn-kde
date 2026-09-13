#!/usr/bin/env python3
"""Sets one monitor's brightness over DDC/CI, as a one-shot.

`ddcutil setvcp` costs ~300ms on this hardware, and only 4ms of that is process
startup: the rest is its conservative DDC/CI pacing. The write itself is a
single I2C transaction, so doing it directly gets the same result in a fraction
of the time. Falls back to ddcutil when /dev/i2c-N is not reachable.
"""
import fcntl
import os
import subprocess
import sys

I2C_SLAVE = 0x0703
DDC_ADDR = 0x37
VCP_BRIGHTNESS = 0x10


def main():
    if len(sys.argv) != 3:
        return 2
    bus, percent = sys.argv[1], max(0, min(100, int(sys.argv[2])))

    payload = bytearray([0x51, 0x84, 0x03, VCP_BRIGHTNESS,
                         (percent >> 8) & 0xFF, percent & 0xFF])
    checksum = 0x6E
    for byte in payload:
        checksum ^= byte
    payload.append(checksum)

    try:
        fd = os.open(f'/dev/i2c-{bus}', os.O_RDWR)
        try:
            fcntl.ioctl(fd, I2C_SLAVE, DDC_ADDR)
            os.write(fd, payload)
        finally:
            os.close(fd)
        return 0
    except Exception:
        pass

    try:
        subprocess.run(['ddcutil', 'setvcp', '10', str(percent),
                        '--bus', str(bus), '--noverify'],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       timeout=3.0)
        return 0
    except Exception:
        return 1


if __name__ == '__main__':
    sys.exit(main())
