module NFS
  class FileProxy < ::File
    class << self
      def new(*args, &block)
        super(*args, &block)._nfs_setup
      end

      def open(*args)
        f = super(*args)._nfs_setup

        if block_given?
          begin
            return yield(f)
          ensure
            f.close
          end
        end

        f
      end
    end

    def _nfs_setup
      @absolute_path = File.expand_path(path)
      @looked_up = {}
      self
    end

    def create(name, mode, uid, gid)
      f = nil

      begin
        f = self.class.new(_lookup(name), File::RDWR | File::CREAT, mode)
      rescue
        f = self.class.new(_lookup(name), File::RDONLY | File::CREAT, mode)
      end

      stat = f.lstat

      @looked_up[[stat.ino, name]] = f

      [f, stat]
    end

    def _lookup(name)
      File.expand_path(name, @absolute_path)
    end

    def lookup(name)
      f = nil

      begin
        f = self.class.new(_lookup(name), File::RDWR)
      rescue
        f = self.class.new(_lookup(name), File::RDONLY)
      end

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

    def readlink
      File.readlink(@absolute_path)
    end

    def mkdir(name, mode, uid, gid)
      path = _lookup(name)
      Dir.mkdir(path, mode)

      f = self.class.new(path)
      #f.chown(uid, gid)

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
  end
end
