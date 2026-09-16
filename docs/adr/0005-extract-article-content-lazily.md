# 5. Extract article content lazily, at summarisation time

Date: 2026-09-17

## Status

Accepted

## Context

Summarising needs the full article text, which RSS entries often do not include, so the content has to be extracted from the original URL.

Extraction could run for every article when a feed is fetched, or only when a summary is requested. Feeds are fetched every 15 minutes for every user, and most fetched articles are never opened, let alone summarised.

## Decision

Extract article content inside the summary job, not the fetch job.

## Consequences

- Only articles the user actually summarises are fetched in full, so stored data and outbound requests stay far smaller.
- Extraction time is added to the wait after pressing "Summarise".
- Extraction failure surfaces as a failed summary rather than a failed fetch.
- If the wait becomes annoying in daily use, move extraction into the fetch job (see the spec).
