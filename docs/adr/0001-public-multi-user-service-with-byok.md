# 1. Public multi-user service with bring-your-own-key

Date: 2026-09-17

## Status

Accepted

## Context

Firth started as a self-hosted single-user reader: anyone who wanted it would clone the repo and run their own instance.

Self-hosting is awkward even for the author. Using the app means running and maintaining an instance, so there is no way to just open a URL and read.

AI summarisation costs money per call, so a public service has to answer who pays.

## Decision

Run Firth as a public multi-user service. Each user supplies their own Claude API key (BYOK), stored encrypted, and their summaries are billed to that key. Users without a key can read articles but cannot summarise them.

## Consequences

- Anyone can use Firth by signing up, with nothing to install.
- The operator pays for hosting (fetching, storage), so per-user usage must be bounded (see the feed limit in the spec).
- Third-party API keys and personal data are stored, so security and UK GDPR obligations apply (encryption at rest, account deletion).
- Self-hosting is out of scope. Features may assume a single shared deployment.
