# Caribe::FPM - A simple FastCGI Manager script for Perl

## SYNOPSIS

  ```./perl-fpm.pl [--listen 0.0.0.0:9000] [--listen-queue 10] [--processes 1] [--connections 10000] [--startup /path/to/script.pl]```

## DESCRIPTION

This script launches a FastCGI pool that can be used
with all webservers that support it. So it is basically
just a FastCGI wrapper.

It differs from other wrappers because it does not
a generic wrapper and so it does not launch a new Perl instance
for every execution. Instead it takes advantage of
the Perl's do-file mechanism.

So it is placed between generic FastCGI wrapper and a
standalone FastCGI application, allowing at the same time
fast changes to scripts and easy deploy of applications.

## OPTIONS

There are some options to adapt the script to your needs.

```--listen 0.0.0.0:9000```

Specify on which IP and port to bind the FastCGI server socket. You
can also set a UNIX socket but permission must be managed elsewhere.

```--listen-queue 10```

The size of the socket listen queue.

```--processes 1```

Number of processes to prefork. The number is fixed, so you have to
base it on your hardware and your needs. Usually doubling the number
of CPU cores is a good choice.

```--connections 10000```

Live time of a single process expressed in served connections. This
is to avoid memory leaks by the child processes.

```--startup /path/to/script.pl```

Optional path to a startup script. This can be used to include some
common modules for the child processes, resulting in a bit faster
execution time.
