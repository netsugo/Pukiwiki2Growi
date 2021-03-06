# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
end

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'pukiwiki2growi'
require_relative '../app'
require 'minitest/autorun'
