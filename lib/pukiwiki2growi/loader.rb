# frozen_string_literal: true

require 'nkf'

module Pukiwiki2growi
  class Loader
    def initialize(pukiwiki_root, encoding, top_page = '/')
      root = File.expand_path(pukiwiki_root)
      @page_root = File.join(root, 'wiki')
      @attach_root = File.join(root, 'attach')
      @top_page = File.join('/', top_page || '')
      @encoding = encoding
      @ignore = []
    end

    def decode_page_name(str)
      path = [str].pack('H*').force_encoding(@encoding)
      nkf_opt = '-E -w'
      NKF.nkf(nkf_opt, path)
    end

    def decode_attach_name(str)
      str.split('_').map { |s| decode_page_name(s) }
    end

    def read_page(file_path)
      doc = File.read(file_path, encoding: @encoding)
      nkf_opt = '-E -w'
      NKF.nkf(nkf_opt, doc)
    end

    def normalize(path)
      if path == 'FrontPage'
        @top_page
      elsif @ignore.include?(path) || path.start_with?(':')
        nil
      else
        File.join(@top_page, path)
      end
    end

    def load_pages
      Dir.chdir(@page_root)
      list = Dir.glob('*.txt').map do |f|
        page_path = normalize(decode_page_name(File.basename(f, '.*')))
        body = read_page(f)
        { page_path: page_path, body: body }
      end

      list.reject { |obj| obj[:page_path].nil? }
    end

    def list_attachments
      Dir.chdir(@attach_root)
      list = Dir.glob('*')
                .select { |f| File.extname(f).empty? }
                .map do |f|
                  page_path, name = decode_attach_name(f)
                  {
                    file_path: File.join(@attach_root, f),
                    page_path: normalize(page_path),
                    name: name
                  }
                end
      list.reject { |obj| obj[:page_path].nil? }
    end
  end
end
