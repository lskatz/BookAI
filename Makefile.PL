use strict;
use warnings;
 
use 5.010;
 
use ExtUtils::MakeMaker;

WriteMakefile1(
  NAME         => 'BookAI',
  VERSION_FROM => 'lib/BookAI.pm',
  #ABSTRACT_FROM => 'lib/Mashtree.pm',
  #ABSTRACT_FROM => 'README.md',
  AUTHOR => q{Lee S. Katz <lskatz@gmail.com>},
  EXE_FILES    => [
    'scripts/generate-MM.pl',
    'scripts/train-MM.pl',
  ],
  BEFORE_BUILD=> {
    #exec => $preBuild,
  },
  PREREQ_PM    => {
    # Core modules
    'File::Basename' => 0,
    'Data::Dumper'   => 0,
    'Getopt::Long'   => 0,
    'Exporter'       => 0,

    # noncore
    'Lingua::EN::Tagger'   => 0,
    'Text::Fuzzy'          => 0,
    'Text::ParseWords'     => 0,
    'String::Markov'       => 0,
    'Lingua::EN::Sentence' => 0,
    'Image::Info'          => 0,
    'JSON'                 => 0,
    'MediaWiki::API'       => 0,
  },
  BUILD_REQUIRES => {
    'Test::More'     => 0.47,
  },
  MIN_PERL_VERSION => '5.10.0',
  LICENSE          => "gpl_3",
  dist=>{
    COMPRESS => "gzip -9f",
    SUFFIX   => "gz",
    #PREOP    => $preop,
  },
  META_MERGE => {
    'meta-spec' => { version => 2 },
    resources => {
      repository => {
        type => 'git',
        url => 'git://github.com/lskatz/bookai.git',
        web => 'https://github.com/lskatz/bookai',
      },
    },
  },
);

sub WriteMakefile1 {  #Compatibility code for old versions of EU::MM. Written by Alexandr Ciornii, version 2. Added by eumm-upgrade.
  my %params=@_;
  my $eumm_version=$ExtUtils::MakeMaker::VERSION;
  $eumm_version=eval $eumm_version;
  die "EXTRA_META is deprecated" if exists $params{EXTRA_META};
  die "License not specified" if not exists $params{LICENSE};
  if ($params{AUTHOR} and ref($params{AUTHOR}) eq 'ARRAY' and $eumm_version < 6.5705) {
    $params{META_ADD}->{author}=$params{AUTHOR};
    $params{AUTHOR}=join(', ',@{$params{AUTHOR}});
  }
  if ($params{TEST_REQUIRES} and $eumm_version < 6.64) {
    $params{BUILD_REQUIRES}={ %{$params{BUILD_REQUIRES} || {}} , %{$params{TEST_REQUIRES}} };
    delete $params{TEST_REQUIRES};
  }
  if ($params{BUILD_REQUIRES} and $eumm_version < 6.5503) {
    #EUMM 6.5502 has problems with BUILD_REQUIRES
    $params{PREREQ_PM}={ %{$params{PREREQ_PM} || {}} , %{$params{BUILD_REQUIRES}} };
    delete $params{BUILD_REQUIRES};
  }
  delete $params{CONFIGURE_REQUIRES} if $eumm_version < 6.52;
  delete $params{MIN_PERL_VERSION} if $eumm_version < 6.48;
  delete $params{META_MERGE} if $eumm_version < 6.46;
  delete $params{META_ADD} if $eumm_version < 6.46;
  delete $params{LICENSE} if $eumm_version < 6.31;

  # LK
  if(defined($params{BEFORE_BUILD})){
    if(defined($params{BEFORE_BUILD}{exec})){
      system($params{BEFORE_BUILD}{exec});
      die if $?;
    }
    delete($params{BEFORE_BUILD});
  }

  WriteMakefile(%params);
}
