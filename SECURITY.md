# Security policy

## Reporting a vulnerability

Please report a vulnerability privately, through GitHub's private vulnerability reporting: the
**Report a vulnerability** button on this repository's **Security** tab. Do not open a public
issue or pull request for it.

Include what you found, where (a file and line, or a command), how to reproduce it, and what an
attacker gains. The maintainer reads reports in the Security tab and answers there.

## Scope

In scope: the `way-of-working` plugin under `plugins/way-of-working/`, the host and container
identity tools under `scripts/identity/`, the loop tooling under `scripts/loop/`, this
repository's dev container and its CI workflows.

Out of scope: the shared dev-container template and its images (report those to
[603-Identity/devcontainers](https://github.com/603-Identity/devcontainers)), and Claude Code,
GitHub or other third-party software this repository uses.

## How a report is handled

If a fix is needed, it goes through a normal public pull request named for the change. The
advisory is published or closed once that pull request merges. How findings are recorded is
decision `WB-D57` in [docs/decisions.md](docs/decisions.md).
