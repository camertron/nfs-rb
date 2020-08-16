module NFS
  class Filehandle < ::String
    def initialize
      super("\0".b * NFS::FHSIZE)
    end

    def increment!
      size.times do |i|
        self[i] += 1
        return self if self[i] != 0
      end

      self
    end

    def [](idx)
      getbyte(idx)
    end

    def []=(idx, newval)
      setbyte(idx, newval)
    end
  end
end
