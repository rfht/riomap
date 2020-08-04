#!/usr/bin/env perl

# Copyright (c) 2020 Thomas Frohwein
# 
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
# 
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

# TODO:
# /TODO
# remove unneeded commented out lines
# add search for filename without the extension, like with Dead Pixels using mainBackground for mainbackground.xnb

use strict;
use warnings;
package Riomap::Main;

use File::Basename;
use File::Find;
use File::Type;		# package p5-File-Type
use Pod::Usage;

my @files;
my @assemblies;
my @rest;

find(\&wanted, @ARGV);

sub wanted {
	push @files, $File::Find::name;
}

my $ft = File::Type->new();
foreach my $file (@files) {
	my $type = $ft->checktype_filename($file);
	if ($type eq 'application/x-ms-dos-executable') {
		push @assemblies, $file
			unless	$file =~ m/\/Mono\..*\.dll$/
			or	$file =~ m/\/System.*\.dll$/
			or	$file =~ m/\/mscorlib\.dll$/
			or	$file =~ m/\/dotNetFx40_Full_x86_x64\.exe$/
			;
	} elsif ($file ne '.'
		and $file ne '..'
		and $file !~ /^$ARGV[0]\/mono(\/|$)/	# TODO: currently only taking $ARGV[0] into account
		and $file !~ /^$ARGV[0]\/lib(\/|$)/	# TODO: currently only taking $ARGV[0] into account
		and $file !~ /^$ARGV[0]\/lib64(\/|$)/	# TODO: currently only taking $ARGV[0] into account
		) {
		push @rest, $file;
	}
}

# check each assembly in @assemblies for presence and spelling of filenames in @files
foreach my $assembly (@assemblies) {
	# https://perlmaven.com/reading-and-writing-binary-files
	my $cont = '';
	open(my $in, '<:raw', $assembly) or die "Can't open $assembly: $!";
	while (1) {
		my $success = read $in, $cont, 100, length($cont);
		die $! if not defined $success;
		last if not $success;
	}
	close $in or die "$in: $!";

	print "$assembly: " . length($cont) . "\n";
	foreach my $filename (@rest) {
		my $basename = basename($filename);
		next if $basename =~ /^\./;	# skip files starting with a dot
		my @name_parts = split(/\./, $basename, 2);
		my $pattern = $name_parts[0];
		next unless $pattern =~ /[[:alpha:]]/;	# skip rest if no letters in $pattern
		my $ext = '';
		if (scalar @name_parts > 1) {
			my $ext = $name_parts[1];
		}
		my @matches = $cont =~ m/[^[:alnum:]]$pattern[^[:alnum:]]/gi;
		chop(@matches);
		my @cleaned_matches = map substr($matches[$_], 1), 1..$#matches;
		print scalar @cleaned_matches . " matches for " . join('.', @name_parts) . " in " . $assembly . "\n";
		foreach my $match (@cleaned_matches) {
			my $matchext = join('.', $match, $ext);
			if ($matchext ne $basename) {
				my $matchpath = dirname($filename) . '/' . $matchext;
				unless (-e $matchpath) {
					system("ln -sf \"$basename\" \"$matchpath\"") == 0
						or die "system failed: $?";
				}
			}
		}
	}
}

exit;
