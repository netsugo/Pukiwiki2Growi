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

  def finalize_yet_already(yet_already_pairs)
    yet = yet_already_pairs.select { |_, b| b.nil? }.map { |a, _| a }
    already = yet_already_pairs.reject { |_, b| b.nil? }.map { |_, b| b }
    [yet, already].map(&:flatten)
  end

  def get_pages(client)
    msg = progresss_msg('Getting page info')
    # lst = client.pages_list_all[:pages]
    lst = Parallel.map([client], process: 1, progress: msg) { |c| c.pages_list_all[:pages] }[0]
    #lst.map { |page| [page[:path], page] }.to_h
    lst
  end

  def pages_yet_already(client, pukiwiki_pages)
    page_map = get_pages(client).map { |page| [page[:path], page] }.to_h
    yet_already_pairs = pukiwiki_pages.map do |pukiwiki_page|
      path = pukiwiki_page[:page_path]
      exist_page = page_map[path]
      [path, exist_page]
    end
    finalize_yet_already(yet_already_pairs)
  end

  def pages_ok_skip_err(rets, exist_pages)
    ok, err = ret_okerr(rets)
    created, skipped = [ok.map { |ret| ret[:page] }, exist_pages].map do |pages|
      pages.map { |page| [page[:path], page] }
           .to_h
    end
    [created, skipped, err]
  end

  def create_pages(client, pukiwiki_pages)
    path_list, exist_pages = pages_yet_already(client, pukiwiki_pages)

    progresss_msg = progresss_msg('Creating pages')
    rets = Parallel.map(path_list, progress: progresss_msg) do |path|
      client.pages_create("# #{path}", path)
    end

    created, skipped, err = pages_ok_skip_err(rets, exist_pages)
    write_log('pages_create', created, skipped, err)
    created.merge(skipped)
  end

  def get_exist_attaches(client, path2retpage) # path2id?
    msg = progresss_msg('Getting attachment info')
    # [[[/path/name1, obj1], [/path/name2, obj2],...],...]
    rets = Parallel.map(path2retpage, progress: msg) do |path, page_id|
      attachments = client.attachments_list(page_id)[:attachments]
      attachments.map do |attach|
        name = attach[:originalName]
        ["#{path}/#{name}", attach]
      end
    end

    # { /path1/name1 => (obj1), /path2/name2 => (obj2), }
    rets.flatten(1).to_h
  end

  def attach_yet_already(client, pukiwiki_attaches, path2retpage)
    attach_exists_map = get_exist_attaches(client, path2retpage)
    # split exist attachments with not uploaded attachments
    yet_already_pairs = pukiwiki_attaches.map do |obj|
      location = "#{obj[:page_path]}/#{obj[:name]}"
      pukiwiki_attach = obj
      exist_attach = attach_exists_map[location]
      # yet, already
      [pukiwiki_attach, exist_attach]
    end
    finalize_yet_already(yet_already_pairs)
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

  def attaches_ok_skip_err(rets, already)
    ok, err = ret_okerr(rets)
    added, skipped = [ok.map { |ret| ret[:attachment] }, already].map do |attachments|
      attachments.group_by { |attach| attach[:page] }
    end

    [added, skipped, err]
  end

  def upload_attach_single(client, obj, path2retpage)
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

  def upload_attaches(client, pukiwiki_attaches, path2retpage)
    yet, already = attach_yet_already(client, pukiwiki_attaches, path2retpage)

    progresss_msg = progresss_msg('Uploading attachments')
    rets = Parallel.map(yet, progress: progresss_msg) do |obj|
      upload_attach_single(client, obj, path2retpage)
    end

    added, skipped, err = attaches_ok_skip_err(rets, already)
    write_log('attaches_upload', added, skipped, err)
    added.merge(skipped) { |_, h1, h2| h1.concat(h2) }
  end

  def id_revid(pages)
    pages.map do |page|
      id = page[:_id]
      revision = page[:revision]
      # revid = revision[:_id] || revision
      revid = revision
      [id, revid]
    end
  end

  def pages_with_rev(client, pages)
    page_map = pages.map { |p| [p.id, p] }.to_h
    ret_pages = get_pages(client)
    id_revid(ret_pages).each { |id, revid| page_map[id]&.revid = revid }
    page_map.map { |_, page| page }
  end

  def update_page_error(page)
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
  end

  def update_page_single(client, page)
    if page.body.nil? || page.id.nil? || page.revid.nil?
      update_page_error(page)
    else
      client.pages_update(page.body, page.id, page.revid)
    end
  end

  def update_pages(client, converted_pages)
    pages = pages_with_rev(client, converted_pages)
    msg = progresss_msg('Updating pages')
    rets = Parallel.map(pages, progress: msg) do |page|
      update_page_single(client, page)
    end
    ok, err = ret_okerr(rets)
    write_log('pages_update', ok, nil, err)
    ok
  end

  def make_page(map_path_retpage, pukiwiki_page)
    page_path = pukiwiki_page[:page_path]
    pageret = map_path_retpage[page_path]
    if pageret.nil?
      nil
    else
      id = pageret[:_id]
      body = pukiwiki_page[:body]
      Page.new(id, page_path, body)
    end
  end

  def page_with_origin2attach(attach_success, page)
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

  def pre_pages(pukiwiki_pages, map_path_retpage, attach_success)
    pukiwiki_pages.map { |page| make_page(map_path_retpage, page) }
                  .reject(&:nil?)
                  .map { |page| page_with_origin2attach(attach_success, page) }
  end

  def convert_pages(pukiwiki_pages, map_path_retpage, attach_success)
    pre_pages = pre_pages(pukiwiki_pages, map_path_retpage, attach_success)

    Parallel.map(pre_pages, progress: 'Convert') do |page|
      conv = Pukiwiki2growi.convert(page.body, @loader.top_page)
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
    loader = Pukiwiki2growi::Loader.new(config['PUKIWIKI_DIR'], config['ENCODING'], config['TOP_PAGE'])
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
