# frozen_string_literal: true

module App
  class JsonLogger
    def initialize(log_root, enable_write)
      @log_root = File.expand_path(log_root || 'log')
      @enable_write = enable_write
    end

    def puts_data(name, obj)
      json = JSON.pretty_generate(obj)
      path = File.join(@log_root, "#{name}.json")
      File.open(path, 'w') do |f|
        f.puts json
      end
    end

    def puts(name, success, skipped, failure)
      return unless @enable_write

      log_data = {
        success: success,
        skipped: skipped,
        failure: failure
      }

      puts_data(name, { name => log_data })
    end
  end

  class AppInfo
    attr_reader :loader, :logger, :client

    def initialize(yaml_config)
      config = yaml_config
      @loader = Pukiwiki2growi::Loader.new(config['PUKIWIKI_DIR'], config['ENCODING'], config['TOP_PAGE'])
      @logger = JsonLogger.new(config['LOG_ROOT'], config['ENABLE_LOG'])
      @client = Pukiwiki2growi::Comm::Client.new(config['URL'], config['API_TOKEN'])
      @is_show_progress = config['ENABLE_PROGRESS']
    end

    def show_progress?
      @is_show_progress
    end
  end
end
