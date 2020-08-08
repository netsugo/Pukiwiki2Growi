# frozen_string_literal: true

require 'pukiwiki2growi/version'
require 'pukiwiki2growi/comm'
require 'pukiwiki2growi/converter'
require 'pukiwiki2growi/loader'

module Pukiwiki2growi
  module_function

  def convert(body, top_page)
    body = Converter::Pre::Body.exec(body)
    body = Converter::Main.exec(body)
    body = Converter::Post::Block.exec(body)
    body
  end
end
