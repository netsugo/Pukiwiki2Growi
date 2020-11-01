# frozen_string_literal: true

module App
  module FetchAttachments
    module_function

    def main(client, is_show_progress, rets_page)
      str = 'Getting attachment info'
      msg = is_show_progress ? str : null

      # [[path, { name1: pname2, name2: pname2,...}],...]
      Parallel.map(rets_page, progress: msg) do |ret_page|
        attachments = client.attachments_list(ret_page.id)[:attachments]
        pairs = attachments.map { |x| [x[:originalName], x[:filePathProxied]] }.to_h
        [ret_page.path, pairs]
      end
    end

    def post(results)
      # { path: { name1: obj1, name2: obj2, ... }, ... }
      results.to_h
    end

    def exec(app, rets_page)
      results = main(app.client, app.show_progress?, rets_page)
      post(results)
    end
  end
end
