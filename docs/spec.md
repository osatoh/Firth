# Firth Specification

> Status: Drafted through all six steps. Revise as the app gets built and used.
> 1. Scope & users
> 2. User stories / use cases
> 3. Domain model
> 4. Key flows
> 5. Decisions (ADRs in `docs/adr/`)
> 6. Task breakdown

## 1. Scope & Users

### 1.1 Product

Firth is a public, multi-user web RSS reader with on-demand AI summarisation.

### 1.2 Users

- Anyone with a Google account can sign up. Google sign-in is the only authentication method.
- Each user owns their own feeds and articles. Nothing is shared between users.
- AI summarisation uses the user's own Claude API key (bring your own key).
  - Users without an API key can still read articles but cannot summarise them.
  - The operator's key is never used for user summaries.

### 1.3 MVP: In Scope

| # | Feature | Notes |
|---|---|---|
| 1 | Sign up / log in / log out | Google sign-in only; no passwords, so no password reset or email verification |
| 2 | API key settings (add / replace / delete) | Stored encrypted |
| 3 | Summary language setting | Per user |
| 4 | Feed add / edit / delete | Per user |
| 5 | Periodic article fetching | Solid Queue recurring job |
| 6 | Full article content extraction | From the article URL |
| 7 | On-demand summarisation | Async job, cached result, live update via Turbo Stream |
| 8 | Article list | Title + summary |
| 9 | Read / unread state | Per article |
| 10 | Per-user limits | e.g. max feeds; controls hosting cost |
| 11 | Account deletion | Deletes all user data (UK GDPR) |
| 12 | OPML import | Migration from other readers |

### 1.4 Out of Scope (Future)

- Keyword-based scoring
- Auto-tagging by AI
- Hacker News integration
- PWA support
- Self-hosted distribution
- Sharing feeds or articles between users
- Authentication methods other than Google (e.g. email + password)

### 1.5 Constraints

- Deployment: AWS, via Kamal from GitHub Actions.
- Stack: Rails 8.1, PostgreSQL, Solid Queue / Cache / Cable, Hotwire, Tailwind CSS.
- The operator pays for hosting (fetching, storage), so per-user usage must be bounded.
- Users' API keys and personal data are stored, so security and privacy obligations apply.

## 2. User Stories

Approach: build the simplest version first, use it daily, then improve what feels awkward.

### 2.1 Daily Reading

1. When I open Firth, I see new articles from all my feeds, newest first.
2. I scan the titles and open the articles that interest me.
3. On an article page, I press "Summarise" and the summary appears in my chosen language a few seconds later.
4. I can jump to the original article from both the article list and the article page.
5. An article is marked as read when I open its article page or follow its original link.

### 2.2 Deferred Until Real Use

Not in the first version. Revisit after using the app:

- Showing summaries (or a summarise button) in the article list
- Filtering the list by feed
- An unread-only view

### 2.3 Onboarding & Settings

1. I sign up and log in with my Google account.
2. Right after sign-up, I am prompted to add my Claude API key and choose a summary language. I can skip this.
3. If I skipped the API key, pressing "Summarise" guides me to add one.
4. I add a feed by entering its RSS URL, or import an OPML file.
5. Right after adding a feed, fetching starts and articles appear in my list shortly.
6. If I have reached the feed limit, I see why I cannot add another feed.
7. I can delete my account from settings, which deletes all my data.

## 3. Domain Model

```
User 1 ── * Feed 1 ── * Article 1 ── * Summary
```

Feeds and articles are owned by a single user, so per-user state (read/unread) lives directly on `Article`.

| Model | Role | Key attributes (conceptual) |
|---|---|---|
| **User** | A person who signs in with Google | Google account id, email, name, summary language, Claude API key (encrypted) |
| **Feed** | An RSS feed the user subscribed to | URL, title, last fetched at |
| **Article** | An entry fetched from a feed | Original URL, title, published at, extracted content, read at |
| **Summary** | An AI summary of an article | Language, body, state (pending / done / failed) |

### 3.1 Summaries

- A summary is a separate model, not columns on `Article`, so generation state and errors stay out of the article itself.
- One article can hold several summaries, one per language. Changing the summary language does not discard existing summaries, and switching back reuses the earlier one instead of paying for the API again.

## 4. Key Flows

### 4.1 Fetching Articles

1. A recurring job runs every 15 minutes and enqueues a fetch job per feed.
2. Each fetch job reads the feed, and stores entries that are not stored yet.
3. Only feed-level data (title, URL, published at) is stored at this point. Article content is not extracted here.

### 4.2 Summarising an Article

