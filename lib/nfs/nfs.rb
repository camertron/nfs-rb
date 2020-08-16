# A port of the NFSv2 XDR specification to Ruby XDR/SUNRPC. Based on RFC 1094.

module NFS
  module NFS
    include SUNRPC

    PORT       = 2049
    MAXDATA    = 8192
    MAXPATHLEN = 1024
    MAXNAMELEN = 255
    FHSIZE     = 32
    FIFO_DEV   = -1 # size kludge for named pipes

    MODE_FMT  = 0170000 # type of file
    MODE_DIR  = 0040000 # directory
    MODE_CHR  = 0020000 # character special
    MODE_BLK  = 0060000 # block special
    MODE_REG  = 0100000 # regular
    MODE_LNK  = 0120000 # symbolic link
    MODE_SOCK = 0140000 # socket
    MODE_FIFO = 0010000 # fifo

    NFSStat = Enumeration.new do
      name :NFS_OK, 0              # no error
      name :NFSERR_PERM, 1         # Not owner
      name :NFSERR_NOENT, 2        # No such file or directory
      name :NFSERR_IO, 5           # I/O error
      name :NFSERR_NXIO, 6         # No such device or address
      name :NFSERR_ACCES, 13       # Permission denied
      name :NFSERR_EXIST, 17       # File exists
      name :NFSERR_NODEV, 19       # No such device
      name :NFSERR_NOTDIR, 20      # Not a directory
      name :NFSERR_ISDIR, 21       # Is a directory
      name :NFSERR_INVAL, 22       # Invalid argument
      name :NFSERR_FBIG, 27        # File too large
      name :NFSERR_NOSPC, 28       # No space left on device
      name :NFSERR_ROFS, 30        # Read-only file system
      name :NFSERR_NAMETOOLONG, 63 # File name too long
      name :NFSERR_NOTEMPTY, 66    # Directory not empty
      name :NFSERR_DQUOT, 69       # Disc quota exceeded
      name :NFSERR_STALE, 70       # Stale NFS file handle
      name :NFSERR_WFLUSH, 99      # Write cache flushed
    end

    FType = Enumeration.new do
      name :NFNON, 0  # non-file
      name :NFREG, 1  # regular file
      name :NFDIR, 2  # directory
      name :NFBLK, 3  # block special
      name :NFCHR, 4  # character special
      name :NFLNK, 5  # symbolic link
      name :NFSOCK, 6 # unix domain sockets
      name :NFBAD, 7  # unused
      name :NFFIFO, 8 # named pipe
    end

    NFSFh = Structure.new do
      component :data, FixedOpaque.new(FHSIZE)
    end

    NFSTime = Structure.new do
      component :seconds, UnsignedInteger.new
      component :useconds, UnsignedInteger.new
    end

    FAttr = Structure.new do
      component :type, FType                    # file type
      component :mode, UnsignedInteger.new      # protection mode bits
      component :nlink, UnsignedInteger.new     # number of hard links
      component :uid, UnsignedInteger.new       # owner user id
      component :gid, UnsignedInteger.new       # owner group id
      component :size, UnsignedInteger.new      # file size in bytes
      component :blocksize, UnsignedInteger.new # prefered block size
      component :rdev, UnsignedInteger.new      # special device number
      component :blocks, UnsignedInteger.new    # Kb of disk used by file
      component :fsid, UnsignedInteger.new      # device number
      component :fileid, UnsignedInteger.new    # inode number
      component :atime, NFSTime # time of last access
      component :mtime, NFSTime # time of last modification
      component :ctime, NFSTime # time of last change
    end

    SAttr = Structure.new do
      component :mode, UnsignedInteger.new # protection mode bits
      component :uid, UnsignedInteger.new  # owner user id
      component :gid, UnsignedInteger.new  # owner group id
      component :size, UnsignedInteger.new # file size in bytes
      component :atime, NFSTime            # time of last access
      component :mtime, NFSTime            # time of last modification
    end

    Filename = DynamicString.new(MAXNAMELEN)
    NFSPath = DynamicString.new(MAXPATHLEN)

    AttrStat = Union.new(NFSStat) do
      arm :NFS_OK do
        component :attributes, FAttr
      end

      default do
      end
    end

    SAttrArgs = Structure.new do
      component :file, NFSFh
      component :attributes, SAttr
    end

    DirOpArgs = Structure.new do
      component :dir, NFSFh
      component :name, Filename
    end

    DirOpOkRes = Structure.new do
      component :file, NFSFh
      component :attributes, FAttr
    end

    DirOpRes = Union.new(NFSStat) do
      arm :NFS_OK do
        component :diropres, DirOpOkRes
      end

      default do
      end
    end

    ReadLinkRes = Union.new(NFSStat) do
      arm :NFS_OK do
        component :data, NFSPath
      end

      default do
      end
    end

    # Arguments to remote read
    ReadArgs = Structure.new do
      component :file, NFSFh                       # handle for file
      component :offset, UnsignedInteger.new     # byte offset in file
      component :count, UnsignedInteger.new      # immediate read count
      component :totalcount, UnsignedInteger.new # read count from offset
    end

    # Status OK portion of remote read reply
    ReadOkRes = Structure.new do
      component :attributes, FAttr # Attributes needed for pagin ??
      component :data, Opaque.new(MAXDATA)
    end

    ReadRes = Union.new(NFSStat) do
      arm :NFS_OK do
        component :reply, ReadOkRes
      end

      default do
      end
    end

    # Arguments to remote write
    WriteArgs = Structure.new do
      component :file, NFSFh                     # handle for file
      component :beginoffset, UnsignedInteger.new # begin. byte offset in file
      component :offset, UnsignedInteger.new      # curr. byte offset in file
      component :totalcount, UnsignedInteger.new  # write count to this offset
      component :data, Opaque.new(MAXDATA)        # data
    end

    CreateArgs = Structure.new do
      component :where, DirOpArgs
      component :attributes, SAttr
    end

    RenameArgs = Structure.new do
      component :from, DirOpArgs
      component :to, DirOpArgs
    end

    LinkArgs = Structure.new do
      component :from, NFSFh
      component :to, DirOpArgs
    end

    SymlinkArgs = Structure.new do
      component :from, DirOpArgs
      component :to, NFSPath
      component :attributes, SAttr
    end

    NFSCookie = UnsignedInteger.new

    # Arguments to readdir
    ReadDirArgs = Structure.new do
      component :dir, NFSFh                   # directory handle
      component :cookie, NFSCookie             # cookie
      component :count, UnsignedInteger.new # directory bytes to read
    end

    Entry = Structure.new do
      component :fileid, UnsignedInteger.new
      component :name, Filename
      component :cookie, NFSCookie
      component :nextentry, Optional.new(self)
    end

    DirList = Structure.new do
      component :entries, Optional.new(Entry)
      component :eof, Boolean.new
    end

    ReadDirRes = Union.new(NFSStat) do
      arm :NFS_OK do
        component :reply, DirList
      end
    end

    StatFsOkRes = Structure.new do
      component :tsize, UnsignedInteger.new  # preferred xfer size in bytes
      component :bsize, UnsignedInteger.new  # file system block size
      component :blocks, UnsignedInteger.new # total blocks in file system
      component :bfree, UnsignedInteger.new  # free blocks in fs
      component :bavail, UnsignedInteger.new # free blocks avail to non-root
    end

    StatFsRes = Union.new(NFSStat) do
      arm :NFS_OK do
        component :reply, StatFsOkRes
      end

      default do
      end
    end

    # Remote file service routines
    NFS_VERSION = 2

    NFS_PROGRAM = Program.new(100003) do
      version(NFS_VERSION) do
        procedure AttrStat, :GETATTR, 1, NFSFh
        procedure AttrStat, :SETATTR, 2, SAttrArgs
        procedure Void.new, :ROOT, 3, Void.new
        procedure DirOpRes, :LOOKUP, 4, DirOpArgs
        procedure ReadLinkRes, :READLINK, 5, NFSFh
        procedure ReadRes, :READ, 6, ReadArgs
        procedure Void.new, :WRITECACHE, 7, Void.new
        procedure AttrStat, :WRITE, 8, WriteArgs
        procedure DirOpRes, :CREATE, 9, CreateArgs
        procedure NFSStat, :REMOVE, 10, DirOpArgs
        procedure NFSStat, :RENAME, 11, RenameArgs
        procedure NFSStat, :LINK, 12, LinkArgs
        procedure NFSStat, :SYMLINK, 13, SymlinkArgs
        procedure DirOpRes, :MKDIR, 14, CreateArgs
        procedure NFSStat, :RMDIR, 15, DirOpArgs
        procedure ReadDirRes, :READDIR, 16, ReadDirArgs
        procedure StatFsRes, :STATFS, 17, NFSFh
      end
    end
  end
end
