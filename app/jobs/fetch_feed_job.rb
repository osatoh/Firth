require "net/http"

# Reads a feed and stores the entries that are not stored yet (spec 4.1).
# Only feed-level data is stored; content is extracted later (ADR 0005).
class FetchFeedJob < ApplicationJob
  queue_as :default

  # The feed was deleted after the job was enqueued.
  discard_on ActiveJob::DeserializationError

  MAX_REDIRECTS = 3
  TIMEOUT = 10.seconds

  class FetchError < StandardError; end

  def perform(feed)
    parsed = Feedjira.parse(fetch(feed.url))
    store_new_entries(feed, parsed.entries)
    feed.update!(last_fetched_at: Time.current)
  rescue FetchError, Feedjira::NoParserAvailable, SystemCallError, SocketError,
         Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, URI::InvalidURIError => e
    # Not re-raised: the next scheduled fetch is the retry, so a broken feed
    # cannot pile up retries in the queue.
    Rails.logger.warn("Failed to fetch feed #{feed.id} (#{feed.url}): #{e.class}: #{e.message}")
  end

  private
    def fetch(url, redirects_left = MAX_REDIRECTS)
      uri = URI.parse(url)
      raise FetchError, "not an http(s) URL: #{url}" unless uri.is_a?(URI::HTTP)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                 open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.request(Net::HTTP::Get.new(uri))
      end

      case response
      when Net::HTTPSuccess
        response.body
      when Net::HTTPRedirection
        raise FetchError, "too many redirects" if redirects_left.zero?

        fetch(URI.join(uri, response["location"]).to_s, redirects_left - 1)
      else
        raise FetchError, "HTTP #{response.code}"
      end
    end

    def store_new_entries(feed, entries)
      now = Time.current
      rows = entries.filter_map do |entry|
        url = entry.url.presence or next
        {
          feed_id: feed.id,
          # RSS guid / Atom id, falling back to the URL for feeds without one.
          guid: entry.entry_id.presence || url,
          url:,
          title: entry.title.presence || url,
          published_at: entry.published,
          created_at: now,
          updated_at: now
        }
      end
      return if rows.empty?

      # The unique index decides what is new, so concurrent fetches of the
      # same feed cannot store an entry twice.
      Article.insert_all(rows, unique_by: [ :feed_id, :guid ])
    end
end
