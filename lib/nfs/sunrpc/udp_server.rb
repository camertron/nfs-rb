require 'socket'
require 'thread'

module NFS
  module SUNRPC
    class UDPServer < Server
      def initialize(programs, port = nil, host = '127.0.0.1')
        @socket = UDPSocket.open
        @socket.bind(host, port)
        socketmutex = Mutex.new
        @programs = hash_programs(programs)

        @thread = Thread.new do
          loop do
            request = @socket.recvfrom(UDPClient::UDPRecvMTU)
            data = request[0]
            port = request[1][1]
            host = request[1][3]

            Thread.new do
              result = run_procedure(data)

              if !result.nil?
                socketmutex.synchronize do
                  @socket.send(result, 0, host, port)
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
