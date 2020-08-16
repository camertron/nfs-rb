# Ruby XDR based implementation of SUNRPC. Based on RFC 1057.

module NFS
  module SUNRPC
    autoload :Client,    'nfs/sunrpc/client'
    autoload :Procedure, 'nfs/sunrpc/procedure'
    autoload :Program,   'nfs/sunrpc/program'
    autoload :Server,    'nfs/sunrpc/server'
    autoload :TCPServer, 'nfs/sunrpc/tcp_server'
    autoload :UDPClient, 'nfs/sunrpc/udp_client'
    autoload :UDPServer, 'nfs/sunrpc/udp_server'
    autoload :Version,   'nfs/sunrpc/version'

    include XDR

    MAXAUTHLEN = 400
    AUTH_UNIX_MAXMACHINENAMELEN = 255
    AUTH_UNIX_MAXGIDS = 16

    AuthFlavor = Enumeration.new do
      name :AUTH_NULL, 0
      name :AUTH_UNIX, 1
      name :AUTH_SHORT, 2
      name :AUTH_DES, 3
      # and more to be defined?
    end

    OpaqueAuth = Structure.new do
      component :flavor, AuthFlavor
      component :body, Opaque.new(MAXAUTHLEN)
    end

    AuthUnix = Structure.new do
      component :stamp, UnsignedInteger.new
      component :machinename, DynamicString.new(AUTH_UNIX_MAXMACHINENAMELEN)
      component :uid, UnsignedInteger.new
      component :gid, UnsignedInteger.new
      component :gids, DynamicArray.new(UnsignedInteger.new, AUTH_UNIX_MAXGIDS)
    end

    AuthDESNamekind = Enumeration.new do
      name :ADN_FULLNAME, 0
      name :ADN_NICKNAME, 1
    end

    DESBlock = FixedOpaque.new(8)

    MAXNETNAMELEN = 255

    AuthDESFullname = Structure.new do
      component :name, DynamicString.new(MAXNETNAMELEN) # name of client
      component :key, DESBlock                          # PK encrypted conversation key
      component :window, FixedOpaque.new(4)             # encrypted window
    end

    AuthDESCred = Union.new(AuthDESNamekind) do
      arm :ADN_FULLNAME do
        component :adc_fullname, AuthDESFullname
      end

      arm :ADN_NICKNAME do
        component :adc_nickname, SignedInteger.new
      end
    end

    Timestamp = Structure.new do
      component :seconds, UnsignedInteger.new  # seconds
      component :useconds, UnsignedInteger.new # microseconds
    end

    AuthDESVerfClnt = Structure.new do
      component :adv_timestamp, DESBlock         # encrypted timestamp
      component :adv_winverf, FixedOpaque.new(4) # encrypted window verifier
    end

    AuthDESVerfSvr = Structure.new do
      component :adv_timeverf, DESBlock          # encrypted verifier
      component :adv_nickname, SignedInteger.new # nickname for client (unencrypted)
    end

    MsgType = Enumeration.new do
      name :CALL, 0
      name :REPLY, 1
    end

    ReplyStat = Enumeration.new do
      name :MSG_ACCEPTED, 0
      name :MSG_DENIED, 1
    end

    AcceptStat = Enumeration.new do
      name :SUCCESS, 0       # RPC executed successfully
      name :PROG_UNAVAIL, 1  # remote hasn't exported program
      name :PROG_MISMATCH, 2 # remote can't support version number
      name :PROC_UNAVAIL, 3  # program can't support procedure
      name :GARBAGE_ARGS, 4  # procedure can't decode params
    end

    RejectStat = Enumeration.new do
      name :RPC_MISMATCH, 0 # RPC version number != 2
      name :AUTH_ERROR, 1   # remote can't authenticate caller
    end

    AuthStat = Enumeration.new do
      name :AUTH_BADCRED, 1      # bad credentials (seal broken)
      name :AUTH_REJECTEDCRED, 2 # client must begin new session
      name :AUTH_BADVERF, 3      # bad verifier (seal broken)
      name :AUTH_REJECTEDVERF, 4 # verifier expired or replayed
      name :AUTH_TOOWEAK, 5      # rejected for security reasons
    end

    CallBody = Structure.new do
      component :rpcvers, UnsignedInteger.new # must be equal to two (2)
      component :prog, UnsignedInteger.new
      component :vers, UnsignedInteger.new
      component :proc, UnsignedInteger.new
      component :cred, OpaqueAuth
      component :verf, OpaqueAuth
      # procedure specific parameters start here
    end

    AcceptedReply = Structure.new do
      component :verf, OpaqueAuth
      component :reply_data, Union.new(AcceptStat) do
        arm :SUCCESS do
          component :results, FixedOpaque.new(0)
          # Procedure specific results start here
        end

        arm :PROG_MISMATCH do
          component :mismatch_info, Structure.new do
            component :low, UnsignedInteger.new
            component :high, UnsignedInteger.new
          end
        end

        default do
          # Void. Cases include PROG_UNAVAIL, PROC_UNAVAIL, and GARBAGE_ARGS.
        end
      end
    end

    RejectedReply = Union.new(RejectStat) do
      arm :RPC_MISMATCH do
        component :mismatch_info, Structure.new do
          component :low, UnsignedInteger.new
          component :high, UnsignedInteger.new
        end
      end

      arm :AUTH_ERROR do
        component :stat, AuthStat
      end
    end

    ReplyBody = Union.new(ReplyStat) do
      arm :MSG_ACCEPTED do
        component :areply, AcceptedReply
      end

      arm :MSG_DENIED do
        component :rreply, RejectedReply
      end
    end

    RpcMsg = Structure.new do
      component :xid, UnsignedInteger.new
      component :body, (Union.new(MsgType) do
        arm :CALL do
          component :cbody, CallBody
        end

        arm :REPLY do
          component :rbody, ReplyBody
        end
      end)
    end

    # Server Exceptions

    class IgnoreRequest < Exception
      def encode(xid)
        nil
      end
    end

    # Abstract base of "rejected" errors
    class RequestDenied < Exception
      def encode(xid)
        RpcMsg.encode({
          xid: xid,
          body: {
            _discriminant: :REPLY,
            rbody: {
              _discriminant: :MSG_DENIED,
              rreply: rreply
            }
          }
        })
      end
    end

    class RpcMismatch < RequestDenied
      # RPC mismatch takes the xid since, it won't actually have one
      # passed to its encode method.
      def initialize(low, high, xid)
        @low, @high, @xid = low, high, xid
      end

      def encode(xid)
        RpcMsg.encode({
          xid: @xid,
          body: {
            _discriminant: :REPLY,
            rbody: {
              _discriminant: :MSG_DENIED,
              rreply: rreply
            }
          }
        })
      end

      private

      def rreply
        {
          _discriminant: :RPC_MISMATCH,
          mismatch_info: {
            low: @low,
            high: @high
          }
        }
      end
    end

    # Abstract base of authentication errors
    class AuthenticationError < RequestDenied
      private

      def rreply
        {
          _discriminant: :AUTH_ERROR,
          stat: AuthStat
        }
      end
    end

    class BadCredentials < AuthenticationError
      private

      def auth_stat
        :AUTH_BADCRED
      end
    end

    class RejectedCredentials < AuthenticationError
      private

      def auth_stat
        :AUTH_REJECTEDCRED
      end
    end

    class BadVerifier < AuthenticationError
      private

      def auth_stat
        :AUTH_BADVERF
      end
    end

    class RejectedVerifier < AuthenticationError
      private

      def auth_stat
        :AUTH_REJECTEDVERF
      end
    end

    class TooWeak < AuthenticationError
      private

      def auth_stat
        :AUTH_TOOWEAK
      end
    end

    # Abstract base of errors where the message was "accepted"
    class AcceptedError < Exception
      def encode(xid)
        RpcMsg.encode({
          xid: xid,
          body: {
            _discriminant: :REPLY,
            rbody: {
              _discriminant: :MSG_ACCEPTED,
              areply: areply
            }
          }
        })
      end
    end

    # Program not supported
    class ProgramUnavailable < AcceptedError
      private

      def areply
        {
          verf: { flavor: :AUTH_NULL, body: '' },
          reply_data: {
            _discriminant: :PROG_UNAVAIL
          }
        }
      end
    end

    # Version not supported
    class ProgramMismatch < AcceptedError
      def initialize(low, high)
        @low, @high = low, high
      end

      private

      def areply
        {
          verf: { flavor: :AUTH_NULL, body: '' },
          reply_data: {
            _discriminant: :PROG_MISMATCH,
            low: @low,
            high: @high
          }
        }
      end
    end

    # Procedure not supported
    class ProcedureUnavailable < AcceptedError
      private

      def areply
        {
          verf: { flavor: :AUTH_NULL, body: '' },
          reply_data: {
            _discriminant: :PROC_UNAVAIL
          }
        }
      end
    end

    class GarbageArguments < AcceptedError
      private

      def areply
        {
          verf: { flavor: :AUTH_NULL, body: '' },
          reply_data: {
            _discriminant: :GARBAGE_ARGS
          }
        }
      end
    end
  end
end
