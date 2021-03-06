# Frozen-string-literal: true
# Copyright: 2012 - 2017 - MIT License
# Encoding: utf-8

module Jekyll
  module Assets
    module Utils
      # --
      def url_asset(url, type:)
        name = File.basename(url)
        old_ = Env.old_sprockets?

        Url.new(*[old_ ? self : nil, {
          name: name,
          filename: url,
          content_type: type,
          load_path: File.dirname(url),
          id: Digest::SHA256.hexdigest(url),
          logical_path: name,
          metadata: {},
          source: "",
          uri: url,
        }].compact)
      end

      # --
      # @param [String] url
      # @return [Sprockets::Asset]
      # Wraps around an external url and so it can be wrapped into
      #  the rest of Jekyll-Assets with little trouble.
      # --
      def external_asset(url, args:)
        if args[:asset]&.key?(:type)
          url_asset(url, {
            type: args[:asset][:type],
          })

        else
          _, type = Sprockets.match_path_extname(url, Sprockets.mime_exts)
          logger.debug "no type for #{url}, assuming image/*" unless type
          url_asset(url, {
            type: type || "image/jpeg",
          })
        end
      end

      # --
      # @param [String,Sprockets::Asset] url
      # Tells you if a url... or asset is external.
      # @return [nil,true,false]
      # --
      def external?(args)
        return true  if args.is_a?(Url)
        return false if args.is_a?(Sprockets::Asset)
        return args =~ %r!^(https?:)?//! if args.is_a?(String)
        return args[:external] if args.key?(:external)
        args[:argv1] !~ %r!^(?\!(https?:)?//)!
      end

      # --
      # @param [String,Hash<>,Array<>] obj the liquid to parse.
      # Parses the Liquid that's being passed, with Jekyll's context.
      # rubocop:disable Lint/LiteralAsCondition
      # @return [String]
      # --
      def parse_liquid(obj, ctx:)
        case true
        when obj.is_a?(Hash) || obj.is_a?(Liquid::Tag::Parser)
          obj.each_key.with_object(obj) do |k, o|
            if o[k].is_a?(String)
              then o[k] = parse_liquid(o[k], {
                ctx: ctx,
              })
            end
          end
        when obj.is_a?(Array)
          obj.map do |v|
            if v.is_a?(String)
              then v = parse_liquid(v, {
                ctx: ctx,
              })
            end

            v
          end
        else
          ctx.registers[:site].liquid_renderer.file("(asset:var)")
            .parse(obj).render!(ctx)
        end
      end

      # --
      # @param [String] path the path to strip.
      # Strips most source paths from the given path path.
      # rubocop:enable Lint/LiteralAsCondition
      # @return [String]
      # --
      def strip_paths(path)
        paths.map do |v|
          if path.start_with?(v)
            return path.sub(v + "/", "")
          end
        end

        path
      end

      # --
      # Lands your path inside of the cache directory.
      # @note configurable with `caching: { path: "dir_name"` }
      # @return [String]
      # --
      def in_cache_dir(*paths)
        path = Pathutil.pwd.join(strip_slashes(asset_config[:caching][:path]))
        paths.reduce(path.to_s) do |b, p|
          Jekyll.sanitized_path(b, p)
        end
      end

      # --
      # @note this is configurable with `:destination`
      # Lands your path inside of the destination directory.
      # @param [Array<String>] paths the paths.
      # @return [String]
      # --
      def in_dest_dir(*paths)
        destination = strip_slashes(asset_config[:destination])

        paths.unshift(destination)
        paths = paths.flatten.compact
        jekyll.in_dest_dir(*paths)
      end

      # --
      # @param [String] the path.
      # @note this should only be used for *urls*
      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/PerceivedComplexity
      # rubocop:disable Metrics/AbcSize
      # Builds a url path for HTML.
      # @return [String]
      # --
      def prefix_url(user_path = nil)
        dest = strip_slashes(asset_config[:destination])
        cdn = make_https(strip_slashes(asset_config[:cdn][:url]))
        base = strip_slashes(jekyll.config["baseurl"])
        cfg = asset_config

        path = []
        path << cdn  if Jekyll.production? && cdn
        path << base if Jekyll.dev? || !cdn || (cdn && cfg[:cdn][:baseurl])
        path << dest if Jekyll.dev? || !cdn || (cdn && cfg[:cdn][:destination])
        path << user_path unless user_path.nil? || user_path == ""

        path = File.join(path.flatten.compact)
        return path if cdn && Jekyll.production?
        "/" + path
      end

      # --
      # param [String] the content type
      # Strips the secondary content from type.
      # rubocop:enable Metrics/PerceivedComplexity
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/AbcSize
      # @return [String]
      # --
      module_function
      def strip_secondary_content_type(str)
        str = str.split("/")
        raise ArgumentError, "#{str.join('/')} is invalid." if str.size > 2
        File.join(str[0], str[1].rpartition(%r!\+!).last)
      end

      # --
      # @param [String] path the path.
      # Strip the start and end slashes in a path.
      # @return [String]
      # --
      module_function
      def strip_slashes(path)
        return if path.nil? || path == ""
        path.gsub(%r!^/|/$!, "")
      end

      # --
      # @param [String] url the url.
      # Make a url a proper url, and an https url.
      # @return [String]
      # --
      module_function
      def make_https(url)
        return if url.nil? || url == ""
        url.gsub(%r!(https?:)?//!,
          "https://")
      end

      # --
      # Get all the manifest files.
      # @note this includes dynamic keys, like SourceMaps.
      # rubocop:disable Metrics/AbcSize
      # @return [Array<String>]
      # --
      module_function
      def manifest_files(env)
        manifest = env.manifest.data.values_at(*Manifest.keep_keys).map(&:to_a)
        out = manifest.flatten.each_with_object([]) do |v, a|
          path = Pathutil.new(env.in_dest_dir(v))
          a << path.to_s + ".gz" if path.exist? && !env.skip_gzip?
          a << path.to_s if path.exist?
          v = Pathutil.new(v)

          next if v.dirname == "."
          v.dirname.descend.each do |vv|
            vv = env.in_dest_dir(vv)
            unless a.include?(vv)
              a << vv
            end
          end
        end

        out
      end

      # --
      # rubocop:enable Metrics/AbcSize
      # Either require the file or keep moving along.
      # @yield a block of code if the require works out.
      # @param [String] file the file to require.
      # @return [nil]
      # --
      module_function
      def try_require(file)
        require file
        if block_given?
          yield
        end
      rescue LoadError
        Logger.debug "Unable to load file `#{file}'"
      end

      # --
      # @yield a blockof code if the require works out.
      # Either require exec.js, and the file or move along.
      # @param [String] file the file to require.
      # @return [nil]
      # --
      module_function
      def javascript?
        require "execjs"
        if block_given?
          yield
        end
      rescue ExecJS::RuntimeUnavailable
        nil
      end

      # --
      # @param [Jekyll::Site] site
      # @param [Hash<Symbol,Object>] payload
      # Try to replicate and run hooks the Jekyll would normally run.
      # rubocop:disable Metrics/LineLength
      # @return nil
      # --
      def run_liquid_hooks(payload, site)
        Hook.trigger(:liquid, :pre_render) { |h| h.call(payload, site) }
        post, page, doc = get_liquid_obj(payload, site)

        # I would assume most people set in :pre_render logically?
        Jekyll::Hooks.trigger(:posts, :pre_render, post, payload) if post
        Jekyll::Hooks.trigger(:documents, :pre_render, post || doc, payload) if post || doc
        Jekyll::Hooks.trigger(:pages, :pre_render, page, payload) if page
      end

      # --
      # @param [Jekyll::Site] site
      # @param [Hash<Symbol,Object>] payload
      # Discovers the Jekyll object, corresponding to the type.
      # @note this allows us to trigger hooks that Jekyll would trigger.
      # @return [Jekyll::Document, Jekyll::Page]
      # rubocop:disable Layout/ExtraSpacing
      # --
      def get_liquid_obj(payload, site)
        path = payload["path"]

        post = site.posts.docs.find { |v| v.relative_path == path }
        docs = site. documents.find { |v| v.relative_path == path } unless post
        page = site.     pages.find { |v| v.relative_path == path } unless docs

        [
          post,
          page,
          docs,
        ]
      end
    end
  end
end
