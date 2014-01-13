# You received this file as part of Finroc
# A framework for intelligent robot control
#
# Copyright (C) Finroc GbR (finroc.org)
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
#----------------------------------------------------------------------
# \file    cpp.pm
#
# \author  Tobias Foehst
#
# \date    2010-06-30
#
#----------------------------------------------------------------------
package FINROC::dependencies::java;

use strict;

sub ProcessSourceFiles($$$)
{
    my ($files, $mandatory, $optional) = @_;

    my @files;
    foreach my $file (@$files)
    {
        next unless $file =~ /\.java$/;
        push @files, $file;
    }

    return unless @files;

    my $command = sprintf "cat %s", join " ", @files;

    my $multiline_comment_started = 0;
    my $multiline_comment_active = 0;
    my $depth = 0;
    my $first_optional_depth = undef;
    my $dependencies = $mandatory;
    foreach (map { chomp; $_ } `$command 2> /dev/null`)
    {
        # remove comments
        s/\/\/.*//;
        s/\/\*.*\*\///g;

        if ($multiline_comment_started)
        {
            $multiline_comment_started = 0;
            $multiline_comment_active = 1;
        }
        $multiline_comment_started = 1 if s/\/\*.*//;
        $multiline_comment_active = 0 if s/.*\*\///;

        $_ = "" if $multiline_comment_active;

        chomp;
        next if $_ eq "";

        next unless /^\s*import/;

        s/\./\//g;

        push @$dependencies, sprintf "%s-java", FINROC::dependencies::DependencyFromInclude($1) if /\s*import\s+org\/finroc\/(\S+)/;
        push @$dependencies, sprintf "%s-java", FINROC::dependencies::DependencyFromInclude($1) if /\s*import\s+org\/(rrlib\/\S+)/;
    }
}

1;
