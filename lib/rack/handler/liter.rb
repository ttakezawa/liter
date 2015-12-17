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
          buf = ''
          while true
            buf << socket.sysread(4096)
            break if buf[-4,4] == "\r\n\r\n"
          end

          reqs = buf.split("\r\n")

          req = reqs.shift.split
          path_info, query_string = req[1].split('?')

          env = {
            'REQUEST_METHOD'    => req[0],
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
          reqs.each do |header|
            header = header.split(': ')
            env['HTTP_' + header[0].upcase.tr('-', '_')] = header[1];
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
