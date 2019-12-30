#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/basename dirname/;
use Data::Dumper;
use Test::More tests=>2;

my $dirname = dirname $0;
local $0 = basename $0;
my $infile = "$dirname/data/pride-and-prejudice.txt";
my $expectedFile = "$dirname/data/MM.dmp";
my $observedFile = "$dirname/data/MM.dmp.tmp";

# Run the help menu and see what comes out
subtest "Running the help menu" => sub{
  plan tests=>2;
  my $helpmenu = `$dirname/../scripts/train-MM.pl --help`;
  my $exit_code = $? << 8;
  is($exit_code << 8, 0, "Exit code");
  ok(length($helpmenu) > 0, "Help menu exists");
};

subtest "Make the training file" => sub{
  plan tests=>2;
  # Make the training file
  system("perl $dirname/../scripts/train-MM.pl $infile > $observedFile");
  is($?, 0, "Error code for training with pride and prejudice");

  my $observed = readDumper($observedFile);
  my $expected = readDumper($expectedFile);

  is_deeply($observed, $expected, "Training file hash");
};

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

