# frozen_string_literal: true

module Pukiwiki2growi
  module Converter
    module Pre
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

        def exec(line)
          line = Pukiwiki2growi::Converter::Plugin.exec(line)
          line = dlist(line)
          line = alt_decoration(line)
          line
        end
      end
    end
  end
end
