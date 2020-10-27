# frozen_string_literal: true

module Pukiwiki2growi
  module Converter
    module Plugin
      module Block
        module_function

        def ls2(args)
          return '$lsx()' if args.nil?

          case args.size
          when 0
            ls2(nil)
          when 1
            "$lsx(#{args[0]})"
          else
            head = args[0] # not nil
            tail = args[1..-1] # index 1 to last
            new_args = []
            new_args << head if !head.nil? && !head.empty?
            new_args << 'reverse=true' if tail.include?('reverse')
            "$lsx(#{new_args.join(', ')})"
          end
        end

        def md_link(name, link)
          ext = File.extname(link)
          if %w[.gif .jpeg .jpg .png .svg .webp].include?(ext.downcase)
            "![#{name}](#{link})"
          else
            "[#{name}](#{link})"
          end
        end

        def ref(args)
          return nil if args.nil? || args.empty?

          name = args[0]
          ext = File.extname(name)

          file_ignore = %w[left center right wrap nowrap]
          common_ignore = %w[nolink around]
          ignore = common_ignore.concat(ext.empty? ? [] : file_ignore)
          opts = args.slice(1, args.size)
          loop do
            break if opts.empty?
            break unless ignore.include?(opts[0])

            opts.shift
          end

          alt_name = opts.empty? ? name : opts.join(',')

          name.gsub!(%r{(^\./)(.+)}) do
            Regexp.last_match(2)
          end

          md_link(alt_name, name)
        end

        # custom: { 'plugin1' => lambda |args| { ... }, 'plugin2' => lambda |args| { ... }, ... }
        def exec(line, custom = {})
          static = {
            'contents' => '@[toc]',
            'hr' => '_' * 4,
            'br' => "\n"
          }.map { |k, v| [k, ->(_) { v }] }.to_h
          dynamic = {
            'ls' => ->(_) { ls2(nil) },
            'ls2' => ->(args) { ls2(args) },
            'ref' => ->(args) { ref(args) }
          }
          Converter::Plugin.block(static.merge(dynamic).merge(custom), line)
        end
      end

      module Inline
        module_function

        # inline
        def htag(name, args, inline)
          attribute = args.map { |k, v| " #{k}=\"#{v}\"" }.join
          "<#{name}#{attribute}>#{inline}</#{name}>"
        end

        def span_style(style_args, inline)
          style = style_args.map { |k, v| "#{k}:#{v}" }.join(';')
          htag('span', { 'style' => style }, inline)
        end

        def size(args, inline)
          return nil if args.nil? || inline.nil?

          case args.size
          when 0
            inline
          else
            span_style({ 'font-size' => "#{args[0]}px" }, inline)
          end
        end

        def color_style(color, bgcolor, inline)
          style_args = { 'color' => color }
          style_args['bgcolor'] = bgcolor unless bgcolor.nil?
          span_style(style_args, inline)
        end

        def color(args, inline)
          return nil if args.nil? || (args.size < 2 && inline.nil?)

          case args.size
          when 0
            inline
          when 1
            color_style(args[0], nil, inline)
          else
            if inline.nil?
              color([args[0]], args[1])
            else
              color_style(args[0], args[1], inline)
            end
          end
        end

        def ruby(args, inline)
          return nil if args.nil? || inline.nil?

          case args.size
          when 0
            inline
          else
            content = [inline, htag('rp', {}, '('), htag('rt', {}, args[0]), htag('rp', {}, ')')].join
            htag('ruby', {}, content)
          end
        end

        # custom: { 'plugin1' => lambda |args, inline| { ... }, 'plugin2' => lambda |args, inline| { ... }, ... }
        def exec(line, custom = {})
          static = {
            'heart' => ':heart:',
            'smile' => ':smiley:',
            'bigsmile' => ':laughing:',
            'huh' => ':stuck_out_tongue:',
            'oh' => ':angry:',
            'wink' => ':wink:',
            'sad' => ':worried:',
            'worried' => ':cold_sweat:',
            't' => "\t"
          }.map { |k, v| [k, ->(_, _) { v }] }.to_h
          dynamic = {
            'color' => ->(args, inline) { color(args, inline) },
            'size' => ->(args, inline) { size(args, inline) },
            'ruby' => ->(args, inline) { ruby(args, inline) },
            'ref' => ->(args, _) { Converter::Plugin::Block.ref(args) }
          }
          Converter::Plugin.inline(static.merge(dynamic).merge(custom), line)
        end
      end

      module_function

      def unknown_block(name, args)
        [
          "##{name}",
          (args.nil? ? '' : "(#{args.join(',')})")
        ].join
      end

      def unknown_inline(name, args, inline)
        [
          "&#{name}",
          (args.nil? ? '' : "(#{args.join(',')})"),
          (inline.nil? ? '' : "{#{inline}}"),
          ';'
        ].join
      end

      def block(mapping, line)
        line.gsub(/^#([0-9a-zA-Z_]+)(\(([^\n]*)\).*)?/) do
          name = Regexp.last_match(1)&.downcase
          args = Regexp.last_match(3)&.split(',')&.map(&:strip)
          mapping[name]&.call(args) || unknown_block(name, args)
        end
      end

      # circular recursion
      # &plugin(args){&plugin(args){inline};&plugin(args);};
      def inline_rec_short(mapping, line)
        regex = /(?:&([0-9a-zA-Z_]+)(?:\(([^\)]+)\))?(?:{(.+)})?;)/
        line.gsub(regex) do
          name = Regexp.last_match(1)&.downcase
          args = Regexp.last_match(2)&.split(',')&.map(&:strip)
          pre_inline = Regexp.last_match(3)
          inline = pre_inline.nil? ? pre_inline : inline(mapping, pre_inline)
          mapping[name]&.call(args, inline) || unknown_inline(name, args, inline)
        end
      end

      # &plugin(args){inline};&plugin(args){inline};
      def inline(mapping, line)
        regex = /(?:&([0-9a-zA-Z_]+)(?:\(([^\)]+)\))?(?:{((?:\g<0>|.)*?)})?;)/
        line.gsub(regex) do
          inline_rec_short(mapping, Regexp.last_match(0))
        end
      end

      def exec(line)
        block_custom = {
          'shadowheader' => lambda { |args|
            args.nil? || args.size < 2 ? nil : "#{'#' * args[0].to_i} #{args[1]}"
          }
        }
        line = Block.exec(line, block_custom)
        line = Inline.exec(line)
        line
      end
    end
  end
end
