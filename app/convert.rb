# frozen_string_literal: true

module App
  module Convert
    class ConvertInfo
      attr_accessor :id
      attr_reader :path, :body, :origin2attach

      def initialize(pukiwiki_page)
        @path = pukiwiki_page.page_path
        @body = pukiwiki_page.body
        @origin2attach = {}
      end

      def push_ret_attachment(ret_attachment)
        origin = ret_attachment.origin_name
        attach = ret_attachment.name
        @origin2attach[origin] = attach
      end
    end

    # Result of convert
    class ResultConvert
      attr_reader :path, :id, :body

      def initialize(path, id, body)
        @path = path
        @id = id
        @body = body
      end
    end

    module_function

    def merge_result(pukiwiki_pages, rets_page, rets_attachment)
      hash = pukiwiki_pages.map { |page| [page.page_path, ConvertInfo.new(page)] }.to_h 
      rets_page.each do |page|
        info = hash[page.path]
        info.id = page.id unless info.nil?
      end
      rets_attachment.each do |attach|
        info = hash[attach.path]
        info&.push_ret_attachment(attach)
      end
      hash.values
    end

    def main(top_page, is_show_progress, requests)
      str = 'Convert'
      msg = is_show_progress ? str : nil

      Parallel.map(requests, progress: msg) do |req|
        conv = Pukiwiki2growi.convert(req.body, top_page)
        ret = Pukiwiki2growi::Converter.convert_attach(conv, req.origin2attach)
        ResultConvert.new(req.path, req.id, ret)
      end
    end

    def exec(app, pukiwiki_pages, rets_page, result_attachments)
      requests = merge_result(pukiwiki_pages, rets_page, result_attachments)
      main(app.loader.top_page, app.show_progress?, requests)
    end
  end
end
