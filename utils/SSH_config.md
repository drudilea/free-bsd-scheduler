# SSH config

> Root user privileges

## Installation

- [Install Vim editor](install_addons.md#vim-console)

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
vim /etc/ssh/sshd_config
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

> In case that your VM gets an IP address like `10.0.x.x`, you should follow [this tutorial](https://www.xmodulo.com/access-nat-guest-from-host-virtualbox.html) to connect by SSH `and login with:`

```bash
#ssh <user>@<localhost-ip> -p 2222
ssh root@127.0.0.1 -p 2222
```

---

## Copy files through SSH

### Copy from host to guest

```bash
#scp [-P] <port> <host-file-path> <user>@<virtual-machine-ip>:<file-path>
scp -P 2222 free-bsd-wiki/tests/marking_transition.txt root@127.0.0.1:/root/free-bsd-wiki/
```

### Copy from guest (VM) to host

```bash
#scp [-P] <port> <user>@<virtual-machine-ip>:<file-path> <host-file-path>
scp -P 2222 root@127.0.0.1:/root/free-bsd-wiki/dmesgOutput.txt free-bsd-wiki/tests/messages_$(date +"%Y-%m-%d_%H:%M")
```
