module Middleware
  class EucJpUrlFixer
    def initialize(app)
      @app = app
    end

    def call(env)
      path = env["PATH_INFO"]

      if path
        # 1. Handle Raw Bytes (Invalid UTF-8 in PATH_INFO itself)
        if !path.valid_encoding?
          path.force_encoding(Encoding::ASCII_8BIT)
          # Convert raw high-bit bytes to %25HH
          # We use %25 because we want Rails to decode it to "%HH" string, not raw byte.
          path = path.gsub(/[^[:ascii:]]/) do |match|
            "%25" + match.unpack1("H*").upcase
          end
          env["PATH_INFO"] = path
        end

        # 2. Handle Encoded EUC-JP (Valid ASCII PATH_INFO, but decodes to invalid UTF-8)
        # Check for percent-encoded high-bit bytes (0x80-0xFF)
        # These correspond to %80-%FF. Regex: %[89A-F][0-9A-F]
        if path.match?( /%[89a-fA-F][0-9a-fA-F]/ )
           # Double-encode these specific sequences to preserve them as literal "%HH" strings
           # after Rails decoding.
           # e.g. "%B7" -> "%25B7" -> Rails decodes to "%B7"
           env["PATH_INFO"] = path.gsub( /%(?=[89a-fA-F][0-9a-fA-F])/ , "%25")
        end
      end

      @app.call(env)
    end
  end
end
