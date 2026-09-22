# The one place that decides whether a string is an http(s) URL with a host:
# the only kind of URL we fetch or send a browser to.
module WebUrl
  def self.valid?(url)
    parse(url).present?
  end

  # Returns the parsed URI, or nil when the URL is not an http(s) URL with a host.
  def self.parse(url)
    uri = URI.parse(url.to_s)
    uri if uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    nil
  end
end
