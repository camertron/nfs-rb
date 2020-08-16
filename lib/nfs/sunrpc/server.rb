module NFS
  module SUNRPC
    class Server
      def host
        @server.addr[2]
      end

      def port
        @server.addr[1]
      end

      def join
        if !@thread.nil?
          @thread.join
        end
      end

      def start
        if @thread.nil?
          @thread.start
        end
      end

      def shutdown
        Thread.kill(@thread)
        @thread = nil
        @server.shutdown
      rescue Errno::ENOTCONN
      end

      private

      def run_procedure(data)
        begin
          xid, program_num, version_num, procedure_num, cred,
            verf = decode_envelope(data)

          program = @programs[program_num]

          if program.nil?
            raise ProgramUnavailable
          else
            result = program.call(
              version_num, procedure_num, data, cred, verf
            )

            create_success_envelope(xid, result)
          end
        rescue IgnoreRequest, RequestDenied, AcceptedError => e
          return e.encode(xid)
        end
      end

      def decode_envelope(data)
        envelope = nil

        begin
          envelope = RpcMsg.decode(data)
        rescue
          raise IgnoreRequest
        end

        if envelope[:body][:_discriminant] != :CALL
          raise IgnoreRequest
        end

        if envelope[:body][:cbody][:rpcvers] != 2
          raise RpcMismatch.new(2, 2, envelope[:xid])
        end

        cbody = envelope[:body][:cbody]

        [
          envelope[:xid],
          cbody[:prog],
          cbody[:vers],
          cbody[:proc],
          cbody[:cred],
          cbody[:verf]
        ]
      end

      def create_success_envelope(xid, result)
        RpcMsg.encode({
          xid: xid,
          body: {
            _discriminant: :REPLY,
            rbody: {
              _discriminant: :MSG_ACCEPTED,
              areply: {
                verf: {
                  flavor: :AUTH_NULL,
                  body: ''
                },
                reply_data: {
                  _discriminant: :SUCCESS,
                  results: ''
                }
              }
            }
          }
        }) + result
      end

      def hash_programs(programs)
        case programs
          when Hash
            programs
          when Array
            programs.each_with_object({}) do |program, result|
              result[program.number] = program
            end
          else
            { programs.number => programs }
        end
      end
    end
  end
end
