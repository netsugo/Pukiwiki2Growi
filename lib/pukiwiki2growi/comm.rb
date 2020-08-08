# frozen_string_literal: true

require 'json'
require 'mime-types'
require 'rest-client'

module Pukiwiki2growi
  module Comm
    # good luck charm :)
    class MultipartFile < File
      attr_reader :original_filename

      def initialize(filename, original_name, mode)
        @original_filename = original_name
        super(filename, mode)
      end

      def content_type
        name = @original_filename || File.basename(@filename)
        MIME::Types.type_for(name)[0]
      end
    end

    class Client
      def initialize(growi_url, access_token)
        @url = File.join(growi_url, '_api')
        @access_token = access_token
      end

      def request(method, name, payload = {}, query_params = {})
        case method
        when :get
          query_params[:access_token] = @access_token
        else
          payload[:access_token] = @access_token
        end
        req_params = {
          method: method,
          url: "#{@url}/#{name}",
          payload: payload,
          headers: { params: query_params }
        }
        res = RestClient::Request.execute(req_params)
        JSON.parse(res.body, symbolize_names: true)
      end

      def request_get(name, params)
        request(:get, name, {}, params)
      end

      def request_post(name, params)
        request(:post, name, params, {})
      end

      def request_post_multipart(name, params, file_path, original_name = nil)
        file = MultipartFile.new(
          file_path,
          original_name || File.basename(file_path),
          'rb'
        )
        payload = { file: file }.merge(params)
        request_post(name, payload)
      end

      def pages_list(path = '/', limit = 0, offset = 0)
        params = { path: path, limit: limit, offset: offset }
        name = __method__.to_s.gsub(/_/, '.')
        request_get(name, params)
      end

      def pages_list_all(path = '/', limit = 50)
        buf = []
        offset = 0
        loop do
          ret = pages_list(path, limit, offset)
          pages = ret[:pages]
          return ret if pages.nil?
          return { ok: true, pages: buf.flatten } if pages.empty?

          buf << pages
          offset += pages.size
        end
      end

      def pages_create(body, path)
        params = { body: body, path: path }
        name = __method__.to_s.gsub(/_/, '.')
        request_post(name, params)
      end

      def pages_update(body, page_id, revision_id)
        params = { body: body, page_id: page_id, revision_id: revision_id }
        name = __method__.to_s.gsub(/_/, '.')
        request_post(name, params)
      end

      def pages_get(path)
        params = { path: path }
        name = __method__.to_s.gsub(/_/, '.')
        request_get(name, params)
      end

      def attachments_list(page_id)
        params = { page_id: page_id }
        name = __method__.to_s.gsub(/_/, '.')
        request_get(name, params)
      end

      def attachments_add(page_id, file_path, original_name = nil)
        params = {
          page_id: page_id
        }
        name = __method__.to_s.gsub(/_/, '.')
        request_post_multipart(name, params, file_path, original_name)
      end
    end
  end
end
