## <h2 id="git"> Git </h2>

The first installation method we’ll show uses the FreeBSD package index. This is generally the easiest and fastest way to install Git.

First, update the pkg repository index

```bash
pkg update -f
```

Next, download and install the git package.

```bash
pkg install git
```

You’ll need to enter **y** to confirm the installation. That’s it!

## <h2 id="vim-console"> Vim Console </h2>

First, update the pkg repository index

```bash
pkg update -f
```

Next, download and install the Vim package.

```bash
pkg install vim-console (FreeBSD 11)
pkg install vim (FreeBSD 13)
```

You’ll need to enter **y** to confirm the installation. That’s it!

## <h2 id="nano"> Nano Editor </h2>

First, update the pkg repository index

```bash
pkg update -f
```

Next, download and install the Nano package.

```bash
pkg install nano
```

You’ll need to enter **y** to confirm the installation. That’s it!

## <h2 id="htop"> htop </h2>

First, update the pkg repository index

```bash
pkg update -f
```

Next, download and install the htop package.

```bash
pkg install htop
```

You’ll need to enter **y** to confirm the installation. That’s it!

## <h2 id="gcc"> gcc </h2>

```bash
pkg install lang/gcc
```

You’ll need to enter **y** to confirm the installation

## <h2 id="fish"> fish shell</h2>

```bash
pkg install fish
```

Set fish as default shell

```bash
whereis fish
# fish: /usr/local/bin/fish /usr/local/share/man/man1/fish.1.gz

chsh -s /usr/local/bin/fish
```

## <h2 id="screen"> Screen </h2>

```bash
pkg install screen
```

### Using screen

- `Ctrl+a` `S`: Split current region horizontally into two regions.
- `Ctrl+a` `tab`: Switch the input focus to the next region.
- `Ctrl+a` `c`: Create a new window (with shell).
- `Ctrl+a` `A`: Rename the current window.
- `Ctrl+a` `X`: Close the current region.
- `Ctrl+a` `d`: Detach from Linux Screen Session
- `Ctrl+a` `Ctrl+a`: Toggle between the current and previous windows
- `Ctrl+a` `|`: Split current region vertically into two regions.
- `Ctrl+a` `"`: List all windows.
- `Ctrl+a` `0`: Switch to window 0 (by number).
- `Ctrl+a` `Q`: Close all regions but the current one.
