module ActionDispatch
  # A simple Rack application that renders exceptions in the given public path.
  class PublicExceptions
    attr_accessor :public_path

    def initialize(public_path)
      @public_path = public_path
    end

    def call(env)
      status       = env["PATH_INFO"][1..-1]
      locale_path  = "#{public_path}/#{status}.#{I18n.locale}.html" if I18n.locale
      path         = "#{public_path}/#{status}.html"
      locale_asset = "#{Rails.root}/app/assets/public/#{status}.html" if I18n.locale
      asset        = "#{Rails.root}/app/assets/public/#{status}.html"

      if locale_path && File.exist?(locale_path)
        render(status, File.read(locale_path))
      elsif File.exist?(path)
        render(status, File.read(path))
      elsif locale_asset && File.exist?(locale_asset)
        render(status, File.read(locale_asset))
      elsif File.exist(asset)
        render(status, File.read(asset))
      else
        [404, { "X-Cascade" => "pass" }, []]
      end
    end

    private

    def render(status, body)
      [status, {'Content-Type' => "text/html; charset=#{Response.default_charset}", 'Content-Length' => body.bytesize.to_s}, [body]]
    end
  end
end