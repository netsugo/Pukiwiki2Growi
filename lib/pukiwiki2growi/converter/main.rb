# frozen_string_literal: true

module Pukiwiki2growi
  module Converter
    module Main
      module Block
        class Empty
          def to_s
            ''
          end
        end
        class MultiLine
          def initialize
            @lines = []
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

          def to_s
            @lines.join("\n")
          end
        end
        class Paragraph < MultiLine
        end
        class PreFormatted < MultiLine
          def to_element(line)
            line[1, line.size]
          end

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
        class Quote
          # TODO: implement
        end
        class BQuote
          # TODO: implement
        end
        class Heading
          def initialize(level, element)
            @level = level
            @element = element
            @replace = '#'
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

          def to_s
            [@replace * @level, ' ', element].join
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
        class Horizontal
          def to_s
            '_' * 4
          end
        end
        class Page
          def initialize
            @list = []
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

          def mapping
            {
              '~' => ->(line) { push_paragraph(line, true) },
              '>' => nil,
              '<' => nil,
              '-' => ->(line) { @list.push(line.start_with?('----') ? Horizontal.new : UList.create(line)) },
              '+' => ->(line) { @list.push(OList.create(line)) },
              ' ' => ->(line) { push_preformatted(line) },
              '|' => ->(line) { push_table(line) }
            }
          end

          def push(line)
            if line.empty?
              @list.push(Empty.new)
            else
              mapping[line[0]]&.call(line) || push_paragraph(line)
            end
          end

          def to_s
            @list.map(&:to_s).join("\n")
          end
        end

        module_function

        def exec(body)
          page = Page.new
          body.split("\n", -1).each { |line| page.push(line) }
          page.to_s
        end
      end
      module Inline
        module_function

        def br(line)
          line.gsub(/^~$/, '')
              .gsub(/~$/, ' ' * 2)
              .gsub('&br;&br;', "\n\n")
              .gsub('&br;', "  \n")
        end

        def em_strong(line)
          line.gsub(/(''+)([^'].*?)(''+)/) do
            head = Regexp.last_match(1)
            text = Regexp.last_match(2)
            tail = Regexp.last_match(3)
            [[5, 3], [3, 1], [2, 2]].each do |k, v|
              if head.size >= k && tail.size >= k
                return [
                  "'" * (head.size - k),
                  ' ', '*' * v, text.strip, '*' * v, ' ',
                  "'" * (tail.size - k)
                ].join.lstrip
              end
            end
          end
        end

        def footnote(line)
          # TODO: implement
          line
        end

        def exec(body)
          body.split("\n", -1).map do |line|
            unless line.start_with?(' ')
              line = br(line)
              line = em_strong(line)
              line = footnote(line)
            end
            line
          end.join("\n")
        end
      end
      module Misc
        module_function

        def comment(line)
          line.gsub(%r{^//(.*)}) { "<!--#{Regexp.last_match(1)}-->" }
        end

        def del_hash(line)
          line.gsub(/\[#[0-9a-z]+?\]/, '')
        end

        def exec(body)
          body.split("\n", -1).map do |line|
            unless line.start_with?(' ')
              line = comment(line)
              line = del_hash(line)
            end
            line
          end.join("\n")
        end
      end

      module_function

      def exec(body)
        body = Misc.exec(body)
        body = Inline.exec(body)
        body = Block.exec(body)
        body
      end
    end
  end
end
