#!/usr/bin/env perl

package Caribe::FPM;

our $VERSION = '0.1';

use strict;
use warnings;

use Getopt::Long;
use FCGI;
use FCGI::ProcManager;
use CGI qw/:cgi/;

my $socket_path = '0.0.0.0:9000';
my $listen_queue = 10;
my $processes = 1;
my $connections = 10000;
my $startup;

GetOptions(
	'listen=s' => \$socket_path,
	'listen-queue=i' => \$listen_queue,
	'processes=i' => \$processes,
	'connections=i' => \$connections,
	'startup=s' => \$startup,
);

my %connections;

my %env;

require $startup if $startup;

my $pm = FCGI::ProcManager->new({ n_processes => $processes });

my $socket = FCGI::OpenSocket($socket_path, $listen_queue);
my $request = FCGI::Request(\*STDIN, \*STDOUT, \*STDOUT, \%ENV, $socket);

$pm->pm_manage();

while ($request->Accept() >= 0) {
	$pm->pm_pre_dispatch();

	CGI->_reset_globals;
	my $q = CGI->new();

	local @ARGV = ($q, \%env);
	unless (my $return = do $ENV{DOCUMENT_ROOT}.$ENV{DOCUMENT_URI}) {
		if ($@) {
			print $q->header('text/plain ', '500 Internal Server Error');
			print "Script `$ENV{DOCUMENT_URI}` is broken.";
			warn "Script $ENV{DOCUMENT_URI} is broken.\n$@";
		} elsif (not defined $return) {
			print $q->header('text/plain ', '404 Not Found');
			print "Script `$ENV{DOCUMENT_URI}` not found.";
			warn "Script `$ENV{DOCUMENT_URI}` not found.\n$!"
		} else {
			print $q->header('text/plain ', '500 Internal Server Error');
			print "Script `$ENV{DOCUMENT_URI}` not run.";
			warn "Script `$ENV{DOCUMENT_URI}` not run."
		}
	}

	$pm->pm_post_dispatch();

	if (++$connections{$$} > $connections) {
		delete $connections{$$};
		exit;
	}
}

FCGI::CloseSocket($socket);


__END__

=pod

=head1 NAME

Caribe::FPM - A simple FastCGI Manager script for Perl

=head1 VERSION

Version 0.1

=head1 SYNOPSIS

  ./perl-fpm.pl [--listen 0.0.0.0:9000] [--listen-queue 10] [--processes 1] [--connections 10000] [--startup /path/to/script.pl]

=head1 DESCRIPTION

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

=head1 OPTIONS

There are some options to adapt the script to your needs.

=head2 C<--listen 0.0.0.0:9000>

Specify on which IP and port to bind the FastCGI server socket. You
can also set a UNIX socket but permission must be managed elsewhere.

=head2 C<--listen-queue 10>

The size of the socket listen queue.

=head2 C<--processes 1>

Number of processes to prefork. The number is fixed, so you have to
base it on your hardware and your needs. Usually doubling the number
of CPU cores is a good choice.

=head2 C<--connections 10000>

Live time of a single process expressed in served connections. This
is to avoid memory leaks by the child processes.

=head2 C<--startup /path/to/script.pl>

Optional path to a startup script. This can be used to include some
common modules for the child processes, resulting in a bit faster
execution time.

=head1 BUGS AND LIMITATIONS

Please report any bugs or feature
requests to C<https://github.com/caribe/perl-fpm>.

=head1 LICENSE AND COPYRIGHT

MIT License

Copyright (c) 2018 Vincenzo Buttazzo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

=cut
