#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/basename/;
use Data::Dumper qw/Dumper/;
use Getopt::Long qw/GetOptions/;

local $0 = basename $0;
sub logmsg{print STDERR "$0: @_\n";}
exit main();

sub main{
  my $settings = {};
  GetOptions($settings,qw(help numsentences|num-sentences|sentences=i )) or die $!;
  usage() if($$settings{help});
  usage() if(!@ARGV);
  $$settings{numsentences} ||= 1;
  
  my($infile) = @ARGV;

  my $text = generateText($infile, $$settings{numsentences}, $settings);

  #die $text;

  # Cleanup
  $text =~ s/^(\w)/uc($1)/e; # Start the sample with uppercase
  $text =~ s/[“”]/"/g;       # Transform double quotes
  $text =~ s/[’]/'/g;        # Transform single quotes
  $text =~ s/"+\s*"+//g;     # Remove empty quotes
  $text =~ s/\s+([\.!\?,;])/$1/g;   # remove whitespace before punctuation
  $text =~ s/ ' s /'s /g;

  print "$text\n";

  return 0;
}

sub generateText{
  my($modelFile, $numSentences, $settings) = @_;

  my $model = readDumper($modelFile, $settings);

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
    $generatedText .= $sentence;
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

  return $generatedText;
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
";
  exit 0;
}

