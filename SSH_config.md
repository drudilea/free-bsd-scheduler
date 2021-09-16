# SSH connection

> Root user privileges

## Installation

- Install NANO editor

```bash
pkg install nano
```

- Enable SSHD in `/etc/rc.conf`

```bash
echo 'sshd_enable="YES"' >> /etc/rc.conf
```

- Verify status

```bash
sysrc sshd_enable
```

- Restart SSHD service

```bash
service sshd restart
```

- Edit `sshd_config` file

```bash
nano /etc/ssh/sshd_config
```

- Find the following line:

```bash
#PermitRootLogin no
```

- Uncomment it by removing the hash (#) symbol and change it's value to yes like below:

```bash
PermitRootLogin yes
```

- Restart SSHD service again (same command as before)

- Now you can be able to login via SSH as root user from any system on the network using command

```bash
 ssh <user>@<virtual-machine-ip>
```
