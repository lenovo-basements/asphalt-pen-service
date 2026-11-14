# asphalt-pen-service

Active pen support for the Lenovo Legion Y700 Gen 2 (TB320FC, "asphalt") on
mainline Linux.

The pen is drawn on the NT36523N touch and display chip itself: position,
pressure, tilt, hover and the two barrel buttons arrive with the finger
reports and come out of the kernel as the `Novatek NT36523N Pen` input
device. The firmware only looks for the pen in **pen mode**, though, and
stock Android turns that on only while its Bluetooth pen is connected. This
repo puts that policy in userspace:

```
asphalt-pen status          what the touchscreen, config and pens say
asphalt-pen sync            apply /etc/asphalt-pen.conf (udev runs this)
asphalt-pen force on|off    set pen mode now, until the next sync
```

There is no daemon. udev runs `sync` when a Bluetooth input device appears
or goes away, and when the touch driver binds. The kernel keeps the mode
across panel power cycles and firmware reloads.

## Needs

A kernel whose `novatek-nt36523n` driver has the `pen_mode` / `pen_battery`
attributes, and a DT with `novatek,pen-support` plus `touchscreen-x-mm` /
`touchscreen-y-mm`. Without the size, libinput treats the pen as a plain
touch device instead of a tablet tool (no pressure, tilt or hover).

```
/sys/bus/spi/drivers/novatek-nt36523n/spi0.0/pen_mode      rw  0/1 (firmware cmd 0x7b)
/sys/bus/spi/drivers/novatek-nt36523n/spi0.0/pen_battery   ro  battery byte of the last pen report, -1 before one
```

`novatek_nt36523n.pen_enabled=` only sets the mode at boot now.

## Install

```
make check
sudo make install                                   # /usr, /usr/lib/udev/rules.d
sudo make install PREFIX=/usr/local UDEVDIR=/etc/udev/rules.d
sudo udevadm control --reload
```

An existing `/etc/asphalt-pen.conf` is never overwritten.

## Config

| key | default | meaning |
|---|---|---|
| `MODE` | `auto` | `auto`: pen mode while a matching Bluetooth pen is connected. `on`: always (pen without Bluetooth). `off`: never |
| `PENS` | `"*pen*"` | case-insensitive globs on the Bluetooth input device name |
| `HAPTIC` | `toggle` | y700-hapticd effect when pen mode turns on, empty for none |

## First pen checklist (AP500U or AP501U)

1. Kernel: `asphalt-pen status` lists `spi0.0`, and `libinput list-devices`
   shows the pen with `Capabilities: tablet`.
2. Pair it (`bluetoothctl`), then check `asphalt-pen status` shows its name
   under `pens:` and pen mode follows connect and disconnect. If the pen
   has no Bluetooth, use `MODE=on`.
3. `sudo evtest /dev/input/event5` (the Pen device):
   - X/Y track the tip in all four corners;
   - pressure goes 0 to 4095;
   - tilt sign: which way is +X?
   - hover (`BTN_TOOL_PEN` with `ABS_DISTANCE` 1);
   - the two buttons.
4. `cat .../pen_battery` against the pen's real charge: is byte 77 really a
   percentage?
5. Firmware pen-state frames: with pen mode off, does the firmware notice a
   pen by itself? If so, auto mode could work without Bluetooth.
   ```
   echo 'file novatek-nt36523n.c +p' | sudo tee /sys/kernel/debug/dynamic_debug/control
   journalctl -kf | grep 'Stylus state'
   ```
6. Palm rejection: libinput should mute the touchscreen while the pen is in
   range, since both are on the same device.
7. Rotation: with Hyprland's `input:tablet:output = DSI-1`, does the pen
   follow the output transform?
8. Power: pen mode on vs off at idle (|I|×V, 40 s windows).
9. Bluetooth extras: button keycodes from the pen's HID device, and whether
   BlueZ shows its battery (`upower -d`).

## Ground truth from stock ZUI

Before tuning, record what Lenovo's own stack does with the same pen
(restore ZUI with QFIL, enable USB debugging, root not needed for most):

| what | how | answers |
|---|---|---|
| raw pen events | `adb shell getevent -lt` while hovering, drawing, tilting, pressing buttons | axis ranges, pressure curve, tilt sign, button codes, which device the buttons come from (touch IC or Bluetooth) |
| input devices | `adb shell dumpsys input` | names, bus, ranges as Android sees them |
| pen mode | `adb shell cat /proc/support_pen` with the pen connected and disconnected | when stock turns pen mode on |
| Bluetooth | Developer options → Bluetooth HCI snoop log, pair + use the pen, `adb bugreport` | pen name, HID report map, GATT services (battery, SN, version, "active time") |
| framework logs | `adb logcat -s BluetoothPenConnectPolicy CapacitorPenInputPolicy StylusPenInputManager` | the pen's name and ID as Lenovo matches them, attach and battery events |
| pen ID | `adb shell cat /proc/Pen_ID` (if present) | what the 0xF0 report carries |

The pen's Bluetooth name goes straight into `PENS=` in `/etc/asphalt-pen.conf`.

## Later

- Map the pen's Bluetooth buttons (once their keycodes are known).
- Pen battery for the shell island (BlueZ `Battery1`, or `pen_battery`).
- Use the firmware pen-detect frames for an `auto` mode that needs no
  Bluetooth, if the firmware sends them.
