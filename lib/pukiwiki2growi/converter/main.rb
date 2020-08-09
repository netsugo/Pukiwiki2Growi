# frozen_string_literal: true

module Pukiwiki2growi
  module Converter
    module Main
      module Block
        class Notation
          attr_reader :footnotes

          def footnote!(_offset)
            raise NotImplementedError
          end
        end

        class MultiLine < Notation
          def initialize
            @footnotes = []
            @lines = []
          end

          def push(element)
            @lines.push(element)
          end

          def enable_footnote
            raise NotImplementedError
          end

          def footnote!(offset)
            return unless enable_footnote

            lst = []
            @footnotes = []
            @lines.each do |line|
              ln, ls = Inline.footnote_rec(line, offset + @footnotes.size)
              lst.push(ln)
              @footnotes.concat(ls)
            end

            @lines = lst
          end
        end

        class HeadingLine < Notation
          def level
            raise NotImplementedError
          end

          def pat
            raise NotImplementedError
          end

          def element
            raise NotImplementedError
          end

          def footnote!(offset)
            @element, @footnotes = Inline.footnote_rec(@element, offset + @footnotes.size)
          end
        end

        class StaticLine < Notation
          def text
            raise NotImplementedError
          end

          def footnotes
            []
          end

          def footnote!(offset); end

          def to_s
            text
          end
        end

        class Empty < StaticLine
          def text
            ''
          end
        end

        class Paragraph < MultiLine
          def enable_footnote
            true
          end

          def to_s
            @lines.join("\n")
          end
        end

        class PreFormatted < MultiLine
          def enable_footnote
            false
          end

          def to_s
            ['```'].concat(@lines).concat(['```']).join("\n")
          end
        end

        class Table < MultiLine
          def enable_footnote
            true
          end

          def to_s
            count = 0
            count = @lines[0].count('|') unless @lines.empty?
            header = Array.new(count, '|').join('     ')
            middle = Array.new(count, '|').join(' --- ')
            [header, middle].concat(@lines).join("\n")
          end
        end

        class Heading < HeadingLine
          attr_reader :level, :element

          def initialize(level, element)
            @level = level
            @element = element
            @footnotes = []
          end

          def pat
            '#'
          end

          def to_s
            [pat * level, ' ', element].join
          end
        end

        # it doesn't look itself's forward/back quotation
        class Quote < HeadingLine
          attr_reader :level, :element

          def initialize(level, element)
            @level = level
            @element = element
            @footnotes = []
          end

          def pat
            '>'
          end

          def to_s
            [pat * level, ' ', element].join
          end
        end

        class BQuote < Quote
          attr_reader :level, :element

          def initialize(level, element)
            @level = level - 1
            @element = element
            @footnotes = []
          end

          def to_s
            if level < 1
              element
            else
              [pat * level, ' ', element].join
            end
          end
        end

        class UList < HeadingLine
          attr_reader :level, :element

          def initialize(level, element)
            @level = level - 1
            @element = element
            @footnotes = []
          end

          def pat
            '*'
          end

          def to_s
            ['  ' * level, pat, ' ', element].join
          end
        end

        class OList < UList
          attr_reader :level, :element

          def initialize(level, element)
            @level = level - 1
            @element = element
            @footnotes = []
          end

          def pat
            '1.'
          end
        end

        class Horizontal < StaticLine
          def text
            '_' * 4
          end
        end

        module Utils
          module_function

          def convert(top_page, line)
            line = Pukiwiki2growi::Converter::Pre::Line.exec(line)
            line = Inline.exec(top_page, line)
            line
          end
        end

        module SingleFactory
          module_function

          def to_element(top_page, line, head)
            [3, 2, 1].each do |n|
              next unless line.start_with?(head * n)

              element = line[n, line.size].lstrip
              return [n, Utils.convert(top_page, element)]
            end
            nil
          end

          def heading(top_page, line)
            n, element = to_element(top_page, line, '*')
            Heading.new(n, element)
          end

          def quote(top_page, line)
            n, element = to_element(top_page, line, '>')
            Quote.new(n, element)
          end

          def bquote(top_page, line)
            ignore_regex = %r{^<(div style=".*?:.*?"|/div)>}
            if line.match(ignore_regex)
              nil
            else
              n, element = to_element(top_page, line, '<')
              BQuote.new(n, element)
            end
          end

          def ulist(top_page, line)
            if line.start_with?('----')
              Horizontal.new
            else
              n, element = to_element(top_page, line, '-')
              UList.new(n, element)
            end
          end

          def olist(top_page, line)
            n, element = to_element(top_page, line, '+')
            OList.new(n, element)
          end

          def mapping
            {
              '*' => ->(tp, l) { heading(tp, l) },
              '>' => ->(tp, l) { quote(tp, l) },
              '<' => ->(tp, l) { bquote(tp, l) },
              '-' => ->(tp, l) { ulist(tp, l) },
              '+' => ->(tp, l) { olist(tp, l) }
            }
          end

          def create(top_page, line)
            if line.empty?
              Empty.new
            else
              mapping[line[0]]&.call(top_page, line)
            end
          end
        end

        module MultiFactory
          module_function

          def paragraph(conv)
            obj = Paragraph.new
            obj.push(conv)
            obj
          end

          def preformatted(conv)
            obj = PreFormatted.new
            obj.push(conv)
            obj
          end

          def table(conv)
            obj = Table.new
            obj.push(conv)
            obj
          end
        end

        class Builder
          def initialize
            @list = []
            @footnotes = nil # cache
          end

          def push_paragraph(top_page, element)
            conv = Utils.convert(top_page, element)
            if @list.last.is_a?(Paragraph)
              @list.last.push(conv)
            else
              @list.push(MultiFactory.paragraph(conv))
            end
          end

          def push_paragraph_single(top_page, line)
            if line == '~'
              push_paragraph(top_page, line)
              return
            end
            element = line[1, line.size].lstrip
            @list.push(Empty.new) if @list.last.is_a?(Paragraph)
            push_paragraph(top_page, element)
            @list.push(Empty.new)
          end

          def push_preformatted(line)
            element = line[1, line.size]
            conv = element
            if @list.last.is_a?(PreFormatted)
              @list.last.push(conv)
            else
              @list.push(MultiFactory.preformatted(conv))
            end
          end

          def push_table(top_page, line)
            element = line
            conv = Utils.convert(top_page, element)
            if @list.last.is_a?(Table)
              @list.last.push(conv)
            else
              @list.push(MultiFactory.table(conv))
            end
          end

          def multi_mapping
            {
              '~' => ->(tp, l) { push_paragraph_single(tp, l) },
              ' ' => ->(_, l) { push_preformatted(l) },
              '|' => ->(tp, l) { push_table(tp, l) }
            }
          end

          def push(top_page, line)
            single = SingleFactory.create(top_page, line)
            if single.nil?
              handler = multi_mapping[line[0]] || ->(tp, l) { push_paragraph(tp, l) }
              handler.call(top_page, line)
            else
              @list.push(single)
            end
          end

          def to_s
            if @footnotes.nil?
              footnotes = []
              @list.each do |obj|
                obj.footnote!(footnotes.size)
                footnotes.concat(obj.footnotes)
              end
              @footnotes = footnotes
            end
            @list.map(&:to_s)
                 .concat(@footnotes.map.with_index { |s, n| "[^#{n + 1}]:#{s}" })
                 .join("\n")
          end
        end

        module_function

        def exec(top_page, body)
          builder = Builder.new
          body.split("\n", -1).each { |line| builder.push(top_page, line) }
          builder.to_s
        end
      end

      module Inline
        module_function

        def br(line)
          line.gsub(/~$/, ' ' * 2)
              .gsub('&br;&br;', "\n\n")
              .gsub('&br;', "  \n")
        end

        def decorate(pat, head_size, tail_size, handlers, text)
          handlers.each do |n, text_handler|
            if head_size >= n && tail_size >= n
              return [
                pat * (head_size - n),
                text_handler.call(text),
                pat * (tail_size - n)
              ].join
            end
          end

          text
        end

        def line_decoration(pat, handlers, line)
          line.gsub(/(#{pat}{2,})(.*?)(#{pat}{2,})/) do
            head = Regexp.last_match(1)
            text = Regexp.last_match(2)
            tail = Regexp.last_match(3)

            decorate(pat, head.size, tail.size, handlers, text)
          end.lstrip
        end

        def em_strong(line)
          handlers = {
            5 => ->(text) { " ***#{text.strip}*** " },
            3 => ->(text) { " *#{text.strip}* " },
            2 => ->(text) { " **#{text.strip}** " }
          }

          line_decoration("'", handlers, line)
        end

        # strike
        def text_line(line)
          handlers = {
            2 => ->(text) { " ~~#{text.strip}~~ " }
          }

          line_decoration('%', handlers, line)
        end

        def fix_link(top_page, link)
          # InterWiki
          if link.match(/^([A-Z][a-z]+)+?:(.+)/)
            link
          # absolute/relative path | URI
          elsif link.match(%r{(?:^\.{0,2}/)|(?:^[a-z]+?://([\w\-]+\.)+\w+(/[\w\-./?%&=]*)?$)})
            link
          elsif link.match(/^\w+([-+.]\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*$/)
            "mailto:#{link}"
          else
            File.join(top_page, link)
          end
        end

        def page_link_alias(top_page, line)
          line.gsub(/\[\[(.+?)(?:([>:])(.+?))?\]\]/) do
            name = Regexp.last_match(1)
            link = Regexp.last_match(3) || name
            link = fix_link(top_page, link)
            Plugin::Block.md_link(name, link)
          end
        end

        def footnote_rec_single(line, offset, list)
          footnote = nil
          index = (offset.negative? ? 0 : offset) + list.size + 1

          line = line.sub(/\(\(((?:\g<0>|[^()])*)\)\)/) do
            footnote = Regexp.last_match(1)
            "[^#{index}]"
          end

          lst = footnote.nil? ? [] : footnote_rec_single(footnote, offset + 1, list).flatten
          [line, lst]
        end

        def footnote_rec(line, offset = 0, list = [])
          ls, lst = footnote_rec_single(line, offset, list)
          lst.empty? ? [line, list] : footnote_rec(ls, offset, list.concat(lst))
        end

        def exec(top_page, line)
          line = Misc.comment(line)
          line = Misc.del_hash(line)
          line = em_strong(line)
          line = text_line(line)
          line = page_link_alias(top_page, line)
          line = br(line)
          line
        end
      end

      module Misc
        module_function

        def comment(line)
          line.gsub(%r{^//(.*)}) { "<!--#{Regexp.last_match(1)}-->" }
        end

        def del_hash(line)
          line.gsub(/(?: *\[#[0-9a-z]+?\])$/, '')
        end
      end

      module_function

      def exec(top_page, body)
        Block.exec(top_page, body)
      end
    end
  end
end
