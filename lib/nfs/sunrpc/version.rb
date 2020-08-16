module NFS
  module SUNRPC
    class Version
      attr_reader :number

      def initialize(number, &block)
        @number = number
        @procedures = {}
        @procedure_names = {}

        # Add the customary null procedure by default.
        procedure XDR::Void.new, :NULL, 0, XDR::Void.new do
          # do nothing
        end

        instance_eval(&block) if block_given?
      end

      def dup
        Version.new(@number).tap do |v|
          @procedure_names.each_pair do |name, procedure|
            v.add_procedure(name, procedure.number, procedure.dup)
          end
        end
      end

      def add_procedure(name, number, newproc)
        @procedures[number] = newproc
        @procedure_names[name] = newproc
      end

      # The name is required, but just for documentation.
      def procedure(returntype, name, number, argtype, &block)
        newproc = Procedure.new(number, returntype, argtype, &block)
        add_procedure(name, number, newproc)
      end

      def get_procedure(procedure_name)
        @procedure_names[procedure_name]
      end

      def on_call(procedure_name, &block)
        @procedure_names[procedure_name].on_call(&block)
      end

      def call(p, arg, cred, verf)
        unless @procedures.include?(p)
          raise ProcedureUnavailable
        end

        @procedures[p].call(arg, cred, verf)
      end
    end
  end
end
