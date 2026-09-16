# 2. Google sign-in as the only authentication method

Date: 2026-09-17

## Status

Accepted

## Context

Making Firth a public service (see [ADR 1](0001-public-multi-user-service-with-byok.md)) requires authentication. The candidates were email + password, Google sign-in, or both.

This is an MVP, and every extra sign-in path is more to build, test and maintain.

## Decision

Support Google sign-in only.

## Consequences

- Fewer authentication paths to build and test.
- No passwords are stored, so password reset is unnecessary.
- Google supplies a verified email address, so email verification is unnecessary. Both features left the MVP scope.
- People without a Google account cannot use Firth.
- Google Cloud OAuth setup and its consent screen become a deployment prerequisite.
- Adding another method later means deciding how to link accounts that share an email address.
