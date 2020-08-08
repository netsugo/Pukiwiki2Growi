# frozen_string_literal: true

require_relative '../test_helper'

class NotationInlineTest < Minitest::Test
  def convert(body)
    Pukiwiki2growi.convert(body, nil)
  end

  # br

  def test_br_normal
    testcase = {
      '~' => '  ',
      'test1~' => 'test1  ',
      "test2~\ntest2" => "test2  \ntest2",
      "test3\n~\ntest3" => "test3\n  \ntest3",
      "test4\n~\n~\ntest4" => "test4\n  \n  \ntest4",
      "test5\nte~\nte~\nte~\ntest5" => "test5\nte  \nte  \nte  \ntest5"
    }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
  end

  def test_br_plugin
    testcase = {
      'test&br;test' => "test  \ntest",
      'test&br;&br;test' => "test\n\ntest"
    }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
  end

  def test_em_strong
    testcase = {
      "''strong''" => '**strong** ',
      "'''em1'''" => '*em1* ',
      "'''em2'em2'''" => "*em2'em2* ",
      "em3'''em3'''em3" => 'em3 *em3* em3',
      "'''''emstrong'''''" => '***emstrong*** ',
      "'''''''emstrong''''''''" => "'' ***emstrong*** '''"
    }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
  end

  def spstyle(args, text)
    style_args = args.map { |k, v| "#{k}:#{v}" }.join(';')
    "<span style=\"#{style_args}\">#{text}</span>"
  end

  def spcolor(color, text)
    spstyle({ 'color' => color }, text)
  end

  def spsize(size, text)
    spstyle({ 'font-size' => size }, text)
  end

  def test_size
    testcase = {
      '&size(20){test};' => spsize('20px', 'test'),
      '&size(20){test};&size(20){test};' => "#{spsize('20px', 'test')}#{spsize('20px', 'test')}"
    }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
  end

  def test_color
    testcase = {
      '&color(red){test};' => spcolor('red', 'test'),
      '&color(red,black){test};' => spstyle({ 'color' => 'red', 'bgcolor' => 'black' }, 'test'),
      '&color(red,black);' => spcolor('red', 'black')
    }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
  end

  def test_size_color
    testcase = {
      '&color(red){&size(20){RED20};};' => spcolor('red', spsize('20px', 'RED20'))
    }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
  end

  def test_alt_decorate1
    testcase = {
      ' COLOR(red){RED}' => "```\nCOLOR(red){RED}\n```",
      'COLOR(red){RED}' => spcolor('red', 'RED'),
      'SIZE(20){20PX}' => spsize('20px', '20PX')
    }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
  end

  def test_alt_decorate2
    testcase = {
      'SIZE(20){COLOR(red){RED20}}' => spsize('20px', spcolor('red', 'RED20')),
      'COLOR(red){SIZE(20){RED20}}' => spcolor('red', spsize('20px', 'RED20')),
      'SIZE(20){COLOR(red){RED20}COLOR(blue){BLUE20}}' => spsize('20px', "#{spcolor('red', 'RED20')}#{spcolor('blue', 'BLUE20')}"),
      'COLOR(red){SIZE(20){RED20}SIZE(25){RED25}}' => spcolor('red', "#{spsize('20px', 'RED20')}SIZE(25){RED25") + '}'
    }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
  end

  def test_alt_decorate3
    testcase = {
      'COLOR(red){RED&size(20){RED20};&size(20){RED20};}' => spcolor('red', "RED#{spsize('20px', 'RED20')}#{spsize('20px', 'RED20')}"),
      'SIZE(20){20PX&color(red){RED20};&color(red){RED20};}' => spsize('20px', "20PX#{spcolor('red', 'RED20')}#{spcolor('red', 'RED20')}"),
      '&color(red){REDSIZE(20){RED20}};' => spcolor('red', "RED#{spsize('20px', 'RED20')}"),
      '&size(20){20PXCOLOR(red){RED20}};' => spsize('20px', "20PX#{spcolor('red', 'RED20')}")
    }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
  end

  def test_strike
    testcase = {
      '%%test1%%' => '~~test1~~ ',
      '%%test2%test2%%' => '~~test2%test2~~ ',
      'test3%%test3%%test3' => 'test3 ~~test3~~ test3'
      # '%%%test%%%' => nil, # underline?
      # '%%%%%test%%%%%' => nil # underline and strike>
    }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
  end

  def test_footnote1
    testcase = {
      'foo((test1))foo' => "foo[^1]foo\n[^1]:test1",
      'foo((test2))foo((test2))foo' => "foo[^1]foo[^2]foo\n[^1]:test2\n[^2]:test2",
      'foo((test3((bar))test3))foo' => "foo[^1]foo\n[^1]:test3[^2]test3\n[^2]:bar",
      'foo((test41((bar1))test41))foo((test42((bar2))test42))foo' => "foo[^1]foo[^3]foo\n[^1]:test41[^2]test41\n[^2]:bar1\n[^3]:test42[^4]test42\n[^4]:bar2"
    }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
  end

  def test_footnote2
    origin = [
      'foo((test41((bar1))test41))',
      'foo((test42((bar2))test42))foo'
    ].join
    expect = [
      'foo[^1]foo[^3]foo',
      '[^1]:test41[^2]test41',
      '[^2]:bar1',
      '[^3]:test42[^4]test42',
      '[^4]:bar2'
    ].join("\n")

    assert_equal expect, convert(origin)
  end

  def test_footnote3
    origin = [
      'foo((test41((bar1((hoge1))bar1))test41))',
      'foo((test42((bar2((hoge2))bar2))test42))',
      'foo((test43((bar3((hoge3))bar3))test43))foo'
    ].join

    expect = [
      'foo[^1]foo[^4]foo[^7]foo',
      '[^1]:test41[^2]test41',
      '[^2]:bar1[^3]bar1',
      '[^3]:hoge1',
      '[^4]:test42[^5]test42',
      '[^5]:bar2[^6]bar2',
      '[^6]:hoge2',
      '[^7]:test43[^8]test43',
      '[^8]:bar3[^9]bar3',
      '[^9]:hoge3'
    ].join("\n")

    assert_equal expect, convert(origin)
  end

  def test_ref
    testcase = {
      '&ref(text1.txt);' => '[text1.txt](text1.txt)',
      '&ref(text2.jpg);' => '![text2.jpg](text2.jpg)',
      '&ref(test3.txt, nolink);' => '[test3.txt](test3.txt)',
      '&ref(test4.txt, test4);' => '[test4](test4.txt)',
      '&ref(test5.txt, test5, nolink);' => '[test5,nolink](test5.txt)',
      '&ref(http://example.com/test6, test6);' => '[test6](http://example.com/test6)'
     }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
  end

  def test_ruby
    testcase = {
      '&ruby(ruby){inline};' => '<ruby>inline<rp>(</rp><rt>ruby</rt><rp>)</rp></ruby>'
    }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
  end

  def test_link
    assert false
  end

  def test_comment
    testcase = {
      '//line' => '<!--line-->'
    }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
  end

  def test_hash
    testcase = {
      'test1 [#1234abcd]' => 'test1',
      'test2 [#1234abc]' => 'test2',
      'test3 [#1234abcde]' => 'test3',
      'test4 [#1234abcd] test4' => 'test4 [#1234abcd] test4',
      '[#1234abcde] test5' => '[#1234abcde] test5'
    }

    testcase.each { |origin, expect| assert_equal expect, convert(origin) }
  end
end
