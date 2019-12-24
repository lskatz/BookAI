#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/basename/;
use Data::Dumper qw/Dumper/;
use Getopt::Long qw/GetOptions/;
#use Algorithm::Viterbi;

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
  my(%transition, %start, $previousWord);

  # HMM variables
  #my(%transition, %emission, %start);
  #my $previousWord;
  #my $state;

  # split the infile into 'words'
  open(my $fh, '<', $infile) or die "ERROR reading file $infile: $!";
  while(<$fh>){
    chomp;

    # Split into words.
    # 'Words' can also be punctuation.
    # Whitespace information is removed.
    for my $word(split(/\b/)){
      $word =~ s/^\s+|\s+$//g; # whitespace trim
      next if($word =~ /^$/);
      $start{$word}++;
      $wordsCounter++;

      if(defined($previousWord)){
        $transition{$previousWord}{$word}++;
        $transition{$previousWord}{__count}++;
      }
      $previousWord = $word;
    }
  }
  close $fh;

  # Normalize start probabilities into frequencies
  while(my($key,$value) = each(%start)){
    $start{$key} = $value/$wordsCounter;
  }

  my @word = keys(%start);
  my $numDiffWords = scalar(@word);

  for(my $i=0; $i<$numDiffWords; $i++){
    my $from = $word[$i];

    # Count the number of 'to' words to calculate frequency
    my $numberOfToWords = 0;
    for(my $j=0; $j<$numDiffWords; $j++){
      my $to = $word[$j];
      next if(!defined($transition{$from}{$to}));
      $numberOfToWords += $transition{$from}{$to};
    }

    # Change count to frequency
    for(my $j=0; $j<$numDiffWords; $j++){
      my $to = $word[$j];
      next if(!defined($transition{$from}{$to}));
      $transition{$from}{$to} = $transition{$from}{$to} / $numberOfToWords;
    }
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

