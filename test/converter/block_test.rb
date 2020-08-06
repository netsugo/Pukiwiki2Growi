# frozen_string_literal: true

require_relative '../test_helper'

class NotationBlockTest < Minitest::Test
  def convert(body)
    Pukiwiki2growi::Converter.convert_page(body, nil)
  end

  def test_paragraph1
    testcase = {
      'test' => 'test',
      '~' => '  ' # see breakline
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
    testcase = {
      '>testQ1' => '> testQ1',
      '>>testQ2' => '>> testQ2',
      '>>>testQ3' => '>>> testQ3',
      '>>>>testQ4' => '>>> >testQ4',
      '<testB1' => 'testB1',
      '<<testB2' => '> testB2',
      '<<<testB3' => '>> testB3',
      '<<<<testB4' => '>> <testB4'
    }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
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

  def test_csv_normal1
    origin = [',aa,aa,aa', ', bb, bb, bb', ', cc , cc , cc '].join("\n")
    expect = [':::csv', 'aa,aa,aa', ' bb, bb, bb', ' cc , cc , cc ', ':::'].join("\n")
    actual = convert(origin)
    assert_equal expect, actual
  end

  def test_csv_normal2
    origin = [',test2,test2'].join("\n")
    expect = [':::csv', 'test2,test2', ':::'].join("\n")
    actual = convert(origin)
    assert_equal expect, actual
  end

  def test_heading
    testcase = {
      '*test1' => '# test1',
      '**test1' => '## test1',
      '***test1' => '### test1',
      '****test1' => '### *test1'
    }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
  end

  def test_toc
    testcase = {
      '#contents' => '@[toc]'
    }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
  end

  def div_align(pos, body)
    header = "<div style=\"text-align:#{pos}\">"
    element = body.split("\n", -1).map { |s| "#{' ' * 4}#{s}" }.join("\n")
    footer = '</div>'
    [header, element, footer].join("\n")
  end

  def test_align
    testcase = {
      'LEFT:test1L' => div_align('left', 'test1L'),
      'CENTER:test1C' => div_align('center', 'test1C'),
      'RIGHT:test1R' => div_align('right', 'test1R'),
      "LEFT:test2\ntest2" => div_align('left', "test2\ntest2"),
      "LEFT:test3\ntest3\n" => div_align('left', "test3\ntest3\n"),
      "CENTER:test4\nCENTER:test4" => [div_align('center', 'test4'), div_align('center', 'test4')].join("\n"),
      'LLEFT:test5' => 'LLEFT:test5',
      "LEFT:test6\n\n" => "#{div_align('left', 'test6')}\n\n",
      "LEFT:test7\n\ntest7" => "#{div_align('left', 'test7')}\n\ntest7"
    }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
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
