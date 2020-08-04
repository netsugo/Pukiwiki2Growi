# frozen_string_literal: true

module Pukiwiki2growi
  module Converter
    module Pre
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
              case args[1]
              when 'reverse'
                "$lsx(#{args[0]}, reverse=true)"
              else
                ls2([args[0]])
              end
            end
          end

          def shadowheader(args)
            return nil if args.nil?

            if args.size < 2
              super(args)
            else
              num = args[0].to_i
              txt = args[1]
              "#{'#' * num} #{txt}"
            end
          end

          def ref(args)
            return nil if args.nil? || args.empty?

            name = args[0]
            ext = File.extname(name)
            name.gsub!(%r{(^\./)(.+)}) do
              Regexp.last_match(2)
            end
            if %w[.gif .jpeg .jpg .png .svg .webp].include?(ext.downcase)
              "![#{name}](#{name})"
            else
              "[#{name}](#{name})"
            end
          end

          def exec(line)
            static = {
              'contents' => '@[toc]',
              'hr' => '_' * 4,
              'br' => "\n"
            }.map { |k, v| [k, ->(_) { v }] }.to_h
            dynamic = {
              'ls' => ->(_) { ls2(nil) },
              'ls2' => ->(args) { ls2(args) },
              'shadowheader' => ->(args) { shadowheader(args) },
              'ref' => ->(args) { ref(args) }
            }
            Converter::Plugin.block(static.merge(dynamic), line)
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

          def exec(line)
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
              'ref' => ->(args, _) { Converter::Pre::Plugin::Block.ref(args) }
            }
            Converter::Plugin.inline(static.merge(dynamic), line)
          end
        end

        module_function

        def exec(line)
          line = Block.exec(line)
          line = Inline.exec(line)
          line
        end
      end

      module Body
        module_function

        # #pre{{......}}
        def convert_preformat(body)
          body.gsub(/(^[#]pre{{)(.+)(\n}})/) do
            Regexp.last_match(2).split("\n").map { |s| " #{s}" }.join("\n")
          end
        end

        def convert_table_csv(body)
          body.gsub(/(^,.*)(\n,.*)*/) do
            header = ":::csv\n"
            ctable = Regexp.last_match(0)
            footer = "\n:::"
            [header, ctable, footer].join
          end
        end

        def div_style(key, value, element)
          header = "<div style=\"#{key}:#{value}\">"
          footer = '</div>'
          [header, element, footer].join("\n")
        end

        # LEFT:...
        # CENTER:...
        # RIGHT:...
        def text_align(body)
          body.gsub(/^(LEFT|CENTER|RIGHT):((.*)(\n(?!(LEFT:|RIGHT:|CENTER:|[~><\-\+: \n])).*)*)/) do
            align = Regexp.last_match(1).downcase
            element = Regexp.last_match(2)
            div_style('text-align', align, element)
          end
        end

        def exec(body)
          body = convert_preformat(body)
          body = convert_table_csv(body)
          body = text_align(body)
          body
        end
      end

      module Line
        module_function

        def dlist(line)
          # TODO: implement
          line
        end

        def exec(line)
          line = Plugin.exec(line)
          line = dlist(line)
          line
        end
      end

      module_function

      def exec(body)
        Body.exec(body).split("\n", -1).map do |line|
          if line.start_with?(' ')
            line
          else
            Line.exec(line)
          end
        end.join("\n")
      end
    end
  end
end
