# Frozen-string-literal: true
# Copyright: 2012 - 2017 - MIT License
# Encoding: utf-8

require "fastimage"
require_relative "html"
require "liquid/tag/parser"
require "active_support/hash_with_indifferent_access"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/hash/deep_merge"
require_relative "default"
require_relative "proxy"
require "nokogiri"

module Jekyll
  module Assets
    class Tag < Liquid::Tag
      class << self
        public :new
      end

      # --
      class MixedArg < StandardError
        def initialize(arg, mixed)
          super "cannot use #{arg} w/ #{mixed}"
        end
      end

      # --
      class InvalidExternal < StandardError
        def initialize(arg)
          super "cannot use `#{arg}' with external url's"
        end
      end

      # --
      attr_reader :name
      attr_reader :tokens
      attr_reader :args
      attr_reader :tag

      # --
      def initialize(tag, args, tokens)
        @tag = tag.to_sym
        @args = Liquid::Tag::Parser.new(args)
        @tokens = tokens
        @og_args = args
        super
      end

      # --
      # @return [String]
      # Render the tag, run the proxies, set the defaults.
      # @note Defaults are ran twice just incase the content type
      #   changes, at that point there might be something that
      #   has to change in the new content.
      # --
      def render(ctx)
        env  = ctx.registers[:site].sprockets
        args = env.parse_liquid(@args, ctx: ctx)
        raise Sprockets::FileNotFound, "UNKNOWN" unless args.key?(:argv1)
        asset = external(ctx, args: args) if env.external?(args)
        asset ||= internal(ctx)

        return_or_build(ctx, args: args, asset: asset) do
          HTML.build({
            args: args,
            asset: asset,
            ctx: ctx,
          })
        end
      rescue Sprockets::FileNotFound => e
        env.logger.error @args.to_h(html: false).inspect
        env.logger.debug  args.to_h(html: false).inspect
        raise e
      end

      # --
      def return_or_build(ctx, args:, asset:)
        methods.grep(%r!^on_(?\!or_build$)!).each do |m|
          out = send(m, args, ctx: ctx, asset: asset)
          if out
            return out
          end
        end

        yield
      end

      # --
      # Returns the path to the asset.
      # @example {% asset img.png @path %}
      # @return [String]
      # --
      def on_path(args, ctx:, asset:)
        env = ctx.registers[:site].sprockets
        if args[:path]
          raise InvalidExternal, "@path" if env.external?(args)
          env.prefix_url(asset.digest_path)
        end
      end

      # --
      # Returns the data uri of an object.
      # @example {% asset img.png @data-url %}
      # @example {% asset img.png @data_uri %}
      # @return [String]
      # --
      def on_data_url(args, ctx:, asset:)
        env = ctx.registers[:site].sprockets
        if args[:data]
          raise InvalidExternal, "@data" if env.external?(args)
          asset.data_uri
        end
      end

      # --
      # @param [Liquid::Context] ctx
      # Set's up an external url using `Url`
      # @return [Url]
      # --
      def external(ctx, args:)
        env = ctx.registers[:site].sprockets
        out = env.external_asset(args[:argv1], args: args)
        Default.set(args, {
          ctx: ctx, asset: out
        })

        out
      end

      # --
      # @param [Liquid::Context] ctx
      # Set's up an internal asset using `Sprockets::Asset`
      # @return [Sprockets::Asset]
      # --
      def internal(ctx)
        env = ctx.registers[:site].sprockets
        original = env.find_asset!(args[:argv1])
        Default.set(args, ctx: ctx, asset: original)
        out = Proxy.proxy(original, args: args, ctx: ctx)
        env.manifest.compile(out.logical_path)

        Default.set(args, {
          ctx: ctx, asset: out
        })

        out
      end
    end
  end
end

# --

Liquid::Template.register_tag "asset", Jekyll::Assets::Tag
