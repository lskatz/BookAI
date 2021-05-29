#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/basename/;
use Data::Dumper qw/Dumper/;
$Data::Dumper::Sortkeys = 1;
use Getopt::Long qw/GetOptions/;
use File::Temp qw/tempdir tempfile/;

use FindBin qw/$RealBin/;
use lib "$RealBin/../lib/perl5";

use Lingua::EN::Sentence qw/get_sentences add_acronyms/;
use Text::ParseWords qw/quotewords/;
use String::Markov;
use Lingua::EN::Tagger;

local $0 = basename $0;
sub logmsg{print STDERR "$0: @_\n";}
exit main();

sub main{
  my $settings = {};
  GetOptions($settings,qw(help order=i mincount|min-count=i chunk=i)) or die $!;
  usage() if($$settings{help} || !@ARGV);
  $$settings{mincount} ||= 1;
  $$settings{order}    ||= 1;
  $$settings{chunk}    ||= 1;
  
  my($infile) = @ARGV;

  # Do the first round of training but we will learn from
  # this first round and train again.
  my $emptyFilter = {};
  #logmsg "DEBUG";$$filter{'<wrb>Why</wrb>'}{'<ppc>,</ppc>'}=1;
  #logmsg "DEBUG";$$filter{'<wrb>why</wrb>'}{'<vbd>did</vbd>'}=1;
  my $initialTraining = train($infile, $emptyFilter, $settings);

  my $filter = lowFrequencyTransitions($initialTraining, $settings);
  my $training = train($infile, $filter, $settings);

  print Dumper $training;

  return 0;
}

sub lowFrequencyTransitions{
  my($markov, $settings) = @_;

  my $minCount = $$settings{mincount} || 1;

  my %lowFrequencyTransition;

  while(my($cur, $nxtCount) = each(%{ $$markov{transition_count} })){
    while(my($nxt, $count) = each(%$nxtCount)){
      if($count < $minCount){
        # if we have a low count, set bool true
        $lowFrequencyTransition{$cur}{$nxt} = $count;
      }
    }
  }

  return \%lowFrequencyTransition;
}

# $infile: the input file path
# $filter: a hash of word transitions. e.g., $filter = {from}{to}=>1
sub train{
  my($infile, $filter, $settings) = @_;

  my $wordsCounter = 0;
  my $order = $$settings{order} || 1;

  # MM variables
  my $markovChain = String::Markov->new(
    order     => $order,
    split_sep => qr/\s+/,
    join_sep  => ' ',
  );


  # Read the input file
  local $/ = undef;
  open(my $fh, '<', $infile) or die "ERROR reading file $infile: $!";
  my $text = <$fh>;
  close $fh;
  $text =~ s/\x94/ /g;   # remove weird whitespace characters
  $text =~ s/[“”]/"/g;   # Change windows quotes
  $text =~ s/[‘’]/'/g;   # Change windows quotes
  $text =~ s/["\(\)]//g; # Remove parentheses
  $text =~ s/_+//g;      # Remove italics

  ## split into sentences
  # Count sentences
  my $numSentences = 0;
  # Tag parts of speech
  my $partOfSpeechTagger = Lingua::EN::Tagger->new;
  # Add some contractions to the tagger
  #addSomeWordsToTheModel($partOfSpeechTagger);
  my @xmlSentence; # array of tagged sentences
  for my $sentence(@{ get_sentences($text) }){
    # Only keep sentences with actual letters
    next if($sentence =~ /^\W/);

    $numSentences++;

    # modify the sentence
    $sentence =~ s/^\s+|\s+$//g; # Left/right whitespace trim

    # Tag the parts of speech in the sentence
    my $xmlSentence    = $partOfSpeechTagger->add_tags($sentence);
    # Markov chain

    # If this sentence contains some filtered transition
    # then skip it.
    my $should_filter_sentence = 0; # mark if we should skip the sentence
    my @taggedWord = split(/\s+/, $xmlSentence);
    my $numWords = @taggedWord;
    for(my $i=0;$i<$numWords-1;$i++){
      my($from, $to) = ($taggedWord[$i], $taggedWord[$i+1]);
      if($$filter{$from}{$to}){
        $should_filter_sentence = 1;
      }
    }
    if($should_filter_sentence){
      next;
    }
    
    push(@xmlSentence, $xmlSentence);
  }

  # Add sentences to the Markov model
  while(@xmlSentence > 1){
    my @sample = splice(@xmlSentence, 0, $$settings{chunk});
    my $sample = join(" ", @sample);
    $markovChain->add_sample($sample);
  }

  return $markovChain;
}

sub usage{
  print "$0: train a hidden markov model with types of sentences
  Usage: $0 training-input.txt > model.dmp
  --order     1  The order of the Markov chain
  --chunk     1  How many sentences to feed the markov
                 model at once.
  --mincount  1  How often a transition has to occur before
                 filtering it out.
  ";
  exit 0;
}

