require 'socket'
require 'pry'

module Rack
  module Handler
    class Liter
      DEFAULT_OPTIONS = {
        Host: '0.0.0.0',
        Port: 8080,
      }

      def self.run(app, options)
        options = DEFAULT_OPTIONS.merge(options)
        new.run(app, options)
      end

      def run(app, options)
        Socket.tcp_server_loop(options[:Host], options[:Port]) do |socket, addr|
          verb, uri, http_version = socket.gets.split(' ')
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
            'rack.input'        => StringIO.new('').set_encoding('BINARY'),
            'rack.errors'       => STDERR,
            'rack.multithread'  => false,
            'rack.multiprocess' => false,
            'rack.run_once'     => false,
          }

          while (header = socket.gets).start_with?("\r\n")
            k, v = header.split(': ')
            env["HTTP_#{k.upcase.tr('-', '_')}"] = v
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
