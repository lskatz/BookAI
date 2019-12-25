#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/basename/;
use Data::Dumper qw/Dumper/;
use Getopt::Long qw/GetOptions/;
use Lingua::EN::Grammarian qw/extract_cautions_from extract_errors_from/;

local $0 = basename $0;
exit main();

sub main{
  my $settings = {};
  GetOptions($settings,qw(help)) or die $!;
  usage() if($$settings{help});

  my $str = "";
  while(<STDIN>){
    $str.=$_;
  }
  close STDIN;

  my $validatedStr = validateText($str, $settings);

  print $validatedStr;

  return 0;
}

sub validateText{
  my($str, $settings) = @_;

  my @cautions = extract_cautions_from($str);
  my @errors   = extract_errors_from($str);
  # Sort in reverse order
  my @all = sort{ ${$b->from}{index} <=> ${ $a->from}{index}} (@cautions,@errors);

  # Find and replace with suggestions
  for my $problem(@all){
    #print Dumper [$problem->match,'',$problem->suggestions];next;
    my $suggestion = ($problem->suggestions)[1];
    my $match = $problem->match;
    my $from = ${$problem->from}{index};
    my $to   = ${$problem->to}{index};

    print "$match=>$suggestion - $from:$to\n";

    $str = substr($str,0,$from)
         . $suggestion
         . substr($str, $to + 1);
    #print Dumper [
    #  $problem->match,
    #  $problem->from,
    #  $problem->to,
    #  $problem->explanation,
    #  $problem->suggestions,
    #]
  }
  
  return $str;
}

sub usage{
  print "$0: remove text that does not validate
  Usage: $0 < in.txt > out.txt
";
  exit 0;
}

