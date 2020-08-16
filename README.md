## nfs-rb

An NFS v2 server implemented in pure Ruby.

Adapted from code written by Brian Ollenberger, available [here](https://github.com/bollenberger/nfs).

## What is NFS?

NFS, or "Network File System," is a protocol developed by Sun Microsystems in the 1980s that allows a filesystem to be accessed remotely over a network. MacOS, Windows, and Linux natively support mounting NFS volumes such that they appear alongside normal directories in the operating system's user interface.

## Running the Server

First, install the gem by running `gem install nfs-rb`, or add it to your Gemfile.

Start the server with the default options by running `nfs-rb`. The various options can be seen by running `nfs-rb --help`:

```
Usage: nfs-rb [options]
    -d, --dir [DIR]         The directory to serve. Defaults to the current directory.
        --host [HOST]       The host to bind to. Defaults to 127.0.0.1.
    -p, --port [PORT]       The port to bind to. Defaults to 2049.
    -u, --udp               Communicate using UDP (default is TCP).
    -v, --verbose           Enable verbose logging
    -h, --help              Prints this help message
```

The server can also be started and managed in your Ruby code:

```ruby
require 'nfs'

server = NFS::Server.new(
  dir: '.',
  host: '127.0.0.1',
  port: 2049,
  protocol: :tcp  # or :udp
)

# start server, return immediately
server.start

# start server, join to current thread
server.join

# shut server down
server.shutdown
```

## Mounting

Once the server is started, mount it using the following command.

```bash
mount -t nfs -o \
  rsize=8192,wsize=8192,timeo=1,nfsvers=2,proto=tcp,\
  retry=1,port=1234,mountport=1234,hard,intr,nolock \
  127.0.0.1:/ path/to/mount/location
```

You should then be able to navigate to /path/to/mount/location and see a listing of all the files available on the networked filesystem.

## Running Tests

Run `bundle exec rspec` to run the test suite.

## License

Licensed under the MIT license. See LICENSE for details.

## Authors

* Cameron C. Dutro: https://github.com/camertron
* Brian Ollenberger: https://github.com/bollenberger
