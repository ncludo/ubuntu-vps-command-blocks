# Ubuntu VPS Command Blocks

Experimental interactive Bash prompt with visual command boundaries, execution status, timing, and optional fail-fast batch execution.

Built for Ubuntu VPS administration over SSH.

## Preview

![Command Blocks terminal preview](docs/images/preview.png)

## Features

- Visual command blocks with clear input/output boundaries
- Exit codes and execution duration
- Git branch and working directory in the prompt
- ANSI accent color controlled by the terminal palette
- Manual spacing using empty Enter or `cbgap`
- Separate command blocks during normal multiline paste
- Optional fail-fast execution of multiline pasted batches
- One input/output separator and one overall status per batch
- Interrupt reporting for batches cancelled with Ctrl+C
- Temporary shell session without modifying Bash configuration

## Quick start

Run from an existing interactive Bash session:

    bash ./command-blocks.bash

This starts a temporary nested Bash session. No installation is performed.

Press `Ctrl+D` inside Command Blocks to return to the parent shell. Do not use `Ctrl+D` from the original SSH shell unless you intend to disconnect.

## Commands

| Command | Description |
| --- | --- |
| `cbgap N` | Add 1–15 blank lines between command groups |
| `cb stop on` | Enable fail-fast execution for multiline pasted batches |
| `cb stop off` | Restore normal sequential paste behavior |
| `cb stop status` | Show the current stop mode |

Stop Mode is disabled by default.

## Stop Mode

When enabled, multiline pasted input is collected for review. Press Enter to execute the collected batch.

The batch runs in a separate Bash process using `-e` and `pipefail`.

An unhandled failure stops the remaining commands, subject to Bash's standard `errexit` semantics. The parent interactive shell remains available.

The original pasted commands are displayed inside one Command Blocks frame. The batch has one separator, one overall exit code, and one execution timer.

Ctrl+C interruption is reported with exit code 130 in the tested scenario.

Run `cb stop on`, `cb stop off`, and `cb stop status` separately at the interactive prompt. These controls cannot change the parent shell's state from inside a child batch.

Changes to variables, functions, exports, and the working directory inside a batch do not propagate to the parent shell.

Stop Mode is not transactional. Commands completed before a failure are not rolled back.

## Current limitations

This remains an experimental prototype, not a production-ready shell configuration.

- Bash `errexit` does not stop on every nonzero status in every syntax context.
- A child batch cannot change its parent shell's environment.
- Individual commands inside a batch do not receive separate status badges.
- Terminal-specific paste and redraw handling require further compatibility testing.
- No persistent installation or automatic shell activation is provided yet.
- Command history is disabled in the temporary test shell.

## Tested environment

- Ubuntu 24.04.4 LTS
- Bash 5.2
- MobaXterm 25.4 on Windows 10

Tested scenarios include:

- Normal sequential and large multiline paste
- Manual spacing and `cbgap`
- Exit status reporting and execution timing
- Git prompt information and terminal colors
- Heredoc and interactive `read`
- Stop Mode enabled and disabled
- Fail-fast batches with and without errors
- Ctrl+C interruption and recovery
- Parent-shell control commands inside a child batch

Compatibility with other terminals and shell environments has not yet been established.

## Development status

Current experimental version: **v0.15.0**.

The next planned development area is persistent installation, shell activation/deactivation, and complete rollback.
