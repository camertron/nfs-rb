require 'fileutils'

module NFS
  class FileProxy
    attr_reader :path

    def initialize(path)
      @path = path
      @absolute_path = File.expand_path(path)
      @looked_up = {}
    end

    def create(name, mode, uid, gid)
      path = _lookup(name)
      f = self.class.new(path)

      unless File.exist?(path)
        FileUtils.touch(path)
      end

      f.chmod(mode)
      f.chown(uid, gid)

      stat = f.lstat
      @looked_up[[stat.ino, name]] = f
      [f, stat]
    end

    def _lookup(name)
      File.expand_path(name, @absolute_path)
    end

    def lookup(name)
      f = self.class.new(_lookup(name))

      stat = f.lstat
      key = [stat.ino, name]

      if @looked_up.include?(key)
        @looked_up[key]
      else
        @looked_up[key] = f
      end
    end

    def delete(name)
      File.delete(_lookup(name))
    end

    def rename(from_name, to_dir, to_name)
      File.rename(_lookup(from_name), to_dir._lookup(to_name))
    end

    def link(dir, name)
      File.link(@absolute_path, dir._lookup(name))
    end

    def symlink(name, to_name)
      File.symlink(to_name, _lookup(name))
    end

    def mkdir(name, mode)
      path = _lookup(name)
      Dir.mkdir(path, mode)

      f = self.class.new(path)

      stat = f.lstat
      @looked_up[[stat.ino, name]] = f

      [f, stat]
    end

    def rmdir(name)
      Dir.delete(_lookup(name))
    end

    def unlink(name)
      File.unlink(_lookup(name))
    end

    def entries
      Dir.entries(@absolute_path)
    end

    def utime(atime, mtime)
      File.utime(atime, mtime, @absolute_path)
    end

    def lstat
      File.lstat(@absolute_path)
    end

    def truncate(len)
      File.truncate(@absolute_path, len)
    end

    def chmod(new_mode)
      File.chmod(new_mode, @absolute_path)
    end

    def chown(uid, gid)
      File.chown(uid, gid, @absolute_path)
    end
  end
end
