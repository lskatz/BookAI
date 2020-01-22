#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/basename dirname/;
use Data::Dumper qw/Dumper/;
use Getopt::Long qw/GetOptions/;
use JSON ();
use FindBin qw/$RealBin/;

use LWP::Simple qw/get/;
use MediaWiki::API;

local $0 = basename $0;
sub logmsg{print STDERR "$0: @_\n";}
exit main();

sub main{
  my $settings = {};
  GetOptions($settings,qw(help)) or die $!;
  usage() if($$settings{help});
  usage() if(!@ARGV);

  my $queryString = join(" ", @ARGV);

  my $mw = MediaWiki::API->new( {
    api_url => 'https://en.wikipedia.org/w/api.php',
    #action  => 'query',
  }  );

  my $res = [ "", [], [], [] ];
  while(length($res) > 1 && !@{ $$res[1] }){
    $res = getFirstReasonableHits($mw, $queryString);
    $queryString =~ s/\s+\S+$//; # remove last word
  }

  # TODO shuffle results??

  # Find the first page that has an image
  my $numResults = @{ $$res[1] };
  my $image = "";
  for(my $i=0; $i<$numResults; $i++){
    $image = getImageFromPage($mw, $$res[1][$i], $$res[3][$i]);

    ## TODO test to see if it's a reasonable image

    if($image){
      last;
    }
  }

  print "$image\n";

  return 0;
}

sub getFirstReasonableHits{
  my($mw, $queryString) = @_;
  # Find the first pages that matches the text
  my $query = {
    action => 'opensearch',
    namespace => '*',
    limit     => 10,
    redirects => 'resolve',
    search    => $queryString,
  };
  my $res = $mw->api($query);
  
  return $res;
}

sub getImageFromPage{
  my($mw, $title, $url) = @_;

  my $content = get($url);

  my @possibleImg;
  while($content =~ /<img.*?src="([^"]+)"/g){
    my $img= $1;
    if($img =~ m|^//|){
      $img = "https:$img";
    } else {
      $img =~ s|^/||;
      $img = "https://en.wikipedia.org/$img";
    }

    if($img =~ /upload.wikimedia.org/){
      return $img;
    }

    push(@possibleImg, $img);
  }

  # TODO randomize?
  return $possibleImg[0];
}

sub usage{
  print "$0: generate text from a markov model
  Usage: $0 words in a sentence > out.jpg

  where 'words in a sentence' is an unquoted set of words
  used as a search term for Wikipedia
";
  exit 0;
}

