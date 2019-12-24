#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/basename dirname/;

my $dirname = dirname $0;
local $0 = basename $0;

my $infile = "$dirname/data/war-of-the-worlds.txt";
my $expectedFile = "$dirname/data/MM.dmp";
my $observedFile = "$dirname/data/MM.dmp.tmp";
system("perl ../scripts/train.pl $infile > $observedFile");
die if $?;

my $expected = eval{
  my $code = "";
  open(my $fh, '<', $expectedFile) or die "ERROR: could not read expected file $expectedFile: $!";
  while(<$fh>){
    $code.=<$fh>;
  }
  close $fh;
  return $code;
};

die $expected;
