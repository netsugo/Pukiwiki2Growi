# frozen_string_literal: true

module Pukiwiki2growi
  module Converter
    module Post
      module Block
        module_function

        def fix_table_csv(body)
          body.gsub(/(:::csv)((\n,.*)*)(\n:::)/) do
            header = Regexp.last_match(1)
            content = Regexp.last_match(2)
            footer = Regexp.last_match(4)
            [header, content.gsub("\n,", "\n"), footer].join
          end
        end

        def fix_div_style(body)
          body.gsub(%r{(<div style=.*?)((\n.*)*?)(\n</div>)}) do
            header = Regexp.last_match(1)
            content = Regexp.last_match(2)
            footer = Regexp.last_match(4)
            lines = content.gsub("\n", "\n#{' ' * 4}")
            [header, lines, footer].join
          end
        end

        def exec(body)
          body = fix_table_csv(body)
          body = fix_div_style(body)
          body
        end
      end
    end
  end
end
