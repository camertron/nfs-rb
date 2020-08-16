require 'logger'

module NFS
  class DefaultLogger < Logger
    def initialize(*args)
      super

      self.formatter = proc do |severity, datetime, _progname, msg|
        "[#{datetime} nfs-rb]  #{severity} -- : #{msg}\n"
      end
    end
  end
end
