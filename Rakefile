# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'
require_relative 'app'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
end

task default: :test

task :app do
  config = YAML.load_file('config.yml')
  app_info = App::AppInfo.new(config)

  pukiwiki_pages = app_info.loader.load_pages
  pukiwiki_page_pathes = pukiwiki_pages.map(&:page_path)
  create_page_rets = App::CreatePages.exec(app_info, pukiwiki_page_pathes)
  upload_attach_rets = App::CreateAttachments.exec(app_info, create_page_rets)
  convert_rets = App::Convert.exec(app_info, pukiwiki_pages, create_page_rets, upload_attach_rets)
  App::UpdatePages.exec(app_info, convert_rets)
end
