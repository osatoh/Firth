# Firth

Firth is a public, multi-user RSS reader with on-demand AI summaries.

- Each user subscribes to their own feeds; feeds and articles are never shared between users.
- Feeds can be imported from an OPML file.
- Articles are summarized on demand with Claude, using **the user's own Claude API key** (BYOK).
  The key is stored encrypted and is never shared; the operator's key is never used.
- Sign-in is Google only.
- Deleting an account removes all of that user's data.

## Stack

- Ruby 4.0 / Rails 8.1
- PostgreSQL
- Solid Queue, Solid Cache, Solid Cable
- Hotwire (Turbo, Stimulus) with importmap
- Tailwind CSS
- RSpec, RuboCop, Brakeman

## Local setup

Requirements: the Ruby version in `.ruby-version` and a running PostgreSQL.

```sh
bin/setup   # install gems, prepare the database, then start the dev server
bin/dev     # start the app and the Tailwind watcher
```

The app runs at http://localhost:3000.

### Google OAuth

Sign-in needs a Google OAuth client. The app reads it from Rails credentials
(`config/initializers/omniauth.rb`):

```sh
bin/rails credentials:edit
```

```yaml
google_oauth2:
  client_id: ...
  client_secret: ...
```

Register `http://localhost:3000/auth/google_oauth2/callback` as an authorized redirect URI
in the Google Cloud console.

### Active Record Encryption (production)

Users' Claude API keys are encrypted with Active Record Encryption. Generate keys with:

```sh
bin/rails db:encryption:init
```

In production, set them as environment variables (read in `config/environments/production.rb`):

- `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`
- `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`
- `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`

When a variable is not set, Rails falls back to `active_record_encryption` in the credentials.
Keep these keys stable: losing or changing them makes stored API keys unreadable.

## Tests and lint

```sh
bundle exec rspec
bin/rubocop
bin/brakeman
```

`bin/ci` runs the full local CI pipeline defined in `config/ci.rb`.

## Background jobs

In production, jobs run on Solid Queue, and `config/recurring.yml` fetches all feeds every
15 minutes (`FetchAllFeedsJob`). The recurring schedule is defined for production only;
development uses Rails' default in-process (async) adapter, so feeds are fetched only when
a feed is added or its URL changes.

## Design notes

- [`docs/spec.md`](docs/spec.md): requirements, user stories, and the task list.
- [`docs/adr/`](docs/adr/): architecture decision records (public multi-user service with BYOK,
  Google sign-in only, per-user feeds and articles, summaries per language, lazy article extraction).

## Deployment

A Kamal configuration exists (`config/deploy.yml`, `bin/kamal`), but deployment to AWS
has not been done yet.
