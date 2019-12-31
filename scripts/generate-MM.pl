#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/basename/;
use Data::Dumper qw/Dumper/;
use Getopt::Long qw/GetOptions/;
use Text::Fuzzy;

local $0 = basename $0;
sub logmsg{print STDERR "$0: @_\n";}
exit main();

sub main{
  my $settings = {};
  GetOptions($settings,qw(help boost=s filter! numsentences|num-sentences|sentences=i )) or die $!;
  usage() if($$settings{help});
  usage() if(!@ARGV);
  $$settings{numsentences} ||= 1;
  $$settings{filter}       //= 1;
  $$settings{boost}        ||= "";
  
  my($infile) = @ARGV;

  my $text = generateText($infile, $$settings{numsentences}, $settings);

  #die $text;

  # Cleanup
  $text =~ s/[“”]/"/g;       # Transform double quotes
  $text =~ s/[’]/'/g;        # Transform single quotes
  $text =~ s/"+\s*"+//g;     # Remove empty quotes
  $text =~ s/\s+([\.!\?,;])/$1/g;   # remove whitespace before punctuation
  $text =~ s/ ' s /'s /g;    # Remove space in between ' s

  print "$text\n";

  return 0;
}

sub generateText{
  my($modelFile, $numSentences, $settings) = @_;

  my $model = readDumper($modelFile, $settings);
  if($$settings{boost}){
    boostModel($model, $$settings{boost}, $settings);
  }

  my @word = sort keys(%{ $$model{start} });
  
  # Choose a start word
  my $startWord;
  my $rand = rand(1);
  my $cumulative = 0;
  for my $possibleStartWord (@word){
    $cumulative += $$model{start}{$possibleStartWord};
    #logmsg "$rand <? $cumulative - $possibleStartWord";
    if($rand < $cumulative){
      if($possibleStartWord !~ /^\w+$/){
        #print "Skipping - $possibleStartWord\n";
        next;
      }
      $startWord = $possibleStartWord;
      last;
    }
  }
  if(!$startWord){
    die "ERROR: no seed was found. The markov model might be corrupted.";
  }

  # This MM is punctuation-based. Generate one sentence
  # at a time.
  my $seed = $startWord;
  my $generatedText = $startWord;
  my $sentenceCounter = 0;
  for(my $i=0; $i<$numSentences; $i++){
    #logmsg "rep $i starts with $seed";
    my $sentence = generateSentence($seed, $model, $settings);

    if($$settings{filter}){
      # Check sentence for quality
      my $dictionOut = `echo '$sentence' | diction 2>&1`;
      my $exit_code = $? << 8;
      if($exit_code || $dictionOut =~ /\[/){
        #logmsg "Sentence seemed to have warnings. Trying another. <= $sentence";
        $numSentences++;
        next;
      }

      my @localWords = split(/\s+/, $sentence);
      if(@localWords > 20 || @localWords < 2){
        $numSentences++;
        next;
      }

      # Stop the script from short circuiting from too
      # many filtered sentences.
      if($numSentences > 10 * $$settings{numsentences}){
        warn "WARNING: too many invalid sentences. Quitting early.";
        return $generatedText;
      }
    }

    # Add the sentence to the growing body.
    $generatedText .= $sentence;
    # New seed is the punctuation with $
    $seed = substr($generatedText, -1, 1) . '$';
  }

  return $generatedText;
}

sub generateSentence{
  my($seed, $model, $settings) = @_;

  my $currentWord = $seed;
  my $generatedText = "";

  my $is_end_of_sentence = 0;
  EACH_WORD:
  while(! $is_end_of_sentence){
    my $rand = rand(1);
    my $cumulative = 0;
    die $generatedText if(!$currentWord);
    while(my($toWord, $freq) = each(%{ $$model{transition}{$currentWord} })){
      # Don't count properties as things with frequency.
      # Properties start with __ .
      next if($toWord =~ /^__/);

      #print "$rand - $cumulative - $possibleStartWord\n";

      $cumulative += $freq;
      if($rand < $cumulative){
        $currentWord = $toWord;
        if($currentWord =~ /\$$/){
          $currentWord = substr($currentWord, 0, -1);
          $generatedText .= $currentWord;
          $is_end_of_sentence = 1;
          last EACH_WORD;
        }

        $generatedText .= " $currentWord";
      }
    }

  }

  # First word uppercase
  $generatedText =~ s/^(\w)/uc($1)/e;

  return $generatedText;
}

# If --boost, then increase the frequency of that
# word in the model.
sub boostModel{
  my($model, $boost, $settings) = @_;
  my($boostedWord, $freqInc) = split(/,/, $boost);

  # Find the closest existing word for the boosted word
  if(!defined($$model{transition}{$boostedWord})){
    my $tf = Text::Fuzzy->new($boostedWord, trans=>1);
    my @nearest = $tf->nearestv([keys(%{ $$model{transition} })]);
    my $nearest = $nearest[0]; # band aid

    # TODO filter @nearest for something like 
    # If capitalized, then filter for capitalized
    
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
    $$model{transition}{$from}{$boostedWord} += $freqInc;
  }

  # Ensure that the boosted word can transition to something else
  for(@startWords){
    $$model{transition}{$boostedWord}{$_} += $freqInc;
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
  --no-filter              Do not remove and replace any sentence that
                           does not pass a simple grammar check.
";
  exit 0;
}

