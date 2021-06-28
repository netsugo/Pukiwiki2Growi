# frozen_string_literal: true

require 'nkf'

module Pukiwiki2growi
  class Page
    attr_reader :page_path, :body

    def initialize(page_path, body)
      @page_path = page_path
      @body = body
    end

    def ==(other)
      @page_path == other.page_path && @body == other.body
    end
  end

  class Attachment
    attr_reader :file_path, :page_path, :name

    def initialize(file_path, page_path, name)
      @file_path = file_path
      @page_path = page_path
      @name = name
    end

    def ==(other)
      @file_path == other.file_path && @page_path == other.page_path && @name == other.name
    end
  end

  module LoaderUtil
    module_function

    def normalize_path(front_page, top_page, path, blacklist)
      if path == front_page
        File.join(top_page, '')
      elsif blacklist.include?(path) || path.start_with?(':')
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

    def select_page(encoding, top_page, file, blacklist)
      bname = File.basename(file, '.*')
      page_path = decode_page_name(encoding, bname)
      normalize_path('FrontPage', top_page, page_path, blacklist)&.gsub(%r{/+$}, '')
    end

    # [page_path, attach_name]
    def decode_attach_name(encoding, str)
      str.split('_').map { |s| decode_page_name(encoding, s) }
    end

    def select_attachment(encoding, top_page, file, blacklist)
      if !File.extname(file).empty?
        nil
      else
        page_path, name = decode_attach_name(encoding, File.basename(file))
        normalized_path = normalize_path('FrontPage', top_page, page_path, blacklist)
        Attachment.new(file, normalized_path, name)
      end
    end
  end

  class Loader
    attr_reader :top_page

    def initialize(pukiwiki_root, encoding, blacklist, top_page = '/')
      root = File.expand_path(pukiwiki_root)
      @page_root = File.join(root, 'wiki')
      @attach_root = File.join(root, 'attach')
      @top_page = File.join('/', top_page || '')
      @encoding = encoding
      @blacklist = blacklist || []
    end

    def file_read(name)
      File.read(name, encoding: @encoding)
    end

    def lsdir(dir, pattern = '')
      Dir.chdir(dir)
      Dir.glob(pattern)
    end

    def read_page(file)
      page_path = LoaderUtil.select_page(@encoding, @top_page, file, @blacklist)
      if page_path.nil?
        nil
      else
        doc = file_read(file)
        body = LoaderUtil.decode(@encoding, doc)
        Page.new(page_path, body)
      end
    end

    def load_pages
      lsdir(@page_root, '*.txt')
        .map { |file| read_page(file) }
        .compact
    end

    def list_attachments
      lsdir(@attach_root, '*')
        .map { |file| LoaderUtil.select_attachment(@encoding, @top_page, file, @blacklist) }
        .compact
    end
  end
end
