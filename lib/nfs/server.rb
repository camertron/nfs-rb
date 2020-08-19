module NFS
  class Server
    attr_reader :dir, :host, :port, :protocol

    def initialize(dir:, host:, port:, protocol:)
      @dir = dir
      @host = host
      @port = port
      @protocol = protocol

      @handler = Handler.new(FileProxy.new(dir))
      @server = server_class.new(@handler.programs, port, host)
    end

    def join
      @server.join
    end

    def start
      @server.start
    end

    def shutdown
      @server.shutdown
    end

    private

    def server_class
      if protocol == :tcp
        SUNRPC::TCPServer
      elsif protocol == :udp
        SUNRPC::UDPServer
      else
        raise "Unsupported protocol #{protocol}, expected :tcp or :udp"
      end
    end
  end
end
