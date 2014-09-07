package Dist::Zilla::Plugin::Test::CreateFromMojoTemplates;

use strict;
use 5.10.1;
our $VERSION = '0.01';

use Moose;
use File::Find::Rule;
use namespace::sweep;
use Path::Tiny;
use MojoX::CustomTemplateFileParser;

use Dist::Zilla::File::InMemory;
with 'Dist::Zilla::Role::FileGatherer';

has directory => (
    is => 'ro',
    isa => 'Str',
    default => sub { 'examples/source/' },
);
has filepattern => (
    is => 'ro',
    isa => 'Str',
    default => sub { '^\w+-\d+\.mojo$' },
);


sub gather_files {
    my $self = shift;
    my $arg = shift;

    my $test_template_path = (File::Find::Rule->file->name('template.test')->in($self->directory))[0];
    my $test_template = path($test_template_path)->slurp;

    my @paths = File::Find::Rule->file->name(qr/@{[ $self->filepattern ]}/)->in($self->directory);
    foreach my $path (@paths) {

        my $contents = MojoX::CustomTemplateFileParser->new(path => path($path)->absolute)->parse->flatten;

        $path =~ s{\.mojo$}{.t};
        $path =~ s{.*/([^/]*$)}{t/$1};

        my $file = Dist::Zilla::File::InMemory->new(
            name => $path,
            content => $test_template . $contents,
        );
        $self->add_file($file);

    }

    return;
}

sub prepare {
    my $path = shift;
    my @lines = split /\n/ => path($path)->slurp;

    (my $filename = $path) =~ s{.*/([^/]*$)}{$1};      # remove path
    (my $baseurl = $filename) =~ s{^([^\.]+)\..*}{$1}; # remove suffix
    $baseurl =~ s{-}{_};

    my $info = parse_source($baseurl, @lines);

    my @parsed = join "\n" => @{ $info->{'head_lines'} };

    my $testcount = 0;
    foreach my $test (@{ $info->{'tests'} }) {
        ++$testcount;
        my $expected_var = sprintf '$expected_%s' => $testcount;
        push @parsed => sprintf 'my %s = qq{ %s };' => $expected_var, join "\n" => @{ $test->{'lines_expected'} };

        push @parsed => sprintf q{get '/%s' => '%s';} => $test->{'test_name'}, $test->{'test_name'};
        push @parsed => sprintf q{$test->get_ok('/%s')->status_is(200)->trimmed_content_is(%s, '%s');}
                                => $test->{'test_name'}, $expected_var, qq{Matched trimmed content in $filename, line $test->{'test_start_line'}};
    }

    push @parsed => 'done_testing();';
    push @parsed => '__DATA__';

    foreach my $test (@{ $info->{'tests'} }) {
        push @parsed => sprintf '@@ %s.html.ep' => $test->{'test_name'};
        push @parsed => join "\n" => @{ $test->{'lines_template'} };
    }

    return join "\n\n" => @parsed;

}

sub parse_source {
    my $baseurl = shift;
    my @lines = @_;

    my $test_start = qr/==TEST(?: EXAMPLE)?(?: (\d+))?==/i;
    my $template_separator = '--t--';
    my $expected_separator = '--e--';

    my $environment = 'head';

    my $info = {
        head_lines => [],
        tests      => []
    };
    my $test = {};

    my $row = 0;
    my $testcount = 0;

    LINE:
    foreach my $line (@lines) {
        ++$row;

        if($environment eq 'head') {
            if($line =~ $test_start) {
                $test = reset_test();
                $test->{'test_number'} = $1;
                ++$testcount;

                push @{ $info->{'head_lines'} } => '';
                $test->{'test_start_line'} = $row;
                $test->{'test_number'} = $testcount;
                $test->{'test_name'} = sprintf '%s_%s' => $baseurl, $testcount;
                $environment = 'beginning';

                next LINE;
            }
            push @{ $info->{'head_lines'} } => $line;
            next LINE;
        }
        if($environment eq 'beginning') {
            if($line eq $template_separator) {
                push @{ $test->{'lines_before'} } => '';
                $environment = 'template';
                next LINE;
            }
            push @{ $test->{'lines_before'} } => $line;
            next LINE;
        }
        if($environment eq 'template') {
            if($line eq $template_separator) {
                # No need to push empty line to the template
                $environment = 'between';
                next LINE;
            }
            push @{ $test->{'lines_template'} } => $line;
            next LINE;
        }
        if($environment eq 'between') {
            if($line eq $expected_separator) {
                push @{ $test->{'lines_between'} } => '';
                $environment = 'expected';
                next LINE;
            }
            push @{ $test->{'lines_expected'} } => $line;
            next LINE;
        }
        if($environment eq 'expected') {
            if($line eq $expected_separator) {
                # No need to push empty line to the template
                $environment = 'ending';
                next LINE;
            }
            push @{ $test->{'lines_expected'} } => $line;
            next LINE;
        }
        if($environment eq 'ending') {
            if($line =~ $test_start) {
                push @{ $test->{'lines_after'} } => '';
                push @{ $info->{'tests'} } => $test;
                $test = reset_test();
                ++$testcount;
                $test->{'test_start_line'} = $row;
                $test->{'test_number'} = $testcount;
                $test->{'test_name'} = sprintf '%s_%s' => $baseurl, $testcount;
                $environment = 'beginning';

                next LINE;
            }
            push @{ $test->{'lines_after'} } => $line;
            next LINE;
        }
    }
    push @{ $info->{'tests'} } => $test;

    return $info;
}

sub reset_test {
    return {
        lines_before => [],
        lines_template => [],
        lines_after => [],
        lines_between => [],
        lines_expected => [],
        test_number => undef,
        test_start_line => undef,
        test_name => undef,
    };
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=encoding utf-8

=head1 NAME

Dist::Zilla::Plugin::Test::CreateFromMojoTemplates - Create tests from custom L<Mojolicious> templates

=head1 SYNOPSIS

  ; In dist.ini
  [Test::CreateFromMojoTemplates]
  directory = examples/source
  filepattern = ^\w+-\d+\.mojo$

=head1 DESCRIPTION

Dist::Zilla::Plugin::Test::CreateFromMojoTemplates creates tests by parsing a custom file format
containg Mojolicious templates and the expected rendering. See L<MojoX::CustomTemplateFileParser> for details.

It looks for files in a given C<directory> (by default C<examples/source>) that matches C<filepattern> (by default C<^\w+-\d+\.mojo$>).

If you have many files you can also create a C<template.test> (currently hardcoded) file. Its content will be placed at the top of all created test files.

=head1 AUTHOR

Erik Carlsson E<lt>info@code301.comE<gt>

=head1 COPYRIGHT

Copyright 2014- Erik Carlsson

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
