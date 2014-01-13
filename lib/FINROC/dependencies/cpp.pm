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
package FINROC::dependencies::cpp;

use strict;

sub ProcessSourceFiles($$$)
{
    my ($files, $mandatory, $optional) = @_;

    my @files;
    foreach my $file (@$files)
    {
        next unless $file =~ /\.(c|h|cpp|hpp)$/;
        $file =~ s/\.(c|h|cpp|hpp)$//;
        push @files, "$file.c" if -f "$file.c";
        push @files, "$file.h" if -f "$file.h";
        push @files, "$file.cpp" if -f "$file.cpp";
        push @files, "$file.hpp" if -f "$file.hpp";
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

        # detect and process #if-directives
        if (/^\s*#\s*if/)
        {
            $depth++;
            if (/_LIB_\S+_PRESENT_/)
            {
                $first_optional_depth = $depth unless defined $first_optional_depth;
                $dependencies = $optional;
            }
            next;
        }

        # detect and process #endif-directives
        if (/^\s*#\s*endif/)
        {
            $depth--;
            if (defined $first_optional_depth and $depth < $first_optional_depth)
            {
                $first_optional_depth = undef;
                $dependencies = $mandatory;
            }
            next;
        }

        push @$dependencies, FINROC::dependencies::DependencyFromInclude($1) if /^\s*#\s*include\s+"([^"]+)"/;
    }
}

1;
