# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('./lib', __dir__)

require 'pukiwiki2growi'

require 'json'
require 'parallel'
require 'ruby-progressbar'
require 'yaml'

class Page
  attr_accessor :revid, :origin2attach
  attr_reader :body, :id, :path

  def initialize(id, path, body, origin2attach = {}, revid = nil)
    @id = id
    @path = path
    @body = body
    @origin2attach = origin2attach
    @revid = revid
    # @created_at = created_at
    # @updated_at = updated_at
  end

  def add_attachment(origin_name, new_name)
    @origin2attach[origin_name] = new_name
  end

  def create(converted)
    Page.new(@id, @path, converted, @origin2attach, revid)
  end
end

class Logger
  def initialize(log_root, enable_write)
    @log_root = File.expand_path(log_root || 'logs')
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

class Migrator
  def initialize(loader, client, logger, show_progress)
    @loader = loader
    @client = client
    @logger = logger
    @show_progress = show_progress
  end

  def ret_okerr(rets)
    success = rets.select { |hash| hash[:ok] }
    failure = rets.reject { |hash| hash[:ok] }
    [success, failure]
  end

  def write_log(name, success, skipped, failure)
    @logger.puts(name, success, skipped, failure)
  end

  def progresss_msg(str)
    @show_progress ? str : nil
  end

  def create_pages(client, pukiwiki_pages)
    page_map = client.pages_list_all[:pages].map { |page| [page[:path], page] }.to_h

    path_list = []
    exist_pages = []
    pukiwiki_pages.map { |page| page[:page_path] }.each do |path|
      ret = page_map[path]
      if ret.nil?
        path_list.push(path)
      else
        exist_pages.push(ret)
      end
    end

    progresss_msg = progresss_msg('Creating pages')
    rets = Parallel.map(path_list, progress: progresss_msg) do |path|
      client.pages_create("# #{path}", path)
    end

    ok, err = ret_okerr(rets)
    created, skipped = [ok.map { |ret| ret[:page] }, exist_pages].map do |pages|
      pages.map { |page| [page[:path], page] }
           .to_h
    end

    write_log('pages_create', created, skipped, err)

    created.merge(skipped)
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

  def upload_attaches(client, pukiwiki_attaches, path2retpage)
    # 1. get attachment list here
    # [[[/path/name1, obj1], [/path/name2, obj2],...],...]

    progresss_msg = progresss_msg('Getting attachment info')
    attach_exist_rets = Parallel.map(path2retpage, progress: progresss_msg) do |path, page_id|
      client.attachments_list(page_id)[:attachments].map do |attach|
        ["#{path}/#{attach[:originalName]}", attach]
      end
    end
    # /path/origin_name.foo => (attach object)
    attach_exists = attach_exist_rets.flatten(1).to_h

    # 2. split exist attachments with not uploaded attachments
    yet = []
    already = []
    pukiwiki_attaches.each do |obj|
      attach = attach_exists["#{obj[:page_path]}/#{obj[:name]}"]
      if attach.nil?
        yet.push(obj)
      else
        already.push(attach)
      end
    end

    progresss_msg = progresss_msg('Uploading attachments')
    rets = Parallel.map(yet, progress: progresss_msg) do |obj|
      page_path = obj[:page_path]
      name = obj[:name]
      pageret = path2retpage[page_path]
      if pageret.nil?
        attach_error('[local] Cannot find path.', page_path, name)
      else
        ret = client.attachments_add(pageret[:_id], obj[:file_path], name)
        ret[:ok] ? ret : attach_error(ret[:error], page_path, name)
      end
    end

    puts 'upload finished'
    ok, err = ret_okerr(rets)
    added, skipped = [ok.map { |ret| ret[:attachment] }, already].map do |attachments|
      attachments.group_by { |attach| attach[:page] }
    end

    write_log('attaches_upload', added, skipped, err)

    added.merge(skipped) { |_, h1, h2| h1.concat(h2) }
  end

  def update_pages(client, converted_pages)
    conv_page_map = converted_pages.map { |p| [p.id, p] }.to_h

    client.pages_list_all[:pages].each do |pageret|
      id = pageret[:_id]
      revision = pageret[:revision]
      # revid = revision[:_id] || revision
      revid = revision
      conv_page_map[id]&.revid = revid
    end

    progresss_msg = progresss_msg('Updating pages')
    rets = Parallel.map(conv_page_map, progress: progresss_msg) do |_, page|
      if page.body.nil? || page.id.nil? || page.revid.nil?
        {
          ok: false,
          error: {
            msg: '[local] Failred to update pages.',
            body: page.body.nil?,
            page_id: page.id,
            page_path: page.path,
            rev_id: page.revid
          }
        }
      else
        client.pages_update(page.body, page.id, page.revid)
      end
    end
    ok, err = ret_okerr(rets)
    write_log('pages_update', ok, nil, err)
    ok
  end

  def pre_pages(pukiwiki_pages, map_path_retpage, attach_success)
    pre_pages = pukiwiki_pages.map do |page|
      page_path = page[:page_path]
      pageret = map_path_retpage[page_path]
      if pageret.nil?
        nil
      else
        id = pageret[:_id]
        body = page[:body]
        Page.new(id, page_path, body)
      end
    end

    pre_pages.reject(&:nil?).map do |page|
      attachments = attach_success[page.id]
      unless attachments.nil?
        origin2attach = attachments.map do |attach|
          origin_name = attach[:originalName]
          attach_name = attach[:filePathProxied]
          [origin_name, attach_name]
        end.to_h
        page.origin2attach = origin2attach
      end
      page
    end
  end

  def convert_pages(pukiwiki_pages, map_path_retpage, attach_success)
    pre_pages = pre_pages(pukiwiki_pages, map_path_retpage, attach_success)

    Parallel.map(pre_pages, progress: 'Convert') do |page|
      conv = Pukiwiki2growi.convert(page.body, @top_page)
      ret = Pukiwiki2growi::Converter.convert_attach(conv, page.origin2attach)
      page.create(ret)
    end
  end

  def exec
    pukiwiki_pages = @loader.load_pages
    pukiwiki_attaches = @loader.list_attachments

    path2pageret = create_pages(@client, pukiwiki_pages)

    attach_success = upload_attaches(@client, pukiwiki_attaches, path2pageret)
    page_list = convert_pages(pukiwiki_pages, path2pageret, attach_success)

    update_pages(@client, page_list)
  end

  def self.create(config)
    loader = Pukiwiki2growi::Loader.new(config['PUKIWIKI_DIR'], 'EUC-JP', config['TOP_PAGE'])
    logger = Logger.new(config['LOG_ROOT'], config['ENABLE_LOG'])
    client = Pukiwiki2growi::Comm::Client.new(config['URL'], config['API_TOKEN'])
    progress = config['ENABLE_PROGRESS']
    new(loader, client, logger, progress)
  end

  def self.start(yml = 'config.yml')
    config = YAML.load_file(yml)
    Migrator.create(config).exec
  end
end

Migrator.start
