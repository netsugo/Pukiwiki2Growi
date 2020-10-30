# frozen_string_literal: true

require_relative '../test_helper'

class MockLoader < Pukiwiki2growi::Loader
  def initialize(encoding, dataset)
    super('/etc/pukiwiki', encoding, '/Top')
    @dataset = dataset
  end

  def file_read(name)
    @dataset[File.basename(name)]
  end

  def create_lsdir
    @dataset.keys
  end

  def lsdir(dir, _pattern)
    create_lsdir.map { |k| File.join(dir, k) }
  end
end

class PukiwikiLoaderTest < Minitest::Test
  def normalize(path)
    Pukiwiki2growi::LoaderUtil.normalize_path('FrontPage', '/Top/', path, @ignore)
  end

  def test_normailze_path
    testcase = {
      'FrontPage' => '/Top/', # '/Top/'
      #'IgnorePage' => nil,
      ':config' => nil,
      'ExamplePage' => '/Top/ExamplePage'
    }

    testcase.each { |origin, expect| assert_equal expect, normalize(origin) }
  end

  def test_load_pages_euc
    dataset = {
      # filename and content
      '3A636F6E666967.txt' => ':config'.encode('euc-jp'),
      '46726F6E7450616765.txt' => 'FrontPage'.encode('euc-jp'),
      '4D656E75426172.txt' => 'MenuBar'.encode('euc-jp'),
      'A5D8A5EBA5D7.txt' => 'ヘルプ'.encode('euc-jp')
    }
    expect = [
      { page_path: '/Top/', body: 'FrontPage' },
      { page_path: '/Top/MenuBar', body: 'MenuBar' },
      { page_path: '/Top/ヘルプ', body: 'ヘルプ' }
    ]
    result = MockLoader.new('euc-jp', dataset).load_pages
    assert_equal expect, result
  end

  def test_load_pages_utf8
    dataset = {
      # filename and content
      '3a636f6e666967.txt' => ':config'.encode('utf-8'),
      '46726f6e7450616765.txt' => 'FrontPage'.encode('utf-8'),
      '4d656e75426172.txt' => 'MenuBar'.encode('utf-8'),
      'e38398e383abe38397.txt' => 'ヘルプ'.encode('utf-8')
    }
    expect = [
      { page_path: '/Top/', body: 'FrontPage' },
      { page_path: '/Top/MenuBar', body: 'MenuBar' },
      { page_path: '/Top/ヘルプ', body: 'ヘルプ' }
    ]
    result = MockLoader.new('utf-8', dataset).load_pages
    assert_equal expect, result
  end

  def test_list_attachments_euc
    dataset = {
      # value has no effect
      '54657374A5DAA1BCA5B8_A5B5A5F3A5D7A5EB2E6A7067' => ['Testページ', 'サンプル.jpg']
    }
    expect = [
      {
        file_path: '/etc/pukiwiki/attach/54657374A5DAA1BCA5B8_A5B5A5F3A5D7A5EB2E6A7067',
        page_path: '/Top/Testページ',
        name: 'サンプル.jpg'
      }
    ]
    result = MockLoader.new('euc-jp', dataset).list_attachments
    assert_equal expect, result
  end

  def test_list_attachments_utf8
    dataset = {
      # value has no effect
      '54657374e3839ae383bce382b8_e382b5e383b3e38397e383ab2e6a7067' => ['Testページ', 'サンプル.jpg']
    }
    expect = [
      {
        file_path: '/etc/pukiwiki/attach/54657374e3839ae383bce382b8_e382b5e383b3e38397e383ab2e6a7067',
        page_path: '/Top/Testページ',
        name: 'サンプル.jpg'
      }
    ]
    result = MockLoader.new('utf-8', dataset).list_attachments
    assert_equal expect, result
  end
end
