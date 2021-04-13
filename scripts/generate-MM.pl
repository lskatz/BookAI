#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/basename/;
use Data::Dumper qw/Dumper/;
use Getopt::Long qw/GetOptions/;
use FindBin qw/$RealBin/;

use lib "$RealBin/../lib/perl5";

use Text::Fuzzy;
use String::Markov;

local $0 = basename $0;
sub logmsg{print STDERR "$0: @_\n";}
exit main();

sub main{
  my $settings = {};
  GetOptions($settings,qw(help boost=s seed=i filter! numsentences|num-sentences|sentences=i )) or die $!;
  usage() if($$settings{help});
  usage() if(!@ARGV);
  $$settings{numsentences} ||= 1;
  $$settings{filter}       //= 1;
  $$settings{boost}        ||= "";

  # Set the seed with either a random number or the supplied number
  my $largeInt = 1e7;
  $$settings{seed} ||= int(rand($largeInt));
  srand($$settings{seed});
  
  my($infile) = @ARGV;

  my $text = generateText($infile, $$settings{numsentences}, $settings);
  $text=~s|<(\w+?)>([^<]+?)</\w+?>|$2|g; # Remove xml tags
  $text=~s/\s+('(s|re))/$1/g;            # fix contractions
  $text=~s/\s+([,;\.\!\?])/$1/g;         # fix punctuation

  print "$text\n";

  return 0;
}

sub generateText{
  my($modelFile, $numSentences, $settings) = @_;

  my $model = readDumper($modelFile, $settings);
  my $markov = $$model{markov};
  my $sentenceTransition = $$model{sentenceTransition};

  my $text = "";
  for(1..$numSentences){
    $text .= $markov->generate_sample()." ";
  }
  return $text;
}

# If --boost, then increase the frequency of that
# word in the model.
sub boostModel{
  my($model, $boost, $settings) = @_;
  my($boostedWord, $freqInc, $changeTo) = split(/,/, $boost);

  if($changeTo){
    ...;
  }

  # Find the closest existing word for the boosted word
  if(!defined($$model{transition}{$boostedWord})){
    my $tf = Text::Fuzzy->new($boostedWord, trans=>1);
    my @nearest = $tf->nearestv([
      keys(%{ $$model{transition} })
    ]);

    # sort @nearest for something like 
    # If capitalized, then sort for capitalized
    @nearest = sort {
      my $distA = $tf->distance($a);
      my $distB = $tf->distance($b);
      $distA <=> $distB ||
        $a cmp $b
    } @nearest;

    my $nearest = $nearest[0];
    
    logmsg "Could not find $boostedWord for boosting! Substituting $nearest for $boostedWord in the model.";
    logmsg "Distance is ".$tf->distance($nearest)."\n";

    # Change the label in the start/seed words
    $$model{start}{$boostedWord} = $$model{start}{$nearest};
    delete($$model{start}{$nearest});

    # Change the label in the transition FROM words
    $$model{transition}{$boostedWord} = $$model{transition}{$nearest};
    delete($$model{transition}{$nearest});

    # Change the label in the transition TO words
    for my $from(keys(%{ $$model{transition} })){
      if(defined($$model{transition}{$from}{$nearest})){
        $$model{transition}{$from}{$boostedWord} = $$model{transition}{$from}{$nearest};
        delete($$model{transition}{$from}{$nearest});
      }
    }
  }

  # Boost the start word
  $$model{start}{$boostedWord} += $freqInc;

  my @startWords = keys(%{ $$model{start} });
  
  # Boost the transition words
  for my $from(keys(%{ $$model{transition} })){
    if(defined($$model{transition}{$from}{$boostedWord})){
      $$model{transition}{$from}{$boostedWord} += $freqInc;
    }
  }

  # Ensure that the boosted word can transition to something else
  for(@startWords){
    if(defined($$model{transition}{$boostedWord}{$_})){
      $$model{transition}{$boostedWord}{$_} += $freqInc;
    }
  }

  return $model;
}

sub readDumper{
  my($file, $settings) = @_;

  local $/ = undef;

  open(my $fh, '<', $file) or die "ERROR: could not read file $file: $!";
  my $code = <$fh>;
  close $fh;

  no strict 'vars';
  my $var = eval $code;
  if($@){
    die "$@";
  }
  use strict 'vars';
  return $var;
}

sub usage{
  print "$0: generate text from a markov model
  Usage: $0 model.dmp > generated.txt
  --numsentences 1  
  --boost        Word,0.1  Raise the probability of a word appearing
                           by adding a frequency. For example, if
                           a word might appear 0.1 of the time and you
                           supply 0.1, then it will change to 0.2.
  --boost        Word,0.1,Word2
                           With this method of --boost, replace Word
                           with Word2.
  --no-filter              Do not remove and replace any sentence that
                           does not pass a simple grammar check.
  --seed                   Seed for randomness, to help guarantee
                           a deterministic result.
";
  exit 0;
}

