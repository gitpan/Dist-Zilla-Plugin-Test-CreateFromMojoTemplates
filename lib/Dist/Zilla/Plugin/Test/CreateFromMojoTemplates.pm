package Dist::Zilla::Plugin::Test::CreateFromMojoTemplates;

use strict;
use 5.10.1;
our $VERSION = '0.04';

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
        my $filename = path($path)->basename(qr{\.[^.]+});

        my $file = Dist::Zilla::File::InMemory->new(
            name => "t/$filename.t",
            content => $test_template . $contents,
        );
        $self->add_file($file);

    }

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=encoding utf-8

=head1 NAME

Dist::Zilla::Plugin::Test::CreateFromMojoTemplates - Create tests from custom L<Mojolicious> templates

=for html <p><a style="float: left;" href="https://travis-ci.org/Csson/p5-dist-zilla-plugin-test-createfrommojotemplate"><img src="https://travis-ci.org/Csson/p5-dist-zilla-plugin-test-createfrommojotemplate.svg?branch=master">&nbsp;</a>

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
