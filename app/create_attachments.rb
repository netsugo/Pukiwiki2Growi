# frozen_string_literal: true

module App
  module CreateAttachments
    # Result of attachment upload
    class Result
      attr_reader :path, :origin_name, :name

      def initialize(path, origin_name, name)
        @path = path
        @origin_name = origin_name
        @name = name
      end
    end

    module_function

    def unuploaded_attachments(fetch_attachments, load_attachments)
      load_attachments.select do |attach|
        fetch_attachments[attach.page_path]&.fetch(attach.name, nil).nil?
      end
    end

    def attach_error(msg, page_path, attach_name)
      {
        ok: false,
        error: {
          msg: msg,
          path: page_path,
          attach_name: attach_name
        }
      }
    end

    def upload_attach_single(client, pukiwiki_attach, path_2_ret_page)
      page_path = pukiwiki_attach.page_path
      ret_page = path_2_ret_page[page_path]
      file_path = pukiwiki_attach.file_path
      name = pukiwiki_attach.name
      if ret_page.nil?
        attach_error('[local] Cannot find path.', page_path, name)
      else
        ret = client.attachments_add(ret_page.id, file_path, name)
        ret[:ok] ? ret : attach_error(ret[:error], page_path, name)
      end
    end

    def main(client, load_attachments, path_2_ret_page, is_show_progress)
      str = 'Uploading attachments'
      msg = is_show_progress ? str : null
      Parallel.map(load_attachments, progress: msg) do |pukiwiki_attach|
        upload_attach_single(client, pukiwiki_attach, path_2_ret_page)
      end
    end

    def create_result_from_ok(hash)
      Result.new(
        hash[:page][:path],
        hash[:attachment][:originalName],
        hash[:attachment][:filePathProxied]
      )
    end

    def create_result_from_skip(hash_tree)
      sk = hash_tree.map do |path, v|
        v.map do |origin_name, name|
          Result.new(path, origin_name, name)
        end
      end
      sk.flatten
    end

    def write_log(logger, results_ok, results_sk, failure)
      ok_log, skip_log = [results_ok, results_sk].map do |rets|
        list = rets.map do |ret|
          "#{ret.path}/#{ret.origin_name}"
        end
        list.sort
      end
      err_log = failure.sort_by { |x| x[:error][:path] }
      logger.puts('attachments_upload', ok_log, skip_log, err_log)
    end

    def post(logger, skipped, results)
      success = results.select { |hash| hash[:ok] }
      failure = results.reject { |hash| hash[:ok] }

      ok = success.map { |hash| create_result_from_ok(hash) }
      sk = create_result_from_skip(skipped)

      write_log(logger, ok, sk, failure)

      ok.concat(sk)
    end

    def exec(app, rets_page)
      skipped = FetchAttachments.exec(app, rets_page)
      path_2_ret_page = rets_page.map { |ret| [ret.path, ret] }.to_h
      load_attachments = app.loader.list_attachments
      uncreated = unuploaded_attachments(skipped, load_attachments)
      results = main(app.client, uncreated, path_2_ret_page, app.show_progress?)
      post(app.logger, skipped, results)
    end
  end
end
