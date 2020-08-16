require 'socket'
require 'thread'

module NFS
  module SUNRPC
    class TCPServer < Server
      def initialize(programs, port = nil, host = '127.0.0.1')
        @server = ::TCPServer.new(host, port)
        @programs = hash_programs(programs)

        @thread = Thread.new do
          loop do
            Thread.new(@server.accept) do |socket|
              loop do
                frame = socket.recv(4).unpack1('N')
                len = frame & ~0x80000000
                break unless len

                data = socket.recv(len)
                result = run_procedure(data)

                if !result.nil?
                  result = [result.length | (128 << 24)].pack('N') + result
                  socket.send(result, 0)
                end
              end
            end
          end
        end

        if block_given?
          begin
            yield(self)
          ensure
            shutdown
          end
        end
      end
    end
  end
end
