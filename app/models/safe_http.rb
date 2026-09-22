require "net/http"
require "resolv"

# Fetches user-supplied URLs without letting them reach internal services (SSRF).
# Every hop, redirects included, must be an http(s) URL whose host resolves only
# to public addresses. The connection goes to the checked address, so a DNS
# answer that changes between the check and the connect (rebinding) cannot
# redirect it, while the Host header and TLS SNI/certificate check keep using
# the hostname.
module SafeHttp
  MAX_REDIRECTS = 3
  TIMEOUT = 10.seconds
  MAX_BODY_SIZE = 5.megabytes

  class Error < StandardError; end
  class BlockedAddressError < Error; end

  # Special-purpose ranges (RFC 6890 and the IANA registries) that are not
  # reachable, or not meant to be reachable, on the public internet.
  BLOCKED_RANGES = %w[
    0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12
    192.0.0.0/24 192.0.2.0/24 192.88.99.0/24 192.168.0.0/16 198.18.0.0/15
    198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4
    ::/128 ::1/128 ::ffff:0:0/96 64:ff9b::/96 64:ff9b:1::/48 100::/64 2001::/23
    2001:db8::/32 2002::/16 fc00::/7 fe80::/10 fec0::/10 ff00::/8
  ].map { IPAddr.new(it) }.freeze

  # Returns the response body of a successful GET, following redirects.
  # Raises SafeHttp::Error (or a network error) when the URL cannot be fetched.
  def self.get(url, redirects_left: MAX_REDIRECTS)
    uri = WebUrl.parse(url) or raise Error, "not an http(s) URL: #{url}"
    response = request(uri)

    case response
    when Net::HTTPSuccess
      response.body
    when Net::HTTPRedirection
      raise Error, "too many redirects" if redirects_left.zero?

      get(URI.join(uri, response["location"]).to_s, redirects_left: redirects_left - 1)
    else
      raise Error, "HTTP #{response.code}"
    end
  end

  def self.public_address?(ip)
    ip = IPAddr.new(ip)
    ip = ip.native # ::ffff:10.0.0.1 is 10.0.0.1
    BLOCKED_RANGES.none? { it.family == ip.family && it.include?(ip) }
  end

  def self.resolve(host)
    addresses = Resolv.getaddresses(host)
    raise Error, "cannot resolve #{host}" if addresses.empty?
    raise BlockedAddressError, "#{host} resolves to a non-public address" unless addresses.all? { public_address?(it) }

    addresses.first
  end

  def self.request(uri)
    # No proxy: going through one would bypass the address check.
    http = Net::HTTP.new(uri.hostname, uri.port, nil)
    http.ipaddr = resolve(uri.hostname)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = http.read_timeout = http.write_timeout = TIMEOUT

    http.start do
      http.request(Net::HTTP::Get.new(uri)) do |response|
        # Read the body here, capped, instead of letting Net::HTTP buffer all of it.
        body = +""
        response.read_body do |chunk|
          body << chunk
          raise Error, "response body exceeds #{MAX_BODY_SIZE} bytes" if body.bytesize > MAX_BODY_SIZE
        end
        response.body = body
      end
    end
  end
  private_class_method :resolve, :request
end
