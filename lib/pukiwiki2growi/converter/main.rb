# frozen_string_literal: true

module Pukiwiki2growi
  module Converter
    module Main
      module Block
        class Notation
          attr_accessor :top_page
          attr_reader :footnotes

          def initialize
            @footnotes = []
            @top_page = ''
          end

          def convert(line)
            line = Pukiwiki2growi::Converter::Pre::Line.exec(line)
            line = Inline.exec(top_page, line)
            line
          end

          def footnote!(offset); end
        end

        class Empty < Notation
          def to_s
            ''
          end
        end

        class MultiLine < Notation
          def initialize
            @lines = []
            @footnotes = []
          end

          def to_element(line)
            line
          end

          def push(line)
            element = to_element(line)
            @lines.push(element)
          end

          def self.create(line)
            obj = new
            obj.push(line)
            obj
          end

          def footnote!(offset)
            lst = []
            @lines.each do |line|
              ln, ls = Inline.footnote_rec(line, offset + @footnotes.size)
              lst.push(ln)
              @footnotes.concat(ls)
            end

            @lines = lst
          end

          def to_s
            @lines.map { |s| convert(s) }.join("\n")
          end
        end

        class Paragraph < MultiLine
        end

        class PreFormatted < MultiLine
          def to_element(line)
            line[1, line.size]
          end

          def convert(line)
            line
          end

          def footnote!(offset); end

          def to_s
            ['```', super, '```'].join("\n")
          end
        end

        class Table < MultiLine
          def to_s
            count = 0
            count = @lines[0].count('|') unless @lines.empty?
            header = Array.new(count, '|').join('     ')
            middle = Array.new(count, '|').join(' --- ')
            [header, middle, super].join("\n")
          end
        end

        class Heading < Notation
          def initialize(level, element)
            @level = level
            @element = convert(element)
            @replace = '#'
            @footnotes = []
          end

          def self._create(line, head)
            [3, 2, 1].each do |n|
              return new(n, line[n, line.size].lstrip) if line.start_with?(head * n)
            end
            nil
          end

          def self.create(line)
            _create(line, '*')
          end

          def footnote!(offset)
            @element, @footnotes = Inline.footnote_rec(@element, offset + @footnotes.size)
          end

          def to_s
            [@replace * @level, ' ', @element].join
          end
        end

        # it doesn't look itself's forward/back quotation
        class Quote < Heading
          def initialize(level, element)
            super(level, element)
            @replace = '>'
          end

          def self.create(line)
            _create(line, '>')
          end
        end

        class BQuote < Quote
          def self.create(line)
            _create(line, '<')
          end

          def to_s
            level = @level - 1
            if level < 1
              @element
            else
              [@replace * level, ' ', @element].join
            end
          end
        end

        class UList < Heading
          def initialize(level, element)
            super(level, element)
            @replace = '*'
            @padding = '  '
          end

          def self.create(line)
            _create(line, '-')
          end

          def to_s
            [@padding * (@level - 1), @replace, ' ', @element].join
          end
        end

        class OList < UList
          def initialize(level, element)
            super(level, element)
            @replace = '1.'
          end

          def self.create(line)
            _create(line, '+')
          end
        end

        class Horizontal < Notation
          def to_s
            '_' * 4
          end
        end

        class Page
          def initialize
            @list = []
            @footnotes = []
          end

          def push_paragraph(line, single = false)
            if single
              @list.push(Empty.new) if @list.last.is_a?(Paragraph)
              @list.push(Paragraph.create(line[1, line.size].lstrip))
              @list.push(Empty.new)
            elsif @list.last.is_a?(Paragraph)
              @list.last.push(line)
            else
              @list.push(Paragraph.create(line))
            end
          end

          def push_preformatted(line)
            if @list.last&.is_a?(PreFormatted)
              @list.last.push(line)
            else
              @list.push(PreFormatted.create(line))
            end
          end

          def push_table(line)
            if @list.last&.is_a?(Table)
              @list.last.push(line)
            else
              @list.push(Table.create(line))
            end
          end

          def push_bquote(line)
            ignore_regex = %r{^<(div style=".*?:.*?"|/div)>}
            if line.match(ignore_regex)
              push_paragraph(line)
            else
              @list.push(BQuote.create(line))
            end
          end

          def mapping
            {
              '~' => ->(line) { push_paragraph(line, line != '~') },
              '>' => ->(line) { @list.push(Quote.create(line)) },
              '<' => ->(line) { push_bquote(line) },
              '-' => ->(line) { @list.push(line.start_with?('----') ? Horizontal.new : UList.create(line)) },
              '+' => ->(line) { @list.push(OList.create(line)) },
              ' ' => ->(line) { push_preformatted(line) },
              '|' => ->(line) { push_table(line) },
              '*' => ->(line) { @list.push(Heading.create(line)) }
            }
          end

          def push(line)
            if line.empty?
              @list.push(Empty.new)
            else
              mapping[line[0]]&.call(line) || push_paragraph(line)
            end
          end

          def footnote!
            @list.each do |obj|
              obj.footnote!(@footnotes.size)
              @footnotes.concat(obj.footnotes)
            end
          end

          def insert_top_page!(top_page)
            @list.each { |obj| obj.top_page = top_page }
          end

          def to_s
            @list.map(&:to_s)
                 .concat(@footnotes.map.with_index { |s, n| "[^#{n + 1}]:#{s}" })
                 .join("\n")
          end
        end

        module_function

        def exec(top_page, body)
          page = Page.new
          body.split("\n", -1).each { |line| page.push(line) }
          page.insert_top_page!(top_page)
          page.footnote!
          page.to_s
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
