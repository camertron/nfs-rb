module NFS
  module SUNRPC
    class Procedure
      attr_reader :number

      def initialize(number, returntype, argtype, &block)
        @number = number
        @returntype, @argtype = returntype, argtype
        @block = block
      end

      def dup
        Procedure.new(@number, @returntype, @argtype, &@block)
      end

      def on_call(&block)
        @block = block
      end

      def encode(arg)
        @argtype.encode(arg)
      end

      def decode(value)
        @returntype.decode(value)
      end

      def call(arg, cred, verf)
        begin
          arg_object = @argtype.decode(arg)
        rescue
          raise GarbageArguments
        end

        # Undefined procedures are also unavailable, even if the XDR says it's
        # there. Define your procedures and this won't happen.
        if @block.nil?
          raise ProcedureUnavailable
        end

        result_object = @block.call(arg_object, cred, verf)
        result = nil

        begin
          result = @returntype.encode(result_object)
        rescue => e
          ::NFS.logger.error(e.message)
          ::NFS.logger.error(e.backtrace.join("\n"))
          raise IgnoreRequest
        end

        result
      end
    end
  end
end
