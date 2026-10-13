# Ubuntu VPS Command Blocks

Experimental interactive Bash prompt with visual command boundaries, execution status, timing, and independently configurable batch grouping and stop-on-error behavior.

Built for Ubuntu VPS administration over SSH.

## Preview

![Command Blocks terminal preview](docs/images/preview.png)

## Features

- Visual command blocks with input/output boundaries
- Exit codes and execution duration
- Git branch and working directory in the prompt
- ANSI accent color controlled by the terminal palette
- Manual spacing using empty Enter or `cbgap`
- Independent batch grouping and stop-on-error settings
- Four combinations of execution behavior
- Fail-fast execution isolated from the interactive shell
- Interrupt reporting and recovery
- Temporary shell without modifying Bash configuration

## Quick start

Run from an existing interactive Bash session:

    bash ./command-blocks.bash

This starts a temporary nested Bash session. No installation is performed.

Press `Ctrl+D` inside Command Blocks to return to the parent shell. Do not use `Ctrl+D` from the original SSH shell unless you intend to disconnect.

## Commands

| Command | Description |
| --- | --- |
| `cb status` | Show both current modes |
| `cb batch separate` | Display separate command blocks |
| `cb batch grouped` | Display one block for a pasted batch |
| `cb batch status` | Show the batch mode |
| `cb stop on` | Stop on an unhandled batch failure |
| `cb stop off` | Continue after errors |
| `cb stop status` | Show the stop mode |
| `cbgap N` | Add 1–15 blank lines between command groups |

Default: **Separate + Stop OFF**.

Run mode-control commands separately at the interactive prompt.

## Execution modes

Batch grouping and stop-on-error behavior are independent.

| Batch mode | Stop OFF | Stop ON |
| --- | --- | --- |
| Separate | Individual blocks, continue | Individual blocks, fail-fast |
| Grouped | One block, continue | One block, fail-fast |

These settings primarily control multiline pasted input.

### Separate + Stop OFF

Normal interactive Bash execution.

Each completed command receives its own frame, exit code, and timer.

A failure does not automatically cancel subsequent pasted commands.

### Separate + Stop ON

A multiline paste is collected and executed in a child Bash.

The input is divided into complete top-level Bash constructs. Each construct receives its own frame, status, and timer.

For example, `if`, `for`, pipelines, and heredocs can be displayed as complete blocks rather than individual internal commands.

Execution stops on an unhandled failure, subject to Bash `errexit` and `pipefail` semantics.

### Grouped + Stop OFF

A multiline paste runs in a child Bash without fail-fast enabled.

The entire input receives one frame, one final exit code, and one execution timer.

An earlier failure may be followed by successful commands. The final status reflects the overall shell execution result.

### Grouped + Stop ON

A multiline paste runs in a child Bash with `-e` and `pipefail`.

The entire input receives one frame, one final exit code, and one execution timer.

Unhandled failures stop the remaining commands.

## Important behavior

Stop Mode does not provide transactional rollback. Commands completed before a failure are not undone.

Bash `errexit` has exceptions for conditions, `&&`, `||`, pipelines, and other language constructs.

Pasted batches executed in a child shell cannot change the parent shell's working directory, variables, or functions.

Interactive input remains available inside supported child batches.

Ctrl+C interrupts execution without intentionally terminating the parent SSH shell.

## Current limitations

This is an experimental prototype, not a production-ready shell.

- Top-level command splitting is based on incremental Bash syntax checks.
- Complex dynamic constructs such as `eval` and `source` are not fully validated.
- Custom traps, background jobs, and unusual shell control flow need further testing.
- Compound commands receive one overall status, not individual internal statuses.
- Terminal-specific paste and redraw behavior may differ between SSH clients.
- Compatibility with other Bash versions is not established.
- Command history is disabled in the temporary test shell.
- Persistent installation, automatic activation, and rollback are not implemented.

## Tested environment

- Ubuntu 24.04.4 LTS
- Bash 5.2
- MobaXterm 25.4 on Windows 10

Tested scenarios include:

- All four Batch/Stop combinations
- Multiline paste with and without failures
- Sequential execution and fail-fast interruption
- Pipelines with `pipefail`
- Conditional commands and handled failures
- `if/else` and `for`
- Heredoc with blank lines
- Interactive `read`
- Command substitution
- Execution timing
- Ctrl+C and interactive shell recovery
- Git prompt information and terminal colors

Compatibility beyond the tested environment is not guaranteed.

## Development status

Current experimental version: **v0.16.0**.

Persistent installation, activation/deactivation, and full rollback are planned for a future development stage.
