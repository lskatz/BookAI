#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/basename/;
use Data::Dumper qw/Dumper/;
use Getopt::Long qw/GetOptions/;
use Lingua::EN::Sentence qw/get_sentences add_acronyms/;
use Text::ParseWords qw/quotewords/;
use Clone 'clone';
use String::Markov;

local $0 = basename $0;
sub logmsg{print STDERR "$0: @_\n";}
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
  my $markovChain = String::Markov->new(
    order     => 1,
    split_sep => qr/\s+/,
    join_sep  => ' ',
  );

  # Read the input file
  local $/ = undef;
  open(my $fh, '<', $infile) or die "ERROR reading file $infile: $!";
  my $text = <$fh>;
  close $fh;
  $text =~ s/\x94/ /g;
  $text =~ s/[“”]/"/g;   # Change windows quotes
  $text =~ s/[‘’]/'/g;   # Change windows quotes
  $text =~ s/["\(\)]//g; # Remove parentheses
  $text =~ s/_+//g;      # Remove italics

  # split into sentences
  for my $sentence(@{ get_sentences($text) }){
    next if($sentence =~ /^\W/);
    $sentence =~ s/^\s+|\s+$//g; # whitespace trim

    $markovChain->add_sample($sentence);
  }

  return $markovChain;

}

sub usage{
  print "$0: train a hidden markov model with types of sentences
  Usage: $0 training.tsv > model.dmp
  ";
  exit 0;
}

