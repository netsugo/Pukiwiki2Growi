# frozen_string_literal: true

module Pukiwiki2growi
  module Converter
    module Post
      module_function

      def fix_table_csv(body)
        body.gsub(/(:::csv)((\n,.*)*)(\n:::)/) do
          header = Regexp.last_match(1)
          ctable = Regexp.last_match(2).gsub("\n,", "\n")
          footer = Regexp.last_match(4)
          [header, ctable, footer].join
        end
      end

      def fix_div_style(body)
        body.gsub(%r{(<div style=.*?)((\n.*)*?)(\n</div>)}) do
          header = Regexp.last_match(1)
          content = Regexp.last_match(2)
          footer = Regexp.last_match(4)
          lines = content.gsub("\n") { "\n#{' ' * 4}" }
          [header, lines, footer].join
        end
      end

      def span_style(key, value, element)
        header = "<span style=\"#{key}:#{value}\">"
        footer = '</span>'
        [header, element, footer].join
      end

      # COLOR(color){inline}
      # SIZE(size){inline}
      # See pukiwiki/default.ini.php
      def alt_decoration(line)
        { 'COLOR' => 'color', 'SIZE' => 'font-size' }.each do |k, name|
          [/#{k}\(([^\(\)]*)\){([^}]*)}/, /#{k}\(([^\(\)]*)\):((?:(?!COLOR\([^\)]+\)\:).)*)/].each do |regex|
            line.gsub!(regex) do
              value = Regexp.last_match(1)
              value << 'px' if k == 'SIZE'
              element = Regexp.last_match(2)
              span_style(name, value, element)
            end
          end
        end
        line
      end

      def exec(body)
        body = fix_table_csv(body)
        body = fix_div_style(body)
        body = alt_decoration(body) # ?
        body
      end
    end
  end
end
