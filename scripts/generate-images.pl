#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/basename/;
use Data::Dumper qw/Dumper/;
use Getopt::Long qw/GetOptions/;
use Google::Search;

local $0 = basename $0;
sub logmsg{print STDERR "$0: @_\n";}
exit main();

sub main{
  my $settings = {};
  GetOptions($settings,qw(help)) or die $!;
  usage() if($$settings{help});
  usage() if(!@ARGV);
  
  my $images = search(\@ARGV, $settings);
  return 0;
}

sub search{
  my($search, $settings) = @_;

  my $gSearch = Google::Search->Image(query => $search);
  print Dumper $gSearch;
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
";
  exit 0;
}

