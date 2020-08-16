module NFS
  module SUNRPC
    module Client
      @@xid = 0
      @@xid_mutex = Mutex.new

      def method_missing(name, *args)
        procedure = @version.get_procedure(name)

        if procedure.nil?
          raise NoMethodError, name.to_s
        end

        if args.size == 0
          args = [nil]
        end

        if args.size != 1
          raise ArgumentError
        end

        xid = nil

        @@xid_mutex.synchronize do
          xid = @@xid
          @@xid += 1
        end

        message = RpcMsg.encode({
          xid: xid,
          body: {
            _discriminant: :CALL,
            cbody: {
              rpcvers: 2,
              prog: @program.number,
              vers: @version.number,
              proc: procedure.number,
              cred: {
                flavor: :AUTH_NULL,
                body: ''
              },
              verf: {
                flavor: :AUTH_NULL,
                body: ''
              }
            }
          }
        }) + procedure.encode(args[0])

        # This will return the result object or raise an exception that
        # contains the cause of the error.
        sendrecv(message) do |result|
          envelope = RpcMsg.decode(result)

          if envelope[:xid] == xid
            if envelope[:body][:_discriminant] != :REPLY
              raise envelope.inspect
            end

            if envelope[:body][:rbody][:_discriminant] != :MSG_ACCEPTED
              raise envelope[:body][:rbody].inspect
            end

            if envelope[:body][:rbody][:areply][:reply_data][:_discriminant] != :SUCCESS

              raise envelope[:body][:rbody][:areply][:reply_data].inspect
            end

            procedure.decode(result)
          else
            false # false means keep giving us received messages to inspect
          end
        end
      end
    end
  end
end
