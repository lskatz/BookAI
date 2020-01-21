#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/basename dirname/;
use Data::Dumper qw/Dumper/;
use Getopt::Long qw/GetOptions/;
use JSON ();
use FindBin qw/$RealBin/;

use MediaWiki::API;

local $0 = basename $0;
sub logmsg{print STDERR "$0: @_\n";}
exit main();

sub main{
  my $settings = {};
  GetOptions($settings,qw(help api_key|api-key|api=s)) or die $!;
  usage() if($$settings{help});
  usage() if(!@ARGV);

  my $queryString = join(" ", @ARGV);

  my $mw = MediaWiki::API->new( {
    api_url => 'https://en.wikipedia.org/w/api.php',
    #action  => 'query',
  }  );

  # Find the first pages that matches the text
  my $query = {
    action => 'opensearch',
    namespace => '*',
    limit     => 10,
    redirects => 'resolve',
    search    => $queryString,
  };
  my $res = $mw->api($query);

  # TODO shuffle results??

  # Find the first page that has an image
  my $numResults = @{ $$res[1] };
  for(my $i=0; $i<$numResults; $i++){
    my $image = getImageFromPage($mw, $$res[1][$i], $$res[3][$i]);

    die Dumper $image;
  }

  return 0;
}

sub getImageFromPage{
  my($mw, $title, $url) = @_;

  my $content = `wget $url -O - 2>/dev/null`;

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
  used as a search term for Google Images

  --api_key      A google api key. See the following for details:
                 https://developers.google.com/custom-search/v1/using_rest
                 Can also edit the file conf/google.conf to
                 permanently add your key.
";
  exit 0;
}

