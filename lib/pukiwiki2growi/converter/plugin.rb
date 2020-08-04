# frozen_string_literal: true

module Pukiwiki2growi
  module Converter
    module Plugin
      module_function

      def unknown_block(name, args)
        [
          "##{name}",
          (args.nil? ? '' : "(#{args.join(',')})")
        ].join
      end

      def unknown_inline(name, args, inline)
        [
          "&#{name}",
          (args.nil? ? '' : "(#{args.join(',')})"),
          (inline.nil? ? '' : "{#{inline}}"),
          ';'
        ].join
      end

      def block(mapping, line)
        line.gsub(/^#([0-9a-zA-Z_]+)(\(([^\n]+)\).*)?/) do
          name = Regexp.last_match(1)&.downcase
          args = Regexp.last_match(3)&.split(',')&.map(&:strip)
          mapping[name]&.call(args) || unknown_block(name, args)
        end
      end

      # circular recursion
      # &plugin(args){&plugin(args){inline};&plugin(args);};
      def inline_rec_short(mapping, line)
        regex = /(?:&([0-9a-zA-Z_]+)(?:\(([^\)]+)\))?(?:{(.+)})?;)/
        line.gsub(regex) do
          name = Regexp.last_match(1)&.downcase
          args = Regexp.last_match(2)&.split(',')&.map(&:strip)
          pre_inline = Regexp.last_match(3)
          inline = pre_inline.nil? ? pre_inline : inline(mapping, pre_inline)
          mapping[name]&.call(args, inline) || unknown_inline(name, args, inline)
        end
      end

      # &plugin(args){inline};&plugin(args){inline};
      def inline(mapping, line)
        regex = /(?:&([0-9a-zA-Z_]+)(?:\(([^\)]+)\))?(?:{((?:\g<0>|.)*?)})?;)/
        line.gsub(regex) do
          inline_rec_short(mapping, Regexp.last_match(0))
        end
      end
    end
  end
end
