# The XDR representation of the NFS mount protocol. Based on RFC 1094.

module NFS
  module Mount
    include SUNRPC

    MNTPATHLEN = 1024 # maximum bytes in a pathname argument
    MNTNAMLEN = 255   # maximum bytes in a name argument

    # The fhandle is the file handle that the server passes to the client.
    # All file operations are done using the file handles to refer to a file
    # or a directory. The file handle can contain whatever information the
    # server needs to distinguish an individual file.
    # -just use nfs_fh from the nfs protocol.

    # If a status of zero is returned, the call completed successfully, and
    # a file handle for the directory follows. A non-zero status indicates
    # some sort of error. The status corresponds with UNIX error numbers.
    FhStatus = Union.new(NFS::NFSStat) do
      arm :NFS_OK do
        component :fhs_fhandle, NFS::NFSFh
      end

      default do
      end
    end

    # The type dirpath is the pathname of a directory
    DirPath = DynamicString.new(MNTPATHLEN)

    # The type name is used for arbitrary names (hostnames, groupnames)
    Name = DynamicString.new(MNTNAMLEN)

    # A list of who has what mounted
    MountBody = Structure.new do
      component :ml_hostname, Name
      component :ml_directory, DirPath
      component :ml_next, Optional.new(self)
    end

    MountList = Optional.new(MountBody)

    # A list of netgroups
    GroupNode = Structure.new do
      component :gr_name, Name
      component :gr_next, Optional.new(self)
    end

    Groups = Optional.new(GroupNode)

    # A list of what is exported and to whom
    ExportNode = Structure.new do
      component :ex_dir, DirPath
      component :ex_groups, Groups
      component :ex_next, Optional.new(self)
    end

    Exports = Optional.new(ExportNode)

    MOUNTVERS = 1

    MOUNTPROG = Program.new(100005) do
      version(MOUNTVERS) do
        # If fhs_status is 0, then fhs_fhandle contains the
        # file handle for the directory. This file handle may
        # be used in the NFS protocol. This procedure also adds
        # a new entry to the mount list for this client mounting
        # the directory.
        # Unix authentication required.
        procedure FhStatus, :MNT, 1, DirPath

        # Returns the list of remotely mounted filesystems. The
        # mountlist contains one entry for each hostname and
        # directory pair.
        procedure MountList, :DUMP, 2, Void.new

        # Removes the mount list entry for the directory
        # Unix authentication required.
        procedure Void.new, :UMNT, 3, DirPath

        # Removes all of the mount list entries for this client
        # Unix authentication required.
        procedure Void.new, :UMNTALL, 4, Void.new

        # Returns a list of all the exported filesystems, and which
        # machines are allowed to import it.
        procedure Exports, :EXPORT, 5, Void.new

        # Identical to MOUNTPROC_EXPORT above
        procedure Exports, :EXPORTALL, 6, Void.new
      end
    end
  end
end
