# frozen_string_literal: true

require_relative '../test_helper'

class NotationInlineTest < Minitest::Test
  def convert(body)
    Pukiwiki2growi::Converter.convert_page(body, nil)
  end

  # br

  def test_br_normal
    testcase = {
      '~' => '',
      'test~' => 'test  '
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

  def test_footnote
    assert false
  end

  def test_ref
    testcase = {
      '&ref(text.txt);' => '[text.txt](text.txt)',
      '&ref(text.jpg);' => '![text.jpg](text.jpg)'
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
    assert false
  end
end
