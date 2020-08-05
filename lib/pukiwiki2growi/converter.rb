# frozen_string_literal: true

require_relative './converter/main'
require_relative './converter/plugin'
require_relative './converter/post'
require_relative './converter/pre'

module Pukiwiki2growi
  module Converter
    module_function

    def convert_page(body, _wiki_root)
      body = Pre::Body.exec(body)
      body = Main.exec(body)
      body = Post::Block.exec(body)
      body
    end
  end
end
