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
# \file    dependencies.pm
#
# \author  Tobias Foehst
#
# \date    2010-06-30
#
#----------------------------------------------------------------------
package FINROC::dependencies;

use strict;

use XML::Simple;
use File::Basename;
use Data::Dumper;

use FINROC::messages;

use FINROC::dependencies::cpp;
use FINROC::dependencies::java;

sub DependencyFromInclude($)
{
    my ($include) = @_;

    my @include = split "/", $include;

    return sprintf "rrlib_%s", $include[1] if $include[0] eq "rrlib";
    return sprintf "finroc_core" if $include[0] eq "core";
    return sprintf "finroc_%s_%s", $include[0], $include[1] if grep { $include[0] eq $_ } ( "plugins", "libraries", "projects" );
}

sub DependencyFromSimVis3DResourceFile($)
{
    my ($path) = @_;

    my @path = split "/", $path;

    return sprintf "rrlib_simvis3d_resources_abstract_objects" if $path[0] eq "abstract_objects";
    return sprintf "rrlib_simvis3d_resources_%s_%s", $path[0], $path[1] if grep { $path[0] eq $_ } ( "environments", "robots" );
    return sprintf "rrlib_simvis3d_resources_%s_%s_%s", $path[0], $path[1], $path[2] if scalar grep { $path[0] eq $_ } ( "decoration", "humans", "sensors" );
}

sub ResolveSourceFiles($$$)
{
    my ($directory, $source_file_patterns, $exclude_patterns) = @_;

    my @files;
    return @files unless defined $source_file_patterns;

    foreach my $include_pattern (split " ", $source_file_patterns)
    {
        if ($include_pattern =~ /\*\*/)
        {
            $include_pattern =~ s/\//\\\//g;
            $include_pattern =~ s/\./\\./g;
            $include_pattern =~ s/\*\*/.*/g;
            $include_pattern =~ s/([^\.])\*/$1\[^\/\]*/g;
            $include_pattern = qr/^$directory\/$include_pattern$/;
            foreach my $file (map { chomp; $_ } `find \"$directory\" -type f`)
            {
                push @files, $file if $file =~ $include_pattern;
            }
        }
        else
        {
            push @files, map { chomp; $_ } `ls \"$directory\"/$include_pattern`;
        }
    }

    return @files unless defined $exclude_patterns;

    my %excluded_files;
    foreach my $exclude_pattern (split " ", $exclude_patterns)
    {
        if ($exclude_pattern =~ /\*\*/)
        {
            $exclude_pattern =~ s/\//\\\//g;
            $exclude_pattern =~ s/\./\\./g;
            $exclude_pattern =~ s/\*\*/.*/g;
            $exclude_pattern =~ s/([^\.])\*/$1\[^\/\]*/g;
            $exclude_pattern = qr/^$directory\/$exclude_pattern$/;
            foreach my $file (map { chomp; $_ } `find \"$directory\" -type f`)
            {
                $excluded_files{$file} = 1 if $file =~ $exclude_pattern;
            }
        }
        else
        {
            map { chomp; $excluded_files{$_} = 1 } `ls \"$directory\"/$exclude_pattern`;
        }
    }

    return grep { !exists $excluded_files{$_} } @files;
}

sub ProcessSourceFiles($$$$)
{
    my ($language, $files, $mandatory, $optional) = @_;

    eval sprintf "FINROC::dependencies::%s::ProcessSourceFiles(\$files, \$mandatory, \$optional)", $language;
    ERRORMSG "$@\n" if $@;
}

