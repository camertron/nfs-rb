# encoding: UTF-8

$:.push(File.dirname(__FILE__))

require 'rspec'
require 'fileutils'
require 'nfs'

RSpec.configure do |config|
  config.before(:suite) do
    $orig_dir = File.expand_path(File.join('.', 'orig_dir'), __dir__)
    $dest_dir = File.expand_path(File.join('.', 'dest_dir'), __dir__)

    FileUtils.mkdir_p($dest_dir)

    $server_pid = Process.spawn(
      "bundle exec ruby #{File.join('spec', 'run_server.rb')}"
    )

    system(
      "mount -t nfs -o "\
        'rsize=8192,wsize=8192,timeo=1,nfsvers=2,proto=tcp,'\
        "port=1234,mountport=1234,"\
        "hard,intr,nolock 127.0.0.1:/ "\
        "#{$dest_dir}"
    )

    if $?.exitstatus != 0
      fail "Unable to mount NFS volume at #{$dest_dir}"
      exit 1
    end
  end

  config.after(:suite) do
    system("umount #{$dest_dir}")

    if $?.exitstatus != 0
      fail "Unable to unmount NFS volume at #{$dest_dir}"
      exit 2
    end

    Process.kill('HUP', $server_pid)
  end
end
