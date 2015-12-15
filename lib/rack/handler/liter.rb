require 'socket'
require 'pry'

module Rack
  module Handler
    class Liter
      def self.run(app, options)
        new.run_server(app, options)
      end

      def run_server(app, options)
        server = TCPServer.new('0.0.0.0', 8080)
        while true
          conn = server.accept

          buf = ""
          # while true
          #   buf << conn.sysread(4096)
          #   binding.pry
          #   break if buf[-4,4] == "\r\n\r\n"
          # end
          buf = "GET / HTTP/1.1\r\nHost: 127.0.0.1:8080\r\nUser-Agent: curl/7.43.0\r\nAccept: */*\r\n\r\n"

          reqs = buf.split("\r\n")
          req = reqs.shift.split
          env = {
            'REQUEST_METHOD'    => req[0],
            'SCRIPT_NAME'       => '',
            'PATH_INFO'         => req[1],
            'QUERY_STRING'      => req[1].split('?').last,
            'SERVER_NAME'       => '0.0.0.0',
            'SERVER_PORT'       => '8080',

            'rack.version'      => [1, 3],
            'rack.url_scheme'   => 'http',
            'rack.input'        => StringIO.new('').set_encoding('BINARY'),
            'rack.errors'       => STDERR,
            'rack.multithread'  => false,
            'rack.multiprocess' => false,
            'rack.run_once'     => false,
          }
          reqs.each do |header|
            header = header.split(": ")
            env["HTTP_" + header[0].upcase.tr('-', '_')] = header[1];
          end
          status, headers, body = app.call(env)
          res_header = "HTTP/1.0 #{status}"
          res_header << "#{Rack::Utils::HTTP_STATUS_CODES[status.to_i]}\r\n"
          headers.each do |k, v|
            res_header << "#{k}: #{v}\r\n"
          end
          res_header << "Connection: close\r\n\r\n"
          conn.write(res_header)
          body.each do |chunk|
            conn.write(chunk)
          end
          conn.close
        end
      end
    end

    register :liter, Liter
  end
end
