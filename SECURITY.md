# Security Policy

## Supported versions

Security fixes are applied to the latest published release.

## Reporting a vulnerability

Please do not open a public issue for a vulnerability. Use GitHub's private vulnerability reporting
for this repository:

https://github.com/Byctor/codex-usage-sidebar/security/advisories/new

Include the affected version, impact, reproduction steps, and any suggested mitigation. You should
receive an initial response within seven days. Please allow a reasonable remediation window before
public disclosure.

## Security boundaries

The companion must remain outside `/Applications/ChatGPT.app`; it must not inject into, modify, or
re-sign the official app. It must not read Codex account tokens, upload quota data, or bypass macOS
privacy controls. See [docs/PRIVACY.md](docs/PRIVACY.md) for the data-flow model.
