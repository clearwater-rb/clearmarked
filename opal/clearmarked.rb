require 'clearwater/component'

require 'clearmarked/js/marked'

module Clearmarked
  module_function

  def call string
    Clearwater::Component.div({ class_name: 'markdown' }, native.call(string))
  end

  def native
    @native ||= build_native
  end

  def build_native
    md = `marked`

    %x{
      marked.setOptions({
        renderer: #{Renderer.new},
      });
    }

    md
  end

  class Renderer
    include Clearwater::Component

    def initialize
      # Block elements
      @heading = proc do |text, level|
        id = text_for(text)
        tag("h#{level}", { id: id }, text)
      end
      @code = proc { |code, lang| pre(code({ lang: lang }, code)) }
      @list = proc { |content, ordered| tag(ordered ? :ol : :ul, nil, content) }
      @listitem = proc { |content| li(content) }
      @text = proc { |text| text }
      @blockquote = proc { |text| blockquote(text) }
      @html = proc { |html| div(innerHTML: html) }
      @hr = proc { hr }
      @paragraph = proc { |content| p content }
      @table = proc do |header, body|
        table([
          thead(header),
          tbody(body),
        ])
      end
      @tablerow = proc { |cells| tr(cells) }
      @tablecell = proc do |content, flags={}|
        flags = Hash.new(flags) # Convert from JS object
        tag_type = flags[:header] ? :th : :td
        properties = {
          style: {
            text_align: flags[:align],
          }
        }

        tag(tag_type, properties, content)
      end

      # Inline elements
      @em = proc { |text| em text }
      @strong = proc { |text| strong text }
      @codespan = proc { |code| code code }
      @br = proc { br }
      @del = proc { |text| del text }
      @link = proc do |href, title, text|
        properties = { href: href, title: title }
          .select { |_, v| v }

        if href =~ %r{^(https?:)?//}
          a(properties, text)
        else
          Link.new(properties, text)
        end
      end
      @image = proc do |src, title, alt|
        img({ src: src, title: title, alt: alt }
              .select { |_, v| v })
      end
    end

    def text_for text
      case `typeof #{text}`
      when :string, :number
        text.to_s
      when :object
        if `!!#{text}.$$class`
          case text
          when Array
            text.map { |t| text_for t }.join
          else
            text.to_s
          end
        elsif `!!#{text}.children`
          text_for `#{text}.children`
        elsif `!!#{text}.text`
          text_for `#{text}.text`
        elsif `#{text} instanceof Array`
          text.map { |t| text_for t }.join
        end
      end
    end
  end
end
