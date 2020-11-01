# frozen_string_literal: true

module App
  module FetchPages
    class Result
      attr_reader :path, :id, :revid

      def initialize(path, id, revid)
        @path = path
        @id = id
        @revid = revid
      end
    end

    module_function

    def main(clients, is_show_progress)
      str = 'Getting page info'
      msg = is_show_progress ? str : null
      Parallel.map(clients, process: 1, progress: msg) do |client|
        client.pages_list_all[:pages]
      end
    end

    def post(results)
      # TODO: check lib/comm.rb
      results[0].map do |page|
        # revision = page[:revision]
        # revid = revision[:_id] || revision

        Result.new(
          page[:path],
          page[:_id],
          page[:revision]
        )
      end
    end

    def exec(app)
      results = main([app.client], app.show_progress?)
      post(results)
    end
  end
end
