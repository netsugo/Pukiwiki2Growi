# frozen_string_literal: true

require 'nkf'

module Pukiwiki2growi
  module LoaderUtil
    module_function

    def normalize_path(front_page, top_page, path, *ignore)
      if path == front_page
        File.join(top_page, '')
      elsif ignore.include?(path) || path.start_with?(':')
        nil
      else
        File.join(top_page, path)
      end
    end

    def decode(encoding, str)
      nkf_opt = "--ic #{encoding.upcase} -w"
      NKF.nkf(nkf_opt, str)
    end

    def decode_page_name(encoding, str)
      path = [str].pack('H*').force_encoding(encoding)
      decode(encoding, path)
    end

    def select_page(encoding, top_page, file, *ignore_page)
      bname = File.basename(file, '.*')
      page_path = decode_page_name(encoding, bname)
      normalize_path('FrontPage', top_page, page_path, ignore_page)
    end

    # [page_path, attach_name]
    def decode_attach_name(encoding, str)
      str.split('_').map { |s| decode_page_name(encoding, s) }
    end

    def select_attachment(encoding, top_page, file, *ignore_page)
      if !File.extname(file).empty?
        nil
      else
        page_path, name = decode_attach_name(encoding, File.basename(file))
        {
          file_path: file,
          page_path: normalize_path('FrontPage', top_page, page_path, ignore_page),
          name: name
        }
      end
    end
  end

  class Loader
    attr_reader :top_page

    def initialize(pukiwiki_root, encoding, top_page = '/')
      root = File.expand_path(pukiwiki_root)
      @page_root = File.join(root, 'wiki')
      @attach_root = File.join(root, 'attach')
      @top_page = File.join('/', top_page || '')
      @encoding = encoding
      @ignore = []
    end

    def file_read(name)
      File.read(name, encoding: @encoding)
    end

    def lsdir(dir, pattern = '')
      Dir.chdir(dir)
      Dir.glob(pattern)
    end

    def read_page(file)
      page_path = LoaderUtil.select_page(@encoding, @top_page, file, @ignore)
      if page_path.nil?
        nil
      else
        doc = file_read(file)
        body = LoaderUtil.decode(@encoding, doc)
        { page_path: page_path, body: body }
      end
    end

    def load_pages
      lsdir(@page_root, '*.txt')
        .map { |file| read_page(file) }
        .compact
    end

    def list_attachments
      lsdir(@attach_root, '*')
        .map { |file| LoaderUtil.select_attachment(@encoding, @top_page, file, @ignore) }
        .compact
    end
  end
end
