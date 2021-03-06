# Frozen-string-literal: true
# Copyright: 2012 - 2017 - MIT License
# Encoding: utf-8

require "jekyll/assets"

module Jekyll
  module Assets
    class Default
      class Img < Default
        content_types "image/bmp"
        content_types "image/webp"
        content_types "image/svg+xml"
        content_types "image/jpeg"
        content_types "image/tiff"
        content_types "image/gif"
        content_types "image/png"
        content_types "image/jpg"

        def set_src
          unless @args[:inline]
            return @args[:src] = @asset.url if @asset.is_a?(Url)
            @args[:src] = @env.prefix_url(@asset
              .digest_path)
          end
        end

        def set_integrity
          return if @asset.is_a?(Url)
          @args[:integrity] = @asset.integrity
          unless @args.key?(:crossorigin)
            @args[:crossorigin] = "anonymous"
          end
        end
      end
    end
  end
end
