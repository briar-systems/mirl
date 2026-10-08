# Security Policy

## Supported Versions

Security fixes are applied to the latest release only. Older releases are not patched.

## Reporting a Vulnerability

Please report security vulnerabilities privately through GitHub's
[private vulnerability reporting](https://github.com/briar-systems/mirl/security/advisories/new)
rather than opening a public issue.

mirl reads IR, as text or through the builder, from any front end. A malformed
module that makes mirl crash, hang, or read or write out of bounds instead of
failing the build is a vulnerability. So is code mirl emits that breaks the
secrecy or constant-time requirements the IR states.

Expect an acknowledgement within a few days. If the report is confirmed we will
prepare a fix and coordinate disclosure with you. If it is declined we will
explain why.
