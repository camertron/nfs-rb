require 'nfs'

nfs_server = NFS::Server.new(
  dir: File.expand_path(File.join('.', 'orig_dir'), __dir__),
  host: '127.0.0.1',
  port: 1234,
  protocol: :tcp
)

nfs_server.join
