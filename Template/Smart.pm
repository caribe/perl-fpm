use strict;
use File::Slurp;
use File::Basename;
use Digest::SHA1 qw(sha1_hex);

package Template::Smart {

	sub new {
		my $classname = shift;
		my $obj = {
			template_dir => '',
			compile_dir => '',
			@_,
			v => {},
		};
		return bless $obj, $classname;
	}

	sub assign {
		my $self = shift;

		if (ref $_[0] eq 'HASH') {
			while (my ($k, $v) = each %{$_[0]}) {
				$self->{v}{$k} = $v;
			}
		} else {
			$self->{v}{$_[0]} = $_[1];
		}
	}

	sub _varresolv {
		my ($v) = $_[0] =~ /^\$(\w+)/;
		my $path = $';
		my @p = ("\$var{'$v'}");
		while ($path) {
			if ($path =~ /^\.(\w+)/) {
				push @p, "\{'$1'\}";
			} elsif ($path =~ /^\[(\d+)\]/) {
				push @p, "[$1]";
			} else {
				die "Invalid var $_[0]";
			}
			$path = $';
		}

		return join '', @p;
	}

	sub _compile {
		my ($self, $template, $extends) = @_;

		my $re_var = qr/\$[a-zA-Z_]\w*(?:\.\w+|\[\d+\])*/;
		my $re_val = qr/(?:"(.*?)"|'(.*?)'|(\S)*)/; # 3 matching
		my $re_par = qr/(\w+)=$re_val/; # 4 matching

		my ($fn, $fp, $fs) = File::Basename::fileparse($self->{template_dir}.$template, '.tpl', '.tmpl');
		my $ff = $self->{compile_dir}.$fn.'.pl';

		my $tpl = File::Slurp::read_file($self->{template_dir}.$template).'{end}';

		# Strips all comments
		$tpl =~ s/\{\*.*?\*\}//gs;

		if ($tpl =~ /^\{extends\s+file=$re_val}/) {
			# Extends mode
			my $template = $1;

			$extends = { ff => $ff, blocks => {} } if not $extends;

			while ($tpl =~ /\{block\s+name=$re_val\}(.*?)\{\/block\}/gis) {
				my $bn = ($1 or $2 or $3);
				$extends->{blocks}{$bn} = $4 if not exists $extends->{blocks}{$bn};
			}

			$self->_compile($template, $extends);

		} else {

			$extends = { ff => $ff, blocks => {} } if not $extends;
			$tpl =~ s/\{block name=$re_val\}(.*?)\{\/block\}/$extends->{blocks}{$1 or $2 or $3} or $4/gise;

			# Rendering mode
			my @s = ('%var = %{$ARGV[0]};'."\n");
			while ($tpl =~ m#(.*?)\{(\/?\w+|$re_var)\s*(.*?)\}#gs) {
				my ($pre, $mark, $token) = ($1, $2, $3);
				if ($pre) {
					$pre =~ s/'/\\\'/gs;
					push @s, "print '$pre';\n";
				}

				if (substr($mark, 0, 1) eq '$') {
					push @s, 'print '._varresolv($mark).";\n";
				} elsif ($mark eq '/if') {
					push @s, "};\n";
				} elsif ($mark eq 'else') {
					push @s, "} else {\n";
				} elsif ($mark eq 'if') {
					$token =~ s/$re_var/_varresolv($&)/ge;
					push @s, "if ($token) {\n";
				} elsif ($mark eq 'elseif') {
					$token =~ s/$re_var/_varresolv($&)/ge;
					push @s, "} elsif ($token) {\n";
				} elsif ($mark eq 'foreach') {
					my ($v, $k) = $token =~ /($re_var)\s+as\s+(\$[a-zA-Z_]\w*)/;
					$v = _varresolv($v);
					$k = _varresolv($k);
					push @s, "foreach (\@{$v}) { $k = \$_; \n";
				} elsif ($mark eq '/foreach') {
					push @s, "};\n";
				} elsif ($mark eq 'include') {
					my %p;
					while ($token =~ /(\w+)=(?:"(.*?)"|'(.*?)'|\S*)/g) {
						$p{$1} = ($2 or $3 or $4);
					}
					my $file = $self->_compile($p{file});

					push @s, "do '$file';\n";
				}
			}

			local $" = undef;
			File::Slurp::write_file(($extends ? $extends->{ff} : $ff), "@s");

			return ($extends ? $extends->{ff} : $ff);
		}
	}

	sub fetch {
		my ($self, $template) = @_;

		my $file = $self->_compile($template);

		# Render

		my $out;
		do {
			local *STDOUT;
			open STDOUT, '>>', \$out;
			local @ARGV = ($self->{v});

			unless (my $ret = do $file) {
				warn "couldn't parse $file: $@" if $@;
				warn "couldn't do $file: $!"    unless defined $ret;
				warn "couldn't run $file"       unless $ret;
			}
		};

		return $out;
	}

	sub display {
		my $self = shift;
		print $self->fetch(@_);
	}
}

1;