sub ProcessTargets($$$$$)
{
    my ($targets, $directory, $language, $mandatory, $optional) = @_;

    foreach (@{$targets})
    {
        $$_{sources} = { content => $$_{sources} } unless ref $$_{sources};
        my @source_files = ResolveSourceFiles $directory, $$_{sources}{content}, $$_{sources}{exclude};

        my $mandatory_list = $mandatory;
        $mandatory_list = $optional if exists $$_{optional} and $$_{optional} eq "true";
        $mandatory_list = $optional if grep { /\/examples\// } @source_files;
        ProcessSourceFiles $language, [ @source_files ], $mandatory_list, $optional;
    }
}

sub ProcessFinrocFiles($$$)
{
    my ($files, $mandatory, $optional) = @_;

    foreach (@$files)
    {
        my $xml = eval { XMLin($_,
                               KeepRoot => 1,
                               ForceArray => [ 'parameter', 'element' ],
                               ContentKey => '-content',
                               GroupTags => { parameters => 'parameter' },
                               NormalizeSpace => 2) };

        if ($@)
        {
            WARNMSG sprintf "Skipping malformed xml file '%s'.\n", $_;
            next;
        }

        next unless exists $$xml{FinstructableGroup};

        my $dependencies = $mandatory;
        $dependencies = $optional if /\/examples\//;

        foreach my $dependency (grep { $_ } split /,| /, $$xml{FinstructableGroup}{dependencies})
        {
            while ($dependency)
            {
                push @$dependencies, $dependency;
                my $dependency_old = $dependency;
                $dependency =~ s/(finroc|rrlib)_[^_]+$//;
                last if $dependency eq $dependency_old;
            }
        }

        foreach my $element (keys %{$$xml{FinstructableGroup}{element}})
        {
            next unless defined $$xml{FinstructableGroup}{element}{$element}{parameters}{'XML file'};
            my $file = join "", map { $_ =~ s/^sources\/cpp\///; $_ } $$xml{FinstructableGroup}{element}{$element}{parameters}{'XML file'};
            my $dependency = DependencyFromInclude $file;
            push @$dependencies, $dependency if $dependency;
        }
    }
}

sub ProcessSimVis3DResourceFiles($$$)
{
    my ($files, $mandatory, $optional) = @_;

    foreach my $file (@$files)
    {
        my $descr = eval { XMLin($file,
                                 KeyAttr => [],
                                 ForceArray => [ "part", "element" ]) };

        if ($@)
        {
            WARNMSG sprintf "Skipping malformed xml file '%s'.\n", $_;
            next;
        }

        my $dependencies = $mandatory;
        $dependencies = $optional if $file =~ /\/examples\//;

        foreach (@{$$descr{part}})
        {
            push @$dependencies, DependencyFromSimVis3DResourceFile $$_{file};
        }
        foreach (@{$$descr{element}})
        {
            push @$dependencies, DependencyFromSimVis3DResourceFile $$_{collision_geom} if defined $$_{collision_geom};
        }
    }
}

sub DependenciesFromWorkingCopy($$)
{
    my ($working_copy, $repository) = @_;

    my ($repository_type, $repository_name) = $repository =~ /^([^_]+)_(.+)/;

    $repository_name = $repository_type = $repository unless defined $repository_type and defined $repository_name;

    DEBUGMSG sprintf "repository type and name: %s, %s\n", $repository_type, $repository_name;

    my $language = "cpp";
    $language = $1 if $repository_name =~ /-(.+)$/;

    DEBUGMSG sprintf "language: %s\n", $language;

    my (@mandatory, @optional);

    my @make_files = map { chomp; $_ } `find \"$working_copy\" -iname "make.xml"`;
    foreach (@make_files)
    {
        my $directory = dirname $_;

        my $make = eval { XMLin($_,
                                KeyAttr => [],
                                ForceArray => [ "program", "library", "rrlib", "unittest", "testprogram", "finroclibrary", "finrocplugin", "finrocprogram" ],
                                ForceContent => [ "sources" ],
                                NormalizeSpace => 2) };

        if ($@)
        {
            WARNMSG sprintf "Skipping malformed xml file '%s'.\n", $_;
            next;
        }

        ProcessTargets $$make{library}, $directory, $language, \@mandatory, \@optional;
        ProcessTargets $$make{program}, $directory, $language, \@mandatory, \@optional;

        ProcessTargets $$make{rrlib}, $directory, $language, \@mandatory, \@optional if $repository_type eq "rrlib";
        if ($repository_type eq "finroc")
        {
            ProcessTargets $$make{finroclibrary}, $directory, $language, \@mandatory, \@optional;
            ProcessTargets $$make{finrocplugin}, $directory, $language, \@mandatory, \@optional if $repository_name =~ /_?plugins_/;
            ProcessTargets $$make{finrocprogram}, $directory, $language, \@mandatory, \@optional if $repository_name =~ /^(projects|tools)_/;
        }

        ProcessTargets $$make{testprogram}, $directory, $language, \@optional, \@optional;
    }

    DEBUGMSG sprintf "collected mandatory dependencies: %s\n", join ", ", @mandatory;
    DEBUGMSG sprintf "collected optional dependencies: %s\n", join ", ", @optional;

    my @finroc_files = map { chomp; $_ } `find \"$working_copy\" -iname "*.finroc" -a ! -iname "license.finroc"`;
    ProcessFinrocFiles \@finroc_files, \@mandatory, \@optional;
    @finroc_files = map { chomp; $_ } `find \"$working_copy\" -iname "*.xml"`;
    ProcessFinrocFiles \@finroc_files, \@mandatory, \@optional;

    my @simvis3d_resource_files = map { chomp; $_ } `find \"$working_copy\" -iname "*.descr"`;
    ProcessSimVis3DResourceFiles \@simvis3d_resource_files, \@mandatory, \@optional;

    my %seen = ( $repository => 1 );
    @mandatory = grep { !$seen{$_}++ } @mandatory;
    @optional = grep { !$seen{$_}++ } @optional;

    # filter dependencies to other-world-repositories
    if ($repository_type eq "rrlib")
    {
        @mandatory = grep { $_ =~ /^rrlib_/ } @mandatory;
        @optional = grep { $_ =~ /^rrlib_/ } @optional;
    }
    if ($repository_type eq "finroc")
    {
        @mandatory = grep { $_ =~ /^(rrlib|finroc)_/ } @mandatory;
        @optional = grep { $_ =~ /^(rrlib|finroc)_/ } @optional;
    }

    return (join(" ", sort @mandatory), join(" ", sort @optional));
}

1;
