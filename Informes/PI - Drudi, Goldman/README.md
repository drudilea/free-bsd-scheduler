## Installation

There are two possible paths to follow for installing LaTeX in a Mac.

- [MacTeX](https://www.tug.org/mactex/)
- [Basic TeX](https://www.tug.org/mactex/morepackages.html) (smaller distribution)

### Basic TeX installation

In this case we will explain the steps for a minimal installation

1. Download and install Basic TeX from the link above
2. Reboot the computer
3. As this package isn't delivered with the `latexmk` package in it, we will need to install it running a command

   ```bash
   sudo tlmgr install latexmk
   ```

   💡 In some cases the TeX Live package manager (`tlmgr`) is outdated, it will prompt you to update it with this command

   ```bash
   sudo tlmgr update --self
   ```

4. Other packages that might be needed are these (don't forget to check the console output in search of some more missing packages)

   ```bash
   sudo tlmgr install ellipsis
   ```

   ```bash
   sudo tlmgr install here
   ```

   ```bash
   sudo tlmgr install tocbibind
   ```

## Common errors

#### Error: "Formatting failed. Please refer to LaTeX Workshop Output for details." when running the formatter on save

1. If latexindent is not installed, run the following command

   ```bash
   brew install latexindent
   ```

2. Error: "Can't locate YAML/Tiny.pm in @INC"

   ```bash
   sudo cpan YAML::Tiny
   ```

3. Error: "Can't locate File::HomeDir in @INC"
   ```bash
   sudo perl -MCPAN -e 'install "File::HomeDir"'
   ```
