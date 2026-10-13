# Ubuntu VPS Command Blocks

Experimental interactive Bash prompt with command boundaries, execution status, timing, and optional fail-fast batch execution.

Built for Ubuntu VPS administration over SSH.

## Preview

![Command Blocks terminal preview](docs/images/preview.png)

## Features

- Visual command blocks with clear input/output boundaries
- Exit codes and execution duration
- Git branch and working directory in the prompt
- ANSI accent color controlled by the terminal palette
- Manual spacing using empty Enter or `cbgap`
- Separate command blocks during multiline paste
- Optional stop-on-error mode for pasted batches
- Temporary shell session without modifying Bash configuration

## Quick start

Run from an existing interactive Bash session:

    bash ./command-blocks.bash

This starts a temporary nested Bash session. No installation is performed.

Press `Ctrl+D` while inside Command Blocks to return to the parent shell. Do not use `Ctrl+D` from the original SSH shell unless you intend to disconnect.

## Commands

| Command | Description |
| --- | --- |
| `cbgap N` | Add 1–15 blank lines between command groups |
| `cb stop on` | Enable fail-fast execution for multiline pasted batches |
| `cb stop off` | Restore normal sequential paste behavior |
| `cb stop status` | Show the current stop mode |

Stop Mode is disabled by default.

## Stop Mode

When enabled, multiline pasted input is collected before execution. Press Enter to execute the collected batch.

The batch runs in a separate Bash process using `-e` and `pipefail`.

Execution stops on an unhandled failure, subject to Bash's standard `errexit` behavior. The parent interactive shell remains available.

Changes to shell variables, exported environment variables, functions, and the current directory inside the batch do not propagate to the parent shell.

## Current limitations

This is an experimental prototype, not a production-ready shell configuration.

- Stop Mode displays `_cb_run_batch` instead of the original pasted command.
- Batch output currently contains two separators.
- Interrupting a batch with `Ctrl+C` may skip the custom stop message.
- Shell management functions are unavailable inside the child Bash.
- Terminal-specific paste handling requires further compatibility testing.
- No persistent installation or automatic shell activation is provided yet.

## Tested environment

- Ubuntu 24.04 LTS
- Bash 5.2
- MobaXterm 25.4 on Windows 10

Tested scenarios include sequential paste, manual spacing, exit status reporting, Git prompt information, heredoc, interactive `read`, delayed commands, and basic fail-fast batch execution.

Compatibility with other terminals and shell environments has not yet been established.

## Development status

Current prototype: v0.14-dev.

The next development stage focuses on improving batch rendering, shell controls, and interruption handling before implementing persistent installation and rollback.
