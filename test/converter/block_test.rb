# frozen_string_literal: true

require_relative '../test_helper'

class NotationBlockTest < Minitest::Unit::TestCase
  def convert(body)
    Pukiwiki2growi::Converter.convert_page(body, nil)
  end

  def test_paragraph1
    testcase = {
      'test' => 'test',
      '~' => '' # see breakline
    }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
  end

  def test_paragraph2
    origin = ['paragraph', '', 'paragraph'].join("\n")
    expect = ['paragraph', '', 'paragraph'].join("\n")
    actual = convert(origin)
    assert_equal expect, actual
  end

  def test_paragraph3
    origin = '~paragraph'
    expect = "paragraph\n"
    actual = convert(origin)
    assert_equal expect, actual
  end

  def test_paragraph4
    origin = ['test', '~paragraph', '~paragraph', 'test'].join("\n")
    expect = ['test', '', 'paragraph', '', 'paragraph', '', 'test'].join("\n")
    actual = convert(origin)
    assert_equal expect, actual
  end

  def test_quote
    assert false
  end

  def test_ul
    testcase = {
      '-test1' => '* test1',
      '--test2' => '  * test2',
      '---test3' => '    * test3',
      '----test4' => '____' # Horizontal
    }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
  end

  def test_ol
    testcase = {
      '+test1' => '1. test1',
      '++test2' => '  1. test2',
      '+++test3' => '    1. test3',
      '++++test4' => '    1. +test4'
    }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
  end

  def test_preformat
    origin = ['  test', '  test'].join("\n")
    expect = ['```', ' test', ' test', '```'].join("\n")
    actual = convert(origin)
    assert_equal expect, actual
  end

  def test_table_normal
    origin = ['|test|test|test|'].join("\n")
    expect = ['|     |     |     |', '| --- | --- | --- |', '|test|test|test|'].join("\n")
    actual = convert(origin)
    assert_equal expect, actual
  end

  def test_csv_normal
    origin = [',aa,aa,aa', ', bb, bb, bb', ', cc , cc , cc '].join("\n")
    expect = [':::csv', 'aa,aa,aa', ' bb, bb, bb', ' cc , cc , cc '].join("\n")
    actual = convert(origin)
    assert_equal expect, actual
  end

  def test_toc
    testcase = {
      '#contents' => '@[toc]'
    }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
  end

  def test_align
    assert false
  end

  def test_hr_normal
    assert '____', convert('--------')
  end

  def test_hr_plugin
    assert '____', convert('#hr')
  end

  def test_br; end

  def test_ref; end
end
