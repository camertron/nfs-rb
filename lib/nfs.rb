module NFS
  class << self
    attr_accessor :logger
  end

  autoload :DefaultLogger, 'nfs/default_logger'
  autoload :FileProxy,     'nfs/file_proxy'
  autoload :Filehandle,    'nfs/filehandle'
  autoload :Mount,         'nfs/mount'
  autoload :NFS,           'nfs/nfs'
  autoload :Handler,       'nfs/handler'
  autoload :Server,        'nfs/server'
  autoload :SUNRPC,        'nfs/sunrpc'
  autoload :XDR,           'nfs/xdr'
end

NFS.logger = NFS::DefaultLogger.new(STDOUT)
