# Extracts the readable main text of an article page (spec 4.2), for the
# summary job to send to Claude. Extraction runs lazily at summarisation time
# and its result is not stored (ADR 0005).
#
# Expected failures (network errors, blocked addresses, non-HTML pages, pages
# without enough text) are returned as a Failure with a reason code, never
# raised, so the caller can turn them into a message for the user.
class ArticleExtractor
  Success = Data.define(:text) do
    def success? = true
  end

  FAILURE_REASONS = %i[blocked_address fetch_failed not_html no_content].freeze

  # reason is one of FAILURE_REASONS.
  Failure = Data.define(:reason) do
    def success? = false
  end

  # Shorter than this is a paywall, cookie wall or error page, not an article.
  MIN_LENGTH = 200
  # Keeps the prompt to roughly 10k-20k tokens; longer articles are truncated.
  MAX_LENGTH = 20_000

  HTML_TYPES = %w[text/html application/xhtml+xml].freeze
  NOISE = "script, style, noscript, template, iframe, svg, form, nav, header, footer, aside"
  BLOCKS = "p, div, section, article, h1, h2, h3, h4, h5, h6, li, pre, blockquote, tr, br"

  def self.extract(url) = new(url).extract

  def initialize(url)
    @url = url
  end

  def extract
    response = SafeHttp.fetch(@url)
    return Failure.new(:not_html) unless HTML_TYPES.include?(response.content_type)

    text = main_text(parse(response))
    text.length < MIN_LENGTH ? Failure.new(:no_content) : Success.new(text.truncate(MAX_LENGTH))
  rescue SafeHttp::BlockedAddressError => e
    failure(:blocked_address, e)
  rescue *SafeHttp::FAILURES => e
    failure(:fetch_failed, e)
  end

  private
    # The header charset wins; without one Nokogiri falls back to <meta charset>.
    def parse(response)
      Nokogiri::HTML(response.body, nil, response.type_params["charset"])
    end

    def main_text(doc)
      doc.css(NOISE).remove
      root = doc.css("article").max_by { it.text.length } || doc.at_css("main, [role=main]") || doc.at_css("body")
      return "" unless root

      # Keep paragraph breaks: end each block with a newline before taking the text.
      root.css(BLOCKS).each { it.add_next_sibling("\n") }
      root.text.lines.map(&:squish).compact_blank.join("\n")
    end

    def failure(reason, error)
      Rails.logger.info("Failed to extract #{@url}: #{error.class}: #{error.message}")
      Failure.new(reason)
    end
end
