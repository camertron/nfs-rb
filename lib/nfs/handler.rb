module NFS
  class Handler
    def initialize(root = nil, fsid = 0)
      @mount_prog = Mount::MOUNTPROG.dup
      @mount_vers = Mount::MOUNTVERS
      @nfs_prog = NFS::NFS_PROGRAM.dup
      @nfs_vers = NFS::NFS_VERSION

      @exports = {}
      @fh_table = {}
      @file_objects = {}
      @next_fh = Filehandle.new

      @fsid = fsid

      if !root.nil?
        export('/', root)
      end

      define_mount_procedures
      define_nfs_procedures

      instance_eval(&block) if block_given?
    end

    def programs
      [@mount_prog, @nfs_prog]
    end

    def export(path, file)
      @exports[path] = add_filehandle(file)
    end

    def add_filehandle(file)
      if @file_objects.include?(file)
        @file_objects[file]
      else
        @next_fh.dup.tap do |fh|
          @fh_table[fh] = file
          @file_objects[file] = fh
          @next_fh.increment!
        end
      end
    end

    def handle_errors
      begin
        yield
      rescue Errno::EPERM
        { :_discriminant => :NFSERR_PERM }
      rescue Errno::ENOENT
        { _discriminant: :NFSERR_NOENT }
      rescue Errno::EIO
        { _discriminant: :NFSERR_IO }
      rescue Errno::ENXIO
        { _discriminant: :NFSERR_NXIO }
      rescue Errno::EACCES
        { _discriminant: :NFSERR_ACCES }
      rescue Errno::EEXIST
        { _discriminant: :NFSERR_EXIST }
      rescue Errno::ENODEV
        { _discriminant: :NFSERR_NODEV }
      rescue Errno::ENOTDIR
        { _discriminant: :NFSERR_NOTDIR }
      rescue Errno::EISDIR
        { _discriminant: :NFSERR_ISDIR }
      rescue Errno::EINVAL
        { _discriminant: :NFSERR_INVAL }
      rescue Errno::EFBIG
        { _discriminant: :NFSERR_FBIG }
      rescue Errno::ENOSPC
        { _discriminant: :NFSERR_NOSPC }
      rescue Errno::EROFS
        { _discriminant: :NFSERR_ROFS }
      rescue Errno::ENAMETOOLONG
        { _discriminant: :NFSERR_NAMETOOLONG }
      rescue Errno::ENOTEMPTY
        { _discriminant: :NFSERR_NOTEMPTY }
      rescue Errno::EDQUOT
        { _discriminant: :NFSERR_DQUOT }
      rescue Errno::ESTALE
        { _discriminant: :NFSERR_STALE }
      rescue => e
        # LOG
        ::NFS.logger.error(e.message)
        ::NFS.logger.error(e.backtrace.join("\n"))
        { _discriminant: :NFSERR_IO }
      end
    end

    def define_mount_procedures
      @mount_prog.on_call(@mount_vers, :MNT) do |arg, auth, verf|
        if @exports.include?(arg)
          ::NFS.logger.info("MNT #{arg}")

          {
            _discriminant: :NFS_OK,
            fhs_fhandle: {
              data: @exports[arg]
            }
          }
        else
          { _discriminant: :NFSERR_ACCES }
        end
      end

      @mount_prog.on_call(@mount_vers, :DUMP) do |arg, auth, verf|
        ::NFS.logger.info('DUMP')
        nil
      end

      @mount_prog.on_call(@mount_vers, :UMNT) do |arg, auth, verf|
        ::NFS.logger.info("UMNT #{arg}")
      end

      @mount_prog.on_call(@mount_vers, :UMNTALL) do |arg, auth, verf|
        ::NFS.logger.info("UMNTALL #{arg}")
      end

      export = proc do |arg, auth, verf|
        ::NFS.logger.info('EXPORT')
        result = nil

        @exports.each_key do |name|
          result = {
            ex_dir: name,
            ex_groups: nil,
            ex_next: result
          }
        end

        result
      end

      @mount_prog.on_call(@mount_vers, :EXPORT, &export)
      @mount_prog.on_call(@mount_vers, :EXPORTALL, &export)
    end

    # Convert Ruby Stat object to an NFS fattr
    def convert_attrs(attrs)
      type = :NFNON
      mode = attrs.mode

      if attrs.file?
        type = :NFREG
        mode |= NFS::MODE_REG
      elsif attrs.directory?
        type = :NFDIR
        mode |= NFS::MODE_DIR
      elsif attrs.blockdev?
        type = :NFBLK
        mode |= NFS::MODE_BLK
      elsif attrs.chardev?
        type = :NFCHR
        mode |= NFS::MODE_CHR
      elsif attrs.symlink?
        type = :NFLNK
        mode |= NFS::MODE_LNK
      elsif attrs.socket?
        type = :NFSOCK
        mode |= NFS::MODE_SOCK
      end

      {
        type: type,
        mode: mode,
        nlink: attrs.nlink,
        uid: attrs.uid,
        gid: attrs.gid,
        size: attrs.size,
        blocksize: attrs.blksize,
        rdev: attrs.rdev,
        blocks: attrs.blocks,
        fsid: @fsid,
        fileid: attrs.ino,
        atime: {
          seconds: attrs.atime.tv_sec,
          useconds: attrs.atime.tv_usec
        },
        mtime: {
          seconds: attrs.mtime.tv_sec,
          useconds: attrs.mtime.tv_usec
        },
        ctime: {
          seconds: attrs.ctime.tv_sec,
          useconds: attrs.ctime.tv_usec
        }
      }
    end

    def define_nfs_procedures
      @nfs_prog.on_call(@nfs_vers, :GETATTR) do |arg, auth, verf|
        handle_errors do
          f = @fh_table[arg[:data]]
          attrs = f.lstat

          ::NFS.logger.info("GETATTR #{f.path}")

          {
            _discriminant: :NFS_OK,
            attributes: convert_attrs(attrs)
          }
        end
      end

      @nfs_prog.on_call(@nfs_vers, :SETATTR) do |arg, auth, verf|
        changes = []

        handle_errors do
          f = @fh_table[arg[:file][:data]]
          attrs = convert_attrs(f.lstat)

          # Get -1 represented as an unsigned integer. The sattr fields
          # are -1 to represent that they should not be changed.
          neg_one = 4294967295

          # Start with the mode. Setattr won't change the type of a file
          # and apparently some NFS clients don't set the type, so mask
          # that part out to keep what we have already.
          if arg[:attributes][:mode] != neg_one
            attrs[:mode] &= ~07777
            attrs[:mode] |= 07777 & arg[:attributes][:mode]

            new_mode = arg[:attributes][:mode] & 07777
            changes << "mode: #{new_mode.to_s(8).rjust(5, '0')}"
            f.chmod(new_mode)
          end

          # Next do the UID and GID
          if arg[:attributes][:uid] != neg_one or
            arg[:attributes][:gid] != neg_one

            uid = arg[:attributes][:uid]
            gid = arg[:attributes][:gid]

            if uid == neg_one
              uid = attrs[:uid]
            end

            if gid == neg_one
              gid = attrs[:gid]
            end

            attrs[:uid] = uid
            attrs[:gid] = gid

            changes << "uid: #{uid}"
            changes << "gid: #{gid}"

            f.chown(uid, gid)
          end

          # Set size (truncate)
          if arg[:attributes][:size] != neg_one
            attrs[:size] = arg[:attributes][:size]
            changes << "size: #{attrs[:size]}"
            f.truncate(arg[:attributes][:size])
          end

          # Set time
          if arg[:attributes][:atime][:seconds] != neg_one or
            arg[:attributes][:mtime][:seconds] != neg_one

            atime = arg[:attributes][:atime]
            mtime = arg[:attributes][:mtime]

            if atime[:seconds] == neg_one
              atime = attrs[:atime]
            end

            if mtime[:seconds] == neg_one
              mtime = attrs[:mtime]
            end

            attrs[:atime] = atime
            attrs[:mtime] = mtime

            atime = Time.at(atime[:seconds], atime[:useconds])
            mtime = Time.at(mtime[:seconds], mtime[:useconds])

            changes << "atime: #{atime}"
            changes << "mtime: #{mtime}"

            f.utime(atime, mtime)
          end

          ::NFS.logger.info("SETATTR #{f} #{changes.join(', ')}")

          {
            _discriminant: :NFS_OK,
            attributes: attrs
          }
        end
      end

      @nfs_prog.on_call(@nfs_vers, :ROOT) do |arg, auth, verf|
        ::NFS.logger.info('ROOT')
        # obsolete
      end

      @nfs_prog.on_call(@nfs_vers, :LOOKUP) do |arg, auth, verf|
        handle_errors do
          f = @fh_table[arg[:dir][:data]].lookup(arg[:name])
          ::NFS.logger.info("LOOKUP #{f.path}")
          fh = add_filehandle(f)
          attrs = f.lstat

          result = {
            _discriminant: :NFS_OK,
            diropres: {
              file: {
                data: fh
              },
              attributes: convert_attrs(attrs)
            }
          }

          result
        end
      end

      @nfs_prog.on_call(@nfs_vers, :READLINK) do |arg, auth, verf|
        handle_errors do
          f = @fh_table[arg[:data]]
          ::NFS.logger.info("READLINK #{f.path}")
          result = f.readlink

          {
            _discriminant: :NFS_OK,
            data: result
          }
        end
      end

      @nfs_prog.on_call(@nfs_vers, :READ) do |arg, auth, verf|
        handle_errors do
          fh = @fh_table[arg[:file][:data]]
          ::NFS.logger.info("READ #{fh.path}")
          attrs = fh.lstat

          File.open(fh.path) do |f|
            f.pos = arg[:offset]
            result = f.read(arg[:count])

            {
              _discriminant: :NFS_OK,
              reply: {
                attributes: convert_attrs(attrs),
                data: result
              }
            }
          end
        end
      end

      @nfs_prog.on_call(@nfs_vers, :WRITECACHE) do |arg, auth, verf|
        ::NFS.logger.info('WRITECACHE')
      end

      @nfs_prog.on_call(@nfs_vers, :WRITE) do |arg, auth, verf|

        handle_errors do
          fh = @fh_table[arg[:file][:data]]
          ::NFS.logger.info("WRITE #{fh.path}")

          File.open(fh.path) do |f|
            f.pos = arg[:offset]
            f.write(arg[:data])
            f.flush
            attrs = f.lstat

            {
              _discriminant: :NFS_OK,
              attributes: convert_attrs(attrs)
            }
          end
        end
      end

      @nfs_prog.on_call(@nfs_vers, :CREATE) do |arg, auth, verf|
        handle_errors do
          dir = @fh_table[arg[:where][:dir][:data]]
          name = arg[:where][:name]
          ::NFS.logger.info("CREATE #{name}")

          f, attrs = dir.create(
            name,
            arg[:attributes][:mode], arg[:attributes][:uid],
            arg[:attributes][:gid]
          )

          fh = add_filehandle(f)

          {
            _discriminant: :NFS_OK,
            diropres: {
              file: {
                data: fh
              },
              attributes: convert_attrs(attrs)
            }
          }
        end
      end

      @nfs_prog.on_call(@nfs_vers, :REMOVE) do |arg, auth, verf|
        (handle_errors do
          dir = @fh_table[arg[:dir][:data]]
          name = arg[:name]
          ::NFS.logger.info("REMOVE #{name}")
          dir.unlink(name)

          { _discriminant: :NFS_OK }
        end)[:_discriminant]
      end

      @nfs_prog.on_call(@nfs_vers, :RENAME) do |arg, auth, verf|
        (handle_errors do
          from_dir = @fh_table[arg[:from][:dir][:data]]
          from_name = arg[:from][:name]
          to_dir = @fh_table[arg[:to][:dir][:data]]
          to_name = arg[:to][:name]

          ::NFS.logger.info(
            "RENAME #{File.join(from_dir.path, from_name)} -> #{File.join(to_dir.path, to_name)}"
          )

          from_dir.rename(from_name, to_dir, to_name)

          { _discriminant: :NFS_OK }
        end)[:_discriminant]
      end

      @nfs_prog.on_call(@nfs_vers, :LINK) do |arg, auth, verf|
        (handle_errors do
          from = @fh_table[arg[:from][:data]]
          to_dir = @fh_table[arg[:to][:dir][:data]]
          to_name = arg[:to][:name]

          ::NFS.logger.info("LINK #{from.path} -> #{File.join(to_dir.path, to_name)}")

          from.link(to_dir, to_name)

          { _discriminant: :NFS_OK }
        end)[:_discriminant]
      end

      @nfs_prog.on_call(@nfs_vers, :SYMLINK) do |arg, auth, verf|
        (handle_errors do
          dir = @fh_table[arg[:from][:dir][:data]]
          name = arg[:from][:name]
          to_name = arg[:to]
          attrs = arg[:attributes]

          ::NFS.logger.info("SYMLINK #{File.join(dir.path, name)} -> #{to_name}")

          dir.symlink(name, to_name)

          { _discriminant: :NFS_OK }
        end)[:_discriminant]
      end

      @nfs_prog.on_call(@nfs_vers, :MKDIR) do |arg, auth, verf|
        handle_errors do
          dir = @fh_table[arg[:where][:dir][:data]]
          name = arg[:where][:name]

          ::NFS.logger.info("MKDIR #{name}")

          f, attrs = dir.mkdir(name, arg[:attributes][:mode],
            arg[:attributes][:uid], arg[:attributes][:gid])

          fh = add_filehandle(f)

          {
            _discriminant: :NFS_OK,
            diropres: {
              file: {
                data: fh
              },
              attributes: convert_attrs(attrs)
            }
          }
        end
      end

      @nfs_prog.on_call(@nfs_vers, :RMDIR) do |arg, auth, verf|
        (handle_errors do
          dir = @fh_table[arg[:dir][:data]]
          name = arg[:name]
          ::NFS.logger.info("RMDIR #{name}")
          dir.rmdir(name)

          { _discriminant: :NFS_OK}
        end)[:_discriminant]
      end

      @nfs_prog.on_call(@nfs_vers, :READDIR) do |arg, auth, verf|
        handle_errors do
          dir = @fh_table[arg[:dir][:data]]
          ::NFS.logger.info("READDIR #{dir.path}")

          cookie = arg[:cookie]
          count = arg[:count]

          need_bytes = 16 + 12

          entries = dir.entries

          result_entries = nil
          last_entry = nil

          while cookie < entries.size && need_bytes < count
            need_bytes += NFS::Filename.encode(entries[cookie]).size

            next_entry = {
              fileid: 1,
              name: entries[cookie],
              cookie: cookie
            }

            if !last_entry.nil?
              last_entry[:nextentry] = next_entry
              last_entry = next_entry
            end

            if result_entries.nil?
              result_entries = next_entry
              last_entry = next_entry
            end

            cookie += 1
            need_bytes += 16
          end

          eof = :TRUE

          if need_bytes > count
            eof = :FALSE
          end

          if !last_entry.nil?
            last_entry[:nextentry] = nil
          end

          {
            _discriminant: :NFS_OK,
            reply: {
              entries: result_entries,
              eof: eof
            }
          }
        end
      end

      @nfs_prog.on_call(@nfs_vers, :STATFS) do |arg, auth, verf|
        ::NFS.logger.info('STATFS')

        handle_errors do
          {
            _discriminant: :NFS_OK,
            reply: {
              tsize: 1024,
              bsize: 1024,
              blocks: 100,
              bfree: 100,
              bavail: 100
            }
          }
        end
      end
    end

    attr_reader :root
  end
end
