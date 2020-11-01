# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('./lib', __dir__)
$LOAD_PATH.unshift File.expand_path('./app', __dir__)

require 'pukiwiki2growi'

require 'json'
require 'parallel'
require 'ruby-progressbar'
require 'yaml'

require 'app_info'
require 'convert'
require 'create_attachments'
require 'create_pages'
require 'fetch_attachments'
require 'fetch_pages'
require 'update_pages'
