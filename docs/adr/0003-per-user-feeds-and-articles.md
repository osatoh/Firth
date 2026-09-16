# 3. Feeds and articles are owned per user

Date: 2026-09-17

## Status

Accepted

## Context

When several users subscribe to the same RSS URL, feeds and articles could be shared (one `Feed` per URL, users joining through a subscription) or duplicated per user.

Sharing fetches each URL once, which keeps hosting cost flatter as users grow. But a reader is a personal thing: read/unread state, which feeds exist, and which articles are kept all belong to one person.

## Decision

Every user owns their own `Feed` and `Article` rows. Nothing is shared between users.

## Consequences

- Read/unread state lives directly on `Article`; no per-user join table is needed.
- Each user curates their own list of feeds and articles freely.
- Ownership is simple (`user.feeds`), and there is no way for one user's data to leak into another's view.
- The same URL is fetched and stored once per subscriber, so fetch jobs and database size grow with the number of users.
- Summaries are never reused across users, which fits BYOK: a summary is paid for by the user who requested it.
