module NFS
  module SUNRPC
    class Program
      attr_reader :number, :low, :high

      def initialize(number, &block)
        @number = number
        @versions = {}
        @low = @high = nil
        instance_eval(&block) if block_given?
      end

      def dup
        self.class.new(@number).tap do |p|
          @versions.each_pair do |number, version|
            p.add_version(number, version.dup)
          end
        end
      end

      def add_version(number, ver)
        if @low.nil? or number < @low
          @low = number
        end

        if @high.nil? or number > @high
          @high = number
        end

        @versions[number] = ver
      end

      def version(ver, &block)
        add_version(ver, Version.new(ver, &block))
      end

      def get_version(ver)
        @versions[ver]
      end

      def each_version(&block)
        @versions.each_value(&block)
      end

      def on_call(ver, procedure_name, &block)
        @versions[ver].on_call(procedure_name, &block)
      end

      def call(ver, procedure, arg, cred, verf)
        if !@versions.include?(ver)
          raise ProgramMismatch.new(2, 2)
        end

        @versions[ver].call(procedure, arg, cred, verf)
      end
    end
  end
end
