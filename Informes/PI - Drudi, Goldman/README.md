## Common errors

#### Error: "Formatting failed. Please refer to LaTeX Workshop Output for details." when running the formatter on save

1. Error: "Can't locate File/HomeDir.pm in @INC"
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