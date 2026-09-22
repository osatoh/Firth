# Creates a user's feeds from an OPML subscription list (spec 2.3.4).
# Every feed goes through the normal model path, so URL normalisation,
# duplicate detection and the per-user limit apply exactly as for one feed.
class OpmlImport
  class InvalidFile < StandardError; end
  class TooLarge < StandardError; end

  # A real subscription list is a few KB per hundred feeds; this is generous.
  MAX_BYTES = 1.megabyte

  # Strict so that non-XML is rejected, NONET so nothing is fetched. Neither
  # DTDLOAD nor NOENT is set, so external entities are never loaded (XXE).
  PARSE_OPTIONS = Nokogiri::XML::ParseOptions::STRICT | Nokogiri::XML::ParseOptions::NONET

  Result = Data.define(:added, :duplicate, :invalid, :over_limit)

  # Takes an IO so that no more than the cap is ever read into memory.
  def initialize(user:, io:)
    @user = user
    @xml = io.read(MAX_BYTES + 1).to_s
    raise TooLarge if @xml.bytesize > MAX_BYTES
  end

  def call
    counts = Hash.new(0)
    entries = outlines

    entries.each_with_index do |(title, url), index|
      feed = @user.feeds.new(title:, url:)

      if feed.save
        counts[:added] += 1
      elsif feed.errors.of_kind?(:base, :limit_reached)
        # Nothing after this fits either, so stop instead of trying each one.
        counts[:over_limit] = entries.size - index
        break
      elsif feed.errors.of_kind?(:url, :taken)
        counts[:duplicate] += 1
      else
        counts[:invalid] += 1
      end
    end

    Result.new(**Result.members.index_with { counts[it] })
  end

  private
    # Folders are nested outlines; flatten them and keep those with a feed URL.
    def outlines
      document.xpath("/opml/body//outline[@xmlUrl]").map do |outline|
        url = outline["xmlUrl"].strip
        title = outline["title"].presence || outline["text"].presence || WebUrl.parse(url)&.host || url
        [ title.strip, url ]
      end
    end

    def document
      doc = Nokogiri::XML(@xml, nil, nil, PARSE_OPTIONS)
      raise InvalidFile unless doc.root&.name == "opml"

      doc
    rescue Nokogiri::XML::SyntaxError
      raise InvalidFile
    end
end
