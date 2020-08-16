# Ruby XDR. XDR codec for Ruby. Based on RFC 4506.

module NFS
  module XDR
    class Void
      def encode(value)
        ''
      end

      def decode(string)
        nil
      end
    end

    class SignedInteger
      def encode(value)
        [value].pack('N')
      end

      def decode(string)
        string.slice!(0..3).unpack('N').pack('I').unpack('i')[0]
      end
    end

    class UnsignedInteger
      def encode(value)
        [value].pack('N')
      end

      def decode(string)
        string.slice!(0..3).unpack('N')[0]
      end
    end

    class Enumeration < SignedInteger
      def initialize(&block)
        @values = {}
        @names = {}

        if block_given?
          instance_eval(&block)
        end
      end

      def name(v_name, value)
        @values[v_name] = value
        @names[value] = v_name
      end

      def encode(name)
        super(@values[name])
      end

      def decode(string)
        @names[super(string)]
      end
    end

    class Boolean < Enumeration
      def initialize
        super

        name :TRUE, 1
        name :FALSE, 0
      end
    end

    class FloatNum
      def encode(value)
        [value].pack('g')
      end

      def decode(string)
        string.slice!(0..3).unpack('g')[0]
      end
    end

    class DoubleNum
      def encode(value)
        [value].pack('G')
      end

      def decode(string)
        string.slice!(0..7).unpack('G')[0]
      end
    end

    def self.pad(n, align)
      r = n % align
      r = align if r == 0
      n + align - r
    end

    class FixedString
      def initialize(n)
        @n = n
      end

      def encode(value)
        [value.to_s].pack('a' + XDR.pad(@n, 4).to_s)
      end

      def decode(string)
        superstring = string.slice!(0, XDR.pad(@n, 4))
        superstring.nil? ? '' : superstring[0, @n]
      end
    end

    class DynamicString
      def initialize(n = nil)
        @n = n
        @length = UnsignedInteger.new
      end

      def encode(value)
        value = value.to_s
        n = value.size
        n = @n if !@n.nil? && @n < n
        @length.encode(n) + [value].pack('a' + XDR::pad(n, 4).to_s)
      end

      def decode(string)
        length = @length.decode(string)
        superstring = string.slice!(0, XDR.pad(length, 4))
        superstring.nil? ? '' : superstring[0, length]
      end
    end

    class FixedOpaque < FixedString
    end

    class Opaque < DynamicString
    end

    class FixedArray
      def initialize(type, n)
        @type, @n = type, n
      end

      def encode(value)
        n.times do |i|
          @type.encode(value[i])
        end
      end

      def decode(string)
        Array.new(n) do
          @type.decode(string)
        end
      end
    end

    class DynamicArray
      def initialize(type, n)
        @type, @n = type, n
        @length = UnsignedInteger.new
      end

      def encode(value)
        n = value.size

        if !@n.nil? && @n < n
          n = @n
        end

        result = @length.encode(n)

        n.times do |i|
          result << @type.encode(value[i])
        end

        result
      end

      def decode(string)
        length = @length.decode(string)

        Array.new(length) do
          @type.decode(string)
        end
      end
    end

    class Optional < DynamicArray
      def initialize(type)
        super(type, 1)
      end

      def encode(value)
        if value.nil?
          super([])
        else
          super([value])
        end
      end

      def decode(string)
        result = super(string)

        if result.empty?
          nil
        else
          result[0]
        end
      end
    end

    class Structure
      def initialize(&block)
        @components = []
        @names = []
        instance_eval(&block) if block_given?
      end

      def component(name, type)
        @components << [name, type]
        @names << name
      end

      def encode(value)
        ''.tap do |result|
          @components.each do |component|
            unless value.include?(component[0])
              raise 'missing structure component ' + component[0].to_s
            end

            result << component[1].encode(value[component[0]])
          end
        end
      end

      def decode(string)
        @components.each_with_object({}) do |component, result|
          result[component[0]] = component[1].decode(string)
        end
      end
    end

    # Each arm of the union is represented as a struct
    class Union
      def initialize(disc_type, &block)
        @disc_type = disc_type
        @arms = {}
        @default_arm = nil
        instance_eval(&block) if block_given?
      end

      # Add an arm
      def arm(disc_value, struct = nil, &block)
        if block_given?
          struct = Structure.new(&block)
        end

        @arms[disc_value] = struct
      end

      # Set the default arm
      def default(struct = nil, &block)
        if block_given?
          struct = Structure.new(&block)
        end

        @default_arm = struct
      end

      def encode(struct)
        disc = struct[:_discriminant]
        arm = @default_arm
        arm = @arms[disc] if @arms.include?(disc)
        result = @disc_type.encode(disc)

        unless arm.nil?
          result << arm.encode(struct)
        end

        result
      end

      def decode(string)
        disc = @disc_type.decode(string)
        arm = @default_arm

        if @arms.include?(disc)
          arm = @arms[disc]
        end

        result = nil

        if arm.nil?
          result = {}
        else
          result = arm.decode(string)
        end

        result[:_discriminant] = disc
        result
      end
    end
  end
end
