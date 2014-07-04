module Rack
  #
  # Rack Middleware for extracting information from the request params and cookies.
  # It populates +env['affiliate.tag']+, # +env['affiliate.from']+ and
  # +env['affiliate.time'] if it detects a request came from an affiliated link 
  #
  class Affiliates
    COOKIE_FROM = "aff_from"
    COOKIE_TIME = "aff_time"

    def initialize(app, opts = {})
      @app = app
      @cookie_ttl = opts[:ttl] || 60*60*24*30  # 30 days
      @cookie_domain = opts[:domain] || nil
      @allow_overwrite = opts[:overwrite].nil? ? true : opts[:overwrite] 
    end

    def call(env)
      req = Rack::Request.new(env)

      from, time = cookie_info(req)

      if from
        if @allow_overwrite
          from, time = params_info(req)
        end
      else
        from, time = params_info(req)
      end

      if from
        env['affiliate.from'] = from
        env['affiliate.time'] = time
      end

      status, headers, body = @app.call(env)

      bake_cookies(headers, from, time)

      [status, headers, body]
    end

    def affiliate_info(req)
      params_info(req) || cookie_info(req) 
    end

    def params_info(req)
      [req.params[@param], req.env["HTTP_REFERER"], Time.now.to_i]
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
