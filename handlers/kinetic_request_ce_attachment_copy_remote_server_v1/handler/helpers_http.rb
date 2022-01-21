require "base64"
require 'net/https'
require 'securerandom'

module HandlerHelpers
  module Http


    #-----------------------------------------------------------------------------
    # HEADER METHODS
    #-----------------------------------------------------------------------------

    def http_json_headers
      {
        "Accept" => "application/json",
        "Content-Type" => "application/json"
      }
    end
    
    
    def http_basic_headers(username, password)
      http_json_headers.merge({
        "Authorization" => "Basic #{Base64.strict_encode64("#{username}:#{password}")}"
      })
    end


    #-----------------------------------------------------------------------------
    # REST METHODS
    #-----------------------------------------------------------------------------

    def http_delete(url, payload, parameters, headers, http_options={})
      uri = URI.parse(url)
      uri.query = URI.encode_www_form(parameters) unless parameters.empty?
      request = Net::HTTP::Delete.new(uri, headers)
      request.body = payload.to_json unless payload.nil? || payload.kind_of?(String)
      send_request(request, http_options)
    end
    
    
    def http_get(url, parameters, headers, http_options={})
      uri = URI.parse(url)
      uri.query = URI.encode_www_form(parameters) unless parameters.empty?
      request = Net::HTTP::Get.new(uri, headers)
      send_request(request, http_options)
    end
    
    
    def http_post(url, payload, parameters, headers, http_options={})
      payload = payload.to_json unless payload.is_a? String
      uri = URI.parse(url)
      uri.query = URI.encode_www_form(parameters) unless parameters.empty?
      request = Net::HTTP::Post.new(uri, headers)
      request.body = payload
      send_request(request, http_options)
    end
    
    
    def http_put(url, payload, parameters, headers, http_options={})
      payload = payload.to_json unless payload.is_a? String
      uri = URI.parse(url)
      uri.query = URI.encode_www_form(parameters) unless parameters.empty?
      request = Net::HTTP::Put.new(uri, headers)
      request.body = payload
      send_request(request, http_options)
    end


    #-----------------------------------------------------------------------------
    # SPECIFIC METHODS
    #-----------------------------------------------------------------------------

    def stream_file_download(file, url, parameters, headers)
      uri = URI.parse(url)
      uri.query = URI.encode_www_form(parameters) unless parameters.empty?

      http = build_http(uri)
      request = Net::HTTP::Get.new(uri, headers)

      http.request(request) do |response|
        open(file, 'w') do |io|
          response.read_body do |chunk|
            io.write chunk
          end
        end
      end
    end


    def upload_file(file, url, parameters, headers)
      uri = URI.parse(url)
      uri.query = URI.encode_www_form(parameters) unless parameters.empty?

      boundary = SecureRandom.hex(16)
      headers["Content-Type"] = "multipart/form-data; boundary=#{boundary}"

      mime_types = MIME::Types.type_for(file)
      mime_type = (!mime_types.empty? && !mime_types.first.nil?) ? mime_types.first.content_type : "application/octet-stream"

      payload = []
      payload << "--#{boundary}\r\n"
      payload << "Content-Disposition: form-data; name=\"file\"; filename=\"#{File.basename(file)}\"\r\n"
      payload << "Content-Type: #{mime_type}\r\n\r\n"
      payload << File.read(file)
      payload << "\r\n\r\n--#{boundary}--\r\n"

      http = build_http(uri)
      request = Net::HTTP::Post.new(uri, headers)
      request.body = payload.join
      
      http.request(request)
    end


    #-----------------------------------------------------------------------------
    # LOWER LEVEL METHODS
    #-----------------------------------------------------------------------------

    def send_request(request, http_options={})
      http = build_http(request.uri, http_options)
      http.request(request)
    end
    
    
    def build_http(uri, http_options={})
      http_options.transform_keys!(&:to_sym)
      http = Net::HTTP.new(uri.host, uri.port)
      if (uri.scheme == 'https')
        http.use_ssl = true
        http.verify_mode = http_options[:ssl_verify] || OpenSSL::SSL::VERIFY_PEER
      end
      http.read_timeout= http_options[:read_timeout] || 30
      http.open_timeout= http_options[:open_timeout] || 30
      http
    end

  end
end
