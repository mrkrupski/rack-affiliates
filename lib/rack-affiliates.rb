module Rack
  #
  # Rack Middleware for extracting information from the request params and cookies.
  # It populates # +env['affiliate.from']+ and
  # +env['affiliate.time'] if it detects a request came from an affiliated link
  #
  class Affiliates
    COOKIE_FROM = "req_from"
    COOKIE_TIME = "req_time"

    def initialize(app, opts = {})
      @app = app
      @cookie_ttl = opts[:ttl] || 60*60*24*30  # 30 days
      @cookie_domain = opts[:domain] || nil
      @allow_overwrite = opts[:overwrite].nil? ? true : opts[:overwrite]
    end

    def call(env)
      req = Rack::Request.new(env)

      http_host    = req.session_options[:domain] || req.env["HTTP_HOST"]
      request_from = req.env["HTTP_REFERER"]
      cookie_from  = req.cookies[COOKIE_FROM]

      self_referer = request_from.try(:include?, http_host)

      unless self_referer
        from, time = cookie_info(req) if cookie_from

        if request_from && request_from != cookie_from
          if from
            from, time = params_info(req) if @allow_overwrite
          else
            from, time = params_info(req)
          end
        end

        if from
          env['req.from'] = from
          env['req.time'] = time
        end
      end

      status, headers, body = @app.call(env)

      unless self_referer
        bake_cookies(headers, from, time) if from != cookie_from
      end

      [status, headers, body]
    end

    def affiliate_info(req)
      params_info(req) || cookie_info(req)
    end

    def params_info(req)
      [req.env["HTTP_REFERER"], Time.now.to_i]
    end

    def cookie_info(req)
      [req.cookies[COOKIE_FROM], req.cookies[COOKIE_TIME].to_i]
    end

    protected
    def bake_cookies(headers, from, time)
      expires = Time.now + @cookie_ttl
      { COOKIE_FROM => from,
        COOKIE_TIME => time }.each do |key, value|
          cookie_hash = {:value => value, :expires => expires}
          cookie_hash[:domain] = @cookie_domain if @cookie_domain
          Rack::Utils.set_cookie_header!(headers, key, cookie_hash)
      end
    end
  end
end
