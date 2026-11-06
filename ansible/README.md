# ansible-hypervisor

Ansible for my homelab hypervisor.

## Bootstrap

```bash
export HOSTNAME=your-hostname
export LOGIN=kakwa

ssh-copy-id $LOGIN@$HOSTNAME
ssh $LOGIN@$HOSTNAME "su -c '
apt update && apt install -y sudo
/usr/sbin/usermod -aG sudo $LOGIN
echo \"$LOGIN ALL=(ALL) NOPASSWD:ALL\" > /etc/sudoers.d/$LOGIN
chmod 440 /etc/sudoers.d/$LOGIN
'"

ansible-playbook -i $HOSTNAME, hypervisor.yml
```

## Serial Console

```bash
screen /dev/ttyUSB0 115200   # connect
# Ctrl-A D to detach, screen -r to reattach
```
