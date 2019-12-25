#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/basename/;
use Data::Dumper qw/Dumper/;
use Getopt::Long qw/GetOptions/;

local $0 = basename $0;
exit main();

sub main{
  my $settings = {};
  GetOptions($settings,qw(help numwords|num-words=i)) or die $!;
  usage() if($$settings{help});
  usage() if(!@ARGV);
  $$settings{numwords} ||= 50;
  
  my($infile) = @ARGV;

  my $text = generateText($infile, $$settings{numwords}, $settings);

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
  my($modelFile, $numWords, $settings) = @_;

  my $model = readDumper($modelFile, $settings);

  my @word = keys(%{ $$model{start} });
  
  # Choose a start word
  my $startWord;
  my $rand = rand(1);
  my $cumulative = 0;
  for my $possibleStartWord (@word){
    $cumulative += $$model{start}{$possibleStartWord};
    if($rand < $cumulative){
      if($possibleStartWord !~ /^\w+$/){
        print "Skipping - $possibleStartWord\n";
        next;
      }
      $startWord = $possibleStartWord;
      last;
    }
  }

  # Generate the rest of the sentence starting with the start word
  my $currentWord = $startWord;
  my $generatedText = $startWord;
  for(my $i=0; $i<$numWords; $i++){
    my $rand = rand(1);
    my $cumulative = 0;
    while(my($toWord, $freq) = each(%{ $$model{transition}{$currentWord} })){
      next if($toWord =~ /^__/);

      #print "$rand - $cumulative - $possibleStartWord\n";

      $cumulative += $freq;
      if($rand < $cumulative){
        $currentWord = $toWord;
        $generatedText .= " $toWord";
        last;
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
  --numwords  50
";
  exit 0;
}

