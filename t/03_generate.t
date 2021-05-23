#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/basename dirname/;
use Data::Dumper;
use Test::More tests=>3;

use FindBin qw/$RealBin/;
use lib "$RealBin/../lib/perl5";

use Lingua::EN::Sentence qw/get_sentences add_acronyms/;

my $dirname = dirname $0;
local $0 = basename $0;
my $MMFile = "$dirname/data/MM.dmp";

system("perl $dirname/../scripts/generate-MM.pl --help >/dev/null 2>&1");
my $exit_code = $? << 8;
is($exit_code, 0, "Help menu; exit code 0");

subtest "Generate some text" => sub{
  plan tests => 2;

  my $sentence = `perl $dirname/../scripts/generate-MM.pl --numsentences 1 $MMFile`;
  chomp($sentence);
  my $exit_code = $? << 8;
  is($exit_code, 0, "Exit code 0");
  my @word = split(/\s+/, $sentence);
  ok(scalar(@word) > 0, "Generated more than one word in a single sentence: $sentence");

};

subtest "Generate five sentences" => sub{
  plan tests => 2;

  my $numSentences = 5;
  my $minWords = $numSentences * 2;

  my $fiveSentences = `perl $dirname/../scripts/generate-MM.pl --seed 42 --numsentences $numSentences $MMFile`;
  chomp($fiveSentences);
  my $exit_code = $? << 8;
  is($exit_code, 0, "Exit code 0");

  diag "Five sentences:";
  diag $fiveSentences;

  # Test each of the five sentences
  subtest "At least two words per $numSentences sentences" => sub{
    plan tests => $numSentences;

    my $sentences = get_sentences($fiveSentences);
    for(my $i=0;$i<$numSentences;$i++){
      my $sentence = $$sentences[$i];
      my @word = split(/\s+/, $sentence);
      diag "Sentence $i: $sentence";
      ok(scalar(@word) >= 1, ">=1 word in sentence $i");
    }
  };
};

