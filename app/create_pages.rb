# frozen_string_literal: true

module App
  module CreatePages
    # Result of page creation
    class Result
      attr_reader :path, :id
      attr_accessor :attachments

      def initialize(path, id)
        @path = path
        @id = id
        @attachments = [] # attachment result
      end
    end

    module_function

    def norm_exist_pages(rets_fetch_page, pukiwiki_page_pathes)
      set = pukiwiki_page_pathes.map { |x| [x, ''] }.to_h
      rets_fetch_page.reject { |ret| set[ret.path].nil? }
    end

    def select_uncreated_pathes(fetch_pages, pukiwiki_page_pathes)
      set = fetch_pages.map { |x| [x.path, ''] }.to_h
      pukiwiki_page_pathes.select { |path| set[path].nil? }
    end

    def page_error(msg, path)
      {
        ok: false,
        error: {
          msg: msg,
          path: path
        }
      }
    end

    def main(client, is_show_progress, pathes)
      str = 'Creating pages'
      msg = is_show_progress ? str : nil
      Parallel.map(pathes, progress: msg) do |path|
        ret = client.pages_create("# #{path}", path)
        ret[:ok] ? ret : page_error(ret[:error], path)
      end
    end

    def create_result_from_ok(hash)
      page = hash[:page]
      Result.new(page[:path], page[:id])
    end

    def create_result_from_skip(obj)
      Result.new(obj.path, obj.id)
    end

    def write_log(logger, results_ok, results_sk, failure)
      ok_log, skip_log = [results_ok, results_sk].map { |list| list.map(&:path).sort }
      err_log = failure.sort_by { |x| x[:error][:path] }
      logger.puts('pages_create', ok_log, skip_log, err_log)
    end

    def post(logger, skipped, results)
      success = results.select { |hash| hash[:ok] }
      failure = results.reject { |hash| hash[:ok] }

      ok = success.map { |hash| create_result_from_ok(hash) }
      sk = skipped.map { |obj| create_result_from_skip(obj) }
      write_log(logger, ok, sk, failure)
      ok.concat(skipped)
    end

    def exec(app, pukiwiki_page_pathes)
      fetched_pages = FetchPages.exec(app)
      skip = norm_exist_pages(fetched_pages, pukiwiki_page_pathes)
      uncreated = select_uncreated_pathes(fetched_pages, pukiwiki_page_pathes)
      results = main(app.client, app.show_progress?, uncreated)
      post(app.logger, skip, results)
    end
  end
end
