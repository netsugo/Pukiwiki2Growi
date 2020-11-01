# frozen_string_literal: true

module App
  module UpdatePages
    class Info
      attr_reader :path, :id, :revid, :body

      def initialize(ret_convert, revid)
        @path = ret_convert.path
        @id = ret_convert.id
        @revid = revid
        @body = ret_convert.body
      end
    end

    module_function

    def pre(app, rets_convert)
      rets_page = FetchPages.exec(app)
      id2revid = rets_page.map { |x| [x.id, x.revid] }.to_h
      rets_convert.map do |ret|
        revid = id2revid[ret.id]
        Info.new(ret, revid)
      end
    end

    def update_page_error(info)
      {
        ok: false,
        error: {
          msg: '[local] Failred to update pages.',
          body: info.body.nil?,
          page_id: info.id,
          page_path: info.path,
          rev_id: info.revid
        }
      }
    end

    def update_page_single(client, page)
      if page.body.nil? || page.id.nil? || page.revid.nil?
        update_page_error(page)
      else
        client.pages_update(page.body, page.id, page.revid)
      end
    end

    def main(client, is_show_progress, convert_info_list)
      str = 'Updating pages'
      msg = is_show_progress ? str : null
      Parallel.map(convert_info_list, progress: msg) do |info|
        if info.body.nil? || info.id.nil? || info.revid.nil?
          update_page_error(info)
        else
          client.pages_update(info.body, info.id, info.revid)
        end
      end
    end

    def create_result_from_ok(hash)
      hash
    end

    def write_log(logger, results_ok, results_sk, failure)
      ok_log, skip_log = [results_ok, results_sk].map { |list| list.map { |x| x[:page][:path] }.sort }
      logger.puts('pages_update', ok_log, skip_log, failure)
    end

    def post(logger, results)
      success = results.select { |hash| hash[:ok] }
      failure = results.reject { |hash| hash[:ok] }

      ok = success.map { |hash| create_result_from_ok(hash) }
      sk = []

      write_log(logger, ok, sk, failure)

      ok.concat(sk)
    end

    def exec(app, rets_convert)
      info_list = pre(app, rets_convert)
      results = main(app.client, app.show_progress?, info_list)
      post(app.logger, results)
    end
  end
end