1. The user presses "Summarise" on an article page.
2. If the user has no API key stored, they are guided to add one and nothing is enqueued.
3. If a summary already exists in the user's current summary language, it is shown immediately and no API call is made.
4. Otherwise a summary record is created in the `pending` state and a job is enqueued.
5. The job extracts the full article content from the original URL, then calls the Claude API with the user's key.
6. On success the summary is stored as `done`; on failure it is stored as `failed` with a reason the user can act on (e.g. invalid API key, extraction failed).
7. Either way the article page updates live via Turbo Stream.

Content extraction happens inside the summary job (deferred extraction). If waiting for extraction turns out to be too slow in daily use, move extraction into the fetch job instead.

### 4.3 Reading an Article

- Opening the article page, or following the original article link from either the list or the article page, marks the article as read.

## 5. Decisions

Each decision and its reasoning lives in its own file under `docs/adr/`:

1. [Public multi-user service with bring-your-own-key](adr/0001-public-multi-user-service-with-byok.md)
2. [Google sign-in as the only authentication method](adr/0002-google-sign-in-only.md)
3. [Feeds and articles are owned per user](adr/0003-per-user-feeds-and-articles.md)
4. [Summary is its own model, kept per language](adr/0004-summary-as-its-own-model-per-language.md)
5. [Extract article content lazily, at summarisation time](adr/0005-extract-article-content-lazily.md)

## 6. Task Breakdown

Ordered so that each task leaves the app working. The aim is to reach a usable reader early (Phase 2), then add AI summaries, then the rest.

### Phase 0: Foundation

| # | Task | Done when |
|---|---|---|
| 0.1 | Add RSpec | `rspec-rails` installed, `spec/` generated, `bundle exec rspec` passes |
| 0.2 | Add a test job to CI | CI starts PostgreSQL and runs RSpec on every push |
| 0.3 | Set up the database and local development | `bin/setup` and `bin/dev` bring up the app locally |

### Phase 1: Accounts

| # | Task | Done when |
|---|---|---|
| 1.1 | `User` model | Stores Google account id, email, name; migration and model specs pass |
| 1.2 | Google sign-in | Sign in, sign out, and a session that survives a reload; a first sign-in creates the user |
| 1.3 | Require sign-in | Every page except the landing and auth pages redirects signed-out visitors |

### Phase 2: Reading (usable reader)

| # | Task | Done when |
|---|---|---|
| 2.1 | `Feed` model and CRUD | A signed-in user can add, edit and delete feeds; invalid URLs are rejected |
| 2.2 | `Article` model and feed fetching job | Fetching a feed stores its new entries and skips ones already stored |
| 2.3 | Recurring fetch every 15 minutes | Solid Queue recurring job enqueues a fetch job per feed |
| 2.4 | Article list | All feeds' articles, newest first, with a link to the original article |
| 2.5 | Article page | Title, feed, published date, original link |
| 2.6 | Read / unread state | Opening the article page or following the original link marks it read |

At the end of Phase 2 the app is usable daily as a plain RSS reader.

### Phase 3: AI Summaries

| # | Task | Done when |
|---|---|---|
| 3.1 | API key and summary language settings | Key is stored encrypted, shown masked, and can be replaced or deleted |
| 3.2 | Article content extraction | Given an article URL, the full text is extracted; failures are reported, not raised |
| 3.3 | `Summary` model | One summary per article per language, with pending / done / failed states |
| 3.4 | Summarisation job | Extracts content, calls the Claude API with the user's key, stores the result or the failure reason |
| 3.5 | Summarise button and live update | Pressing it enqueues the job, and the result appears via Turbo Stream without a reload |
| 3.6 | Reuse and guidance | An existing summary in the current language is shown without an API call; a missing API key guides the user to settings |

### Phase 4: Operations and the Rest

| # | Task | Done when |
|---|---|---|
| 4.1 | Per-user feed limit | Adding a feed beyond the limit is refused with a clear reason |
| 4.2 | Account deletion | Deleting an account removes the user and all their feeds, articles and summaries |
| 4.3 | OPML import | Uploading an OPML file creates the feeds it lists, within the feed limit |
| 4.4 | Onboarding prompt | After the first sign-in, the user is prompted to add an API key and language, and can skip |
| 4.5 | Deploy to AWS with Kamal | `config/deploy.yml` targets the AWS host and a manual deploy succeeds |
| 4.6 | Deploy from GitHub Actions | Merging to `main` deploys, with secrets stored in GitHub |
| 4.7 | Landing page and README | A signed-out visitor understands what Firth is; the README matches the built app |
