#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/basename/;
use Data::Dumper qw/Dumper/;
use Getopt::Long qw/GetOptions/;
use Lingua::EN::Sentence qw/get_sentences add_acronyms/;
use Text::ParseWords qw/quotewords/;

local $0 = basename $0;
exit main();

sub main{
  my $settings = {};
  GetOptions($settings,qw(help)) or die $!;
  usage() if($$settings{help});
  
  my($infile) = @ARGV;

  my $training = train($infile, $settings);

  print Dumper $training;

  return 0;
}

sub train{
  my($infile, $settings) = @_;

  my $wordsCounter = 0;

  # MM variables
  my(%transition, %start, $previousWord, %wordCount, $startWordsCounter);

  # split the infile into 'words'
  local $/ = undef;
  open(my $fh, '<', $infile) or die "ERROR reading file $infile: $!";
  my $text = <$fh>;
  close $fh;

  for my $sentence(@{ get_sentences($text) }){
    $sentence =~ s/^\s+|\s+$//g;

    # Identify the ending punctuation of the sentence
    my $endingPunctuation;
    if($sentence =~ /([\.;\?!]+)$/){
      $endingPunctuation = $1;
      # Remove the end punctuation for later
      $sentence = substr($sentence,0, -1 * length($endingPunctuation));
    }
    # Only accept sentences with punctuation
    if(!defined($endingPunctuation)){
      next;
    }

    # Split into words.
    # 'Words' can also be punctuation.
    # Whitespace information is removed.
    my @word = quotewords('\s+', 0, $sentence);
       @word = grep {/\S/ } 
               map{
                 s/\x94/ /g;            # Remove <94>
                 s/[“”]//g;             # Change windows quotes
                 s/[‘’]//g;             # Change windows quotes
                 s/,//g;                # remove commas
                 s/^\s+|\s+$//g;        # trim whitespace
                 s/^_([a-zA-Z]+)_$/$1/; # remove italics
                 $_;
               } 
               @word;
               #split(/\b/, $sentence);

    # Don't accept sentences that start with a non-word char.
    # Don't accept small sentences.
    next if($word[0] =~ /^\W/);
    next if(@word < 2);
    
    #print join(" ", @word)."\n";

    # Record the first word as a possible seed to the MM
    $start{$word[0]}++;
    $startWordsCounter++;

    # Record the words in the markov model
    for my $word(@word){
      next if($word =~ /^$/);

      $wordsCounter++;
      $wordCount{$word}++;

      if(defined($previousWord)){
        $transition{$previousWord}{$word}++;
        $transition{$previousWord}{__count}++;
      }
      $previousWord = $word;
    }

    # End of sentence: next word is the punctuation.
    # The punctuation will be notated with a $ like in suffix trees
    my $word = $endingPunctuation.'$';
    $transition{$previousWord}{$word}++;
    $transition{$previousWord}{__count}++;
    $previousWord = $word;
  }

  # Normalize start probabilities into frequencies
  while(my($key,$value) = each(%start)){
    $start{$key} = $value/$startWordsCounter;
  }

  my @word = keys(%wordCount);
  my $numDiffWords = scalar(@word);
  
  for(my $i=0; $i<$numDiffWords; $i++){
    my $from = $word[$i];

    # Change count to frequency
    my %freq;
    while(my($to, $count) = each(%{ $transition{$from} })){
      if($to =~ /^__/){
        $freq{$to} = $count;
      } else {
        $freq{$to} = $count / $transition{$from}{__count};
      }
    }
    $transition{$from} = \%freq;
  }
      
  return {
    transition => \%transition,
    start      => \%start,
  };
}

sub usage{
  print "$0: train a hidden markov model with types of sentences
  Usage: $0 training.tsv > model.dmp
  ";
  exit 0;
}

