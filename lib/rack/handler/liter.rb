require 'socket'

module Rack
  module Handler
    class Liter
      DEFAULT_OPTIONS = {
        Host: '0.0.0.0',
        Port: 8080
      }
      SPECIAL_HEADERS = {
        'CONTENT_TYPE'   => true,
        'CONTENT_LENGTH' => true
      }
      NULL_IO = StringIO.new('').set_encoding('BINARY')

      def self.run(app, options)
        serve(app, DEFAULT_OPTIONS.merge(options))
      end

      def self.serve(app, options)
        Signal.trap(:PIPE, "IGNORE")
        Socket.tcp_server_loop(options[:Host], options[:Port]) do |socket, addr|
          verb, uri, http_version = socket.gets("\r\n").split(' ')
          path_info, query_string = uri.split('?')

          env = {
            'REQUEST_METHOD'    => verb,
            'SCRIPT_NAME'       => '',
            'PATH_INFO'         => path_info,
            'QUERY_STRING'      => query_string || '',
            'SERVER_NAME'       => options[:Host],
            'SERVER_PORT'       => options[:Port],
            'REMOTE_ADDR'       => addr.ip_address,
            'rack.version'      => [1, 3],
            'rack.url_scheme'   => 'http',
            'rack.input'        => NULL_IO,
            'rack.errors'       => $stderr,
            'rack.multithread'  => false,
            'rack.multiprocess' => false,
            'rack.run_once'     => false
          }

          socket.each_line("\r\n") do |header|
            break if header == "\r\n"
            key, value = header.split(': ')
            key.upcase!
            key.tr!('-', '_')
            unless SPECIAL_HEADERS.include?(key)
              key.insert(0, 'HTTP_')
            end
            value.chomp!("\r\n")
            env[key] = value
          end

          if (content_length = env['CONTENT_LENGTH'].to_i) > 0
            env['rack.input'] = StringIO.new(socket.read(content_length))
          end

          status, headers, body = app.call(env)

          res_header = "HTTP/1.0 #{status} #{Rack::Utils::HTTP_STATUS_CODES[status.to_i]}\r\n"
          headers.each do |k, v|
            res_header << "#{k}: #{v}\r\n"
          end
          res_header << "Connection: close\r\n\r\n"
          socket.write(res_header)
          body.each {|s| socket.write(s)}
          body.close if body.respond_to? :close

          socket.close
        end
      end
    end

    register :liter, Liter
  end
end
