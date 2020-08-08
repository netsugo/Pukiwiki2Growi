# frozen_string_literal: true

require_relative './converter/main'
require_relative './converter/plugin'
require_relative './converter/post'
require_relative './converter/pre'

module Pukiwiki2growi
  module Converter
    module_function

    def convert_attach(page, origin2attach)
      # raise NotImplementedError

      page.gsub(/(\[)(.*)(\])(\()(.*)(\))/) do
        tag, origin = [Regexp.last_match(2), Regexp.last_match(5)].map do |name|
          name.gsub(%r{(^\./)(.+)}) do
            Regexp.last_match(2)
          end
        end

        new_name = origin2attach[origin] || origin
        "[#{tag}](#{new_name})"
      end
    end
  end
end
