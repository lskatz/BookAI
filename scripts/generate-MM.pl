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
  GetOptions($settings,qw(help debug boost=s seed=i filter! numsentences|num-sentences|sentences=i )) or die $!;
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

  logmsg $text if($$settings{debug});

  # Fix spaces before contractions
  # To test, use suggested seeds on The Martian
  # posessive
  $text=~s/\s+(<pos>'s<\/pos>)/$1/gi;
  # negative contractions
  $text=~s/\s+(<rb>n't<\/rb>)/$1/gi;
  # will ('ll)
  $text=~s/\s+(<md>'ll<\/md>)/$1/gi;
  # am ('m)
  $text=~s/\s+(<vbp>'m<\/vbp>)/$1/gi;
  # is ('s) --seed 53
  $text=~s/\s+(<vbz>'s<\/vbz>)/$1/gi;
  #         --seed 70
  $text=~s/\s+(<nnp>'s<\/nnp>)/$1/gi;
  # are ('re)
  $text=~s/\s+(<vbp>'re<\/vbp>)/$1/gi;
  # have ('ve) --seed 54
  $text=~s/\s+(<vbp>'ve<\/vbp>)/$1/gi;
  # would ('d) --seed 50
  $text=~s/\s+(<md>'d<\/md>)/$1/gi;

  # numbers things
  # percentage --seed 50
  $text=~s/\s+(<nn>\%<\/nn>)/$1/g;
  # dollars: fix the space after 
  $text=~s/(<ppd>\$<\/ppd>)\s+//g;

  # Fix spaces before punctuation
  $text=~s/\s+(<pp>[\.\!\?]<\/pp>)/$1/g;
  $text=~s/\s+(<ppc>[,]<\/ppc>)/$1/g;
  $text=~s/\s+(<pps>[;\:]<\/pps>)/$1/g;
  $text=~s/\s+(<pps>\.{3,}<\/pps>)/$1/g;

  $text=~s|<(\w+?)>([^<]+?)</\w+?>|$2|g; # Remove xml tags

  print "$text\n";

  return 0;
}

sub generateText{
  my($modelFile, $numSentences, $settings) = @_;

  my $markov = readDumper($modelFile, $settings);

  # deprecated: sentenceTransition
  #my $sentenceTransition = $$model{sentenceTransition};

  my $text = "";
  for(1..$numSentences){
    # get the next sentence but since I messed with the
    # String::Markov object, avoid warnings.
    my $nextSentence = $markov->generate_sample();
    # Get at least two words in the sentence by checking for a space.
    my $numTries = 0;
    while($nextSentence !~ / / || $nextSentence !~ /<\/pp>$/){
      if(++$numTries > 999){
        die "ERROR: tried $numTries times to make a sentence but failed. Last sentence was $nextSentence";
      }

      $nextSentence = $markov->generate_sample();
    }
    $text .= $nextSentence ." ";
  }
  return $text;
}

# Add a function to remove a transition from the markov model
sub String::Markov::remove{
  my($markov, $cur, $nxt) = @_;

  # Actual deletion
  my $count = $$markov{transition_count}{$cur}{$nxt};
  delete($$markov{transition_count}{$cur}{$nxt});
  # Remove the base counter
  $$markov{row_sum}{$cur} -= $count;

  # If there are zero times we transition from this word,
  # remove it from the object
  if($$markov{row_sum}{$cur} < 1){
    #delete($$markov{row_sum}{$cur});
    #delete($$markov{transition_count}{$cur});
    $$markov{row_sum}{$cur}=1;
    $$markov{transition_count}{$cur} = {$markov->null => 1};
  }
  
  #logmsg "Removed $cur -> $nxt (count: $count)";

  # Cleanup
  # If there is a zero count transitioning to this word,
  # then remove it from the base_count
  for my $current(sort keys(%{ $$markov{transition_count} })){
    my @next = sort keys(%{ $$markov{transition_count}{$current} });
    #logmsg "$cur: $next[0] .. @next";
    #if($next[0] eq $markov->{null}){
    #  die "removing $cur/$nxt";
    #}

    # If we don't transition to anything, remove this FROM word.
    if(@next < 1){
      #delete($$markov{transition_count}{$current});
      $$markov{transition_count}{$current}{$markov->null}=1;
      next;
    }
  }

  return $markov;
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
  --debug                  print some messages to stderr
";
  exit 0;
}

