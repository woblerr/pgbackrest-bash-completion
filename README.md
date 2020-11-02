# pgBackRest Bash Completion
A script that adds bash completion for pgBackRest (https://pgbackrest.org/).

# Usage

* Simple use:
    ```bash
    source /path/to/pgbackrest-completion.sh
    ```

* For permanent use:
  
    Copy `pgbackrest-completion.sh` in your bash_completion.d folder (`/etc/bash_completion.d`, `/usr/local/etc/bash_completion.d` or `~/bash_completion.d`).
    
    Or load `pgbackrest-completion.sh` file in your `~/.bashrc` or `~/.profile`:

    ```bash
    echo "source /path/to/pgbackrest-completion.sh" >> ~/.bashrc
    ```