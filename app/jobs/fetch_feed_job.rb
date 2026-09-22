# Reads a feed and stores the entries that are not stored yet (spec 4.1).
# Only feed-level data is stored; content is extracted later (ADR 0005).
class FetchFeedJob < ApplicationJob
  queue_as :default

  # The feed was deleted after the job was enqueued.
  discard_on ActiveJob::DeserializationError

  def perform(feed)
    parsed = Feedjira.parse(SafeHttp.get(feed.url))
    store_new_entries(feed, parsed.entries)
    feed.update!(last_fetched_at: Time.current)
  rescue SafeHttp::Error, Feedjira::NoParserAvailable, SystemCallError, SocketError,
         Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, URI::InvalidURIError => e
    # Not re-raised: the next scheduled fetch is the retry, so a broken feed
    # cannot pile up retries in the queue.
    Rails.logger.warn("Failed to fetch feed #{feed.id} (#{feed.url}): #{e.class}: #{e.message}")
  end

  private
    def store_new_entries(feed, entries)
      rows = entries.filter_map do |entry|
        # Feeds are untrusted: never store a javascript: or other non-web URL.
        next unless WebUrl.valid?(entry.url)

        url = entry.url
        {
          # RSS guid / Atom id, falling back to the URL for feeds without one.
          guid: entry.entry_id.presence || url,
          url:,
          title: entry.title.presence || url,
          published_at: entry.published
        }
      end
      return if rows.empty?

      # The unique index decides what is new, so concurrent fetches of the
      # same feed cannot store an entry twice.
      feed.articles.insert_all(rows, unique_by: [ :feed_id, :guid ])
    end
end
