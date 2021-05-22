#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/basename/;
use Data::Dumper qw/Dumper/;
use Getopt::Long qw/GetOptions/;
#use Lingua::EN::Grammarian qw/extract_cautions_from extract_errors_from/;
use Text::Aspell;

local $0 = basename $0;
sub logmsg{print STDERR "$0: @_\n";}
exit main();

sub main{
  my $settings = {};
  GetOptions($settings,qw(verbose help)) or die $!;
  usage() if($$settings{help});

  # Read stdin
  my $str = "";
  while(<STDIN>){
    $str.=$_;
  }
  close STDIN;

  # Create our spell checker
  my $aspell = Text::Aspell->new;
  $aspell->set_option("lang", "en_US");
  $aspell->set_option("sug-mode", "fast");

  my $validatedStr = spellCheck($str, $settings);

  print $validatedStr;

  return 0;
}

sub validateTextWithGrammarian{
  my($str, $settings) = @_;

  #my @cautions = extract_cautions_from($str);
  my @cautions = ();
  my @errors   = extract_errors_from($str);
  # Sort in reverse order
  my @all = sort{ ${$b->from}{index} <=> ${ $a->from}{index}} (@cautions,@errors);

  # Find and replace with suggestions
  for my $problem(@all){
    my $suggestion = ($problem->suggestions)[0];
    my $match = $problem->match;
    my $from = ${$problem->from}{index};
    my $to   = ${$problem->to}{index};

    logmsg "$match=>$suggestion - $from:$to" if($$settings{verbose});

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
  --verbose
";
  exit 0;
}

