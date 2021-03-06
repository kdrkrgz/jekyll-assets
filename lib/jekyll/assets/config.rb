# Frozen-string-literal: true
# Copyright: 2012 - 2017 - MIT License
# Encoding: utf-8

require "jekyll"
require "active_support/hash_with_indifferent_access"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/hash/deep_merge"
require_relative "hook"

module Jekyll
  module Assets
    class Config < HashWithIndifferentAccess
      DEVELOPMENT = {
        digest: false,
        source_maps: true,
        subresource_integrity: false,
        destination: "/assets",
        compression: true,
        gzip: false,

        caching: {
          enabled: true,
          path: ".jekyll-cache/assets",
          type: "file",
        },

        precompile: [
          #
        ],

        cdn: {
          baseurl: false,
          destination: false,
          url: nil,
        },

        sources: %w(
          assets/css
          assets/fonts
          assets/images
          assets/videos
          assets/javascript
          assets/video
          assets/image
          assets/img
          assets/js

          _assets/css
          _assets/fonts
          _assets/images
          _assets/videos
          _assets/javascript
          _assets/video
          _assets/image
          _assets/img
          _assets/js

          css
          fonts
          images
          videos
          javascript
          video
          image
          img
          js
        ),
      }.freeze

      PRODUCTION = DEVELOPMENT.deep_merge({
        source_maps: false,
      }).freeze

      # --
      def initialize(config)
        super(self.class.defaults)
        Hook.trigger(:config, :before_merge) { |h| h.call(self) }
        deep_merge!(config)
        merge_sources!
      end

      # --
      # @return [HashWithIndifferentAccess]
      # @note this is useful if you are in safe mode.
      # The original defaults we have set.
      # --
      def self.defaults
        Jekyll.dev? ? DEVELOPMENT : PRODUCTION
      end

      # --
      # Merge our sources with their sources.
      # @note we don't really allow users to remove our sources.
      # @return [nil]
      # --
      private
      def merge_sources!
        ours = self.class.defaults[:sources]
        theirs = [self[:sources] || []].flatten.compact
        self[:sources] = theirs | ours
      end
    end
  end
end
