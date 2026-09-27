# frozen_string_literal: true

require "open-uri"
require "socket"
require "ipaddr"

# Downloads files from third-party URLs (crawled pages), so the URL is untrusted input.
module RemoteFile
  Error = Class.new(StandardError)

  MAX_BYTES = 200.megabytes
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"

  module_function

  # Returns an IO that responds to #content_type.
  # ponytail: the host is checked once before the request; a redirect or DNS rebind can still land on a private
  # address. Upgrade: connect to the pre-resolved IP and re-check every redirect hop.
  def fetch(url)
    uri = URI.parse(url.to_s)
    raise Error, "Only http(s) URLs can be downloaded." unless uri.is_a?(URI::HTTP) && uri.host.present?

    addresses = Addrinfo.getaddrinfo(uri.host, nil, nil, :STREAM).map(&:ip_address)
    raise Error, "#{uri.host} is not a public address." if addresses.any? { |address| private_address?(address) }

    uri.open(
      "User-Agent" => USER_AGENT,
      open_timeout: 10,
      read_timeout: 30,
      content_length_proc: ->(length) { raise Error, "File is too large." if length && length > MAX_BYTES }
    )
  rescue URI::InvalidURIError, OpenURI::HTTPError, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => e
    raise Error, e.message
  end

  def filename(url)
    File.basename(URI.parse(url.to_s).path.to_s).presence || "download"
  rescue URI::InvalidURIError
    "download"
  end

  def private_address?(address)
    ip = IPAddr.new(address).native
    ip.private? || ip.loopback? || ip.link_local? || ip.to_i.zero?
  end
end
