requires 'perl', '5.14.0';

requires 'Moose', '2.00';
requires 'File::Find::Rule', '0.33';
requires 'namespace::sweep', '0.006';
requires 'Path::Tiny', '0.050';
requires 'MojoX::CustomTemplateFileParser', '0.09';

requires 'Dist::Zilla::File::InMemory', '5.000';
requires 'Dist::Zilla::Role::FileGatherer', '5.000';


on test => sub {
    requires 'Test::More', '0.96';
};
on build => sub {
	requires 'Test::EOL';
	requires 'Test::Pod';
};
