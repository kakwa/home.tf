# Serial Console Role

This Ansible role configures a Linux system to enable serial console access through both GRUB and the system's getty service.

## Features

- Configures GRUB bootloader for serial console access
- Sets up kernel parameters for console output on serial port
- Enables and starts getty service on the serial port
- Configurable serial port parameters (speed, port, etc.)
- Automatic GRUB configuration update

## Requirements

- Debian/Ubuntu-based system with GRUB bootloader
- Root/sudo access
- Physical or virtual serial port available

## Role Variables

Available variables are defined in `defaults/main.yml`:

### Serial Port Configuration

- `serial_console_port`: Serial port device (default: `"ttyS0"`)
- `serial_console_speed`: Baud rate (default: `115200`)
- `serial_console_params`: Serial parameters (default: `"8n1"`)

### GRUB Configuration

- `grub_serial_unit`: GRUB serial unit number (default: `0` for ttyS0)
- `grub_serial_speed`: GRUB serial speed (default: `115200`)
- `grub_serial_word`: Data bits (default: `8`)
- `grub_serial_parity`: Parity (default: `"no"`)
- `grub_serial_stop`: Stop bits (default: `1`)
- `grub_timeout`: GRUB menu timeout in seconds (default: `5`)

### Feature Toggles

- `grub_serial_enable`: Enable serial console in GRUB (default: `true`)
- `getty_serial_enable`: Enable getty on serial port (default: `true`)

### Kernel Parameters

- `console_kernel_params`: Console parameters added to kernel command line
  (default: `"console=tty0 console=ttyS0,115200n8"`)

## Example Playbook

Basic usage with defaults:

```yaml
---
- hosts: servers
  become: true
  roles:
    - serial-console
```

Custom configuration:

```yaml
---
- hosts: servers
  become: true
  roles:
    - role: serial-console
      vars:
        serial_console_port: "ttyS1"
        serial_console_speed: 9600
        grub_serial_unit: 1
        grub_serial_speed: 9600
```

With tags:

```yaml
---
- hosts: servers
  become: true
  roles:
    - { role: serial-console, tags: ["system", "serial"] }
```

## Usage

After running this role:

1. **Reboot the system** for GRUB changes to take effect
2. Connect to the serial port using a serial console tool:
   ```bash
   # On Linux
   screen /dev/ttyUSB0 115200
   # or
   minicom -D /dev/ttyUSB0 -b 115200
   # or
   picocom -b 115200 /dev/ttyUSB0
   ```

3. You should see:
   - GRUB menu on the serial console
   - Kernel boot messages
   - Login prompt on the serial console

## Testing

To verify the configuration:

```bash
# Check if getty service is running
systemctl status serial-getty@ttyS0.service

# Check GRUB configuration
grep -E "GRUB_TERMINAL|GRUB_SERIAL_COMMAND|GRUB_CMDLINE_LINUX" /etc/default/grub

# Check if serial port exists
ls -l /dev/ttyS0
```

## Notes

- The role preserves existing GRUB configuration by backing it up to `/etc/default/grub.backup`
- Both VGA console (`console=tty0`) and serial console are enabled by default
- For virtual machines (KVM/QEMU), ensure the VM is configured with a serial port
- The serial port device may not exist until after reboot on some systems

## License

Same as the parent repository.

