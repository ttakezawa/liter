require 'socket'
require 'stringio'
require 'rack/utils'

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
        Signal.trap(:PIPE, 'IGNORE')
        Socket.tcp_server_loop(options[:Host], options[:Port]) do |socket, addr|
          begin
            # Parse Request-Line
            verb, uri, http_version = socket.readline("\r\n").split(' ')
            path_info, query_string = uri.split('?')

            # Initialize Rack environment
            env = {
              'REQUEST_METHOD'    => verb,
              'SCRIPT_NAME'       => '',
              'PATH_INFO'         => path_info,
              'QUERY_STRING'      => query_string || '',
              'SERVER_NAME'       => options[:Host],
              'SERVER_PORT'       => options[:Port],
              'REMOTE_ADDR'       => addr.ip_address,
              'SERVER_PROTOCOL'   => 'HTTP/1.0',
              'rack.version'      => [1, 3],
              'rack.url_scheme'   => 'http',
              'rack.input'        => NULL_IO,
              'rack.errors'       => $stderr,
              'rack.multithread'  => false,
              'rack.multiprocess' => false,
              'rack.run_once'     => false
            }

            # Parse request headers and set to the environment
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
              # Read the request body
              env['rack.input'] = StringIO.new(socket.sysread(content_length))
            end

            # Run a Rack app
            status, headers, body = app.call(env)

            # Create response headers
            response_header = "HTTP/1.0 #{status} #{Rack::Utils::HTTP_STATUS_CODES[status.to_i]}\r\n"
            headers.each do |k, v|
              response_header << "#{k}: #{v}\r\n"
            end
            response_header << "Connection: close\r\n\r\n"

            # Send a response
            socket.syswrite(response_header)
            body.each {|s| socket.syswrite(s)}

          rescue EOFError, Errno::EPIPE
            # The client closed the connection and we have nothing to do.
          ensure
            body.close if body.respond_to? :close
            socket.close
          end
        end
      end
    end

    register :liter, Liter
  end
end
