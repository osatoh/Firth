# 4. Summary is its own model, kept per language

Date: 2026-09-17

## Status

Accepted

## Context

A summary could be columns on `Article`, or a model of its own. Summarisation is asynchronous and can fail, so it carries state (pending / done / failed) that is not really about the article.

Users choose their summary language. Some want to read in English, others in Japanese, and a user may change that setting. Regenerating a summary costs an API call each time.

## Decision

Model `Summary` separately, with a language, a body and a state. An article can hold several summaries, one per language, and changing the summary language never discards existing ones.

## Consequences

- Generation state and failure reasons stay out of `Article`.
- Switching back to a language that was summarised before reuses the stored summary, with no new API call.
- One extra table, and the article page must pick the summary matching the user's current language.
- Re-generating a summary in the same language is a separate decision, deferred until it is needed.
