#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/basename dirname/;
use Data::Dumper qw/Dumper/;
use Getopt::Long qw/GetOptions/;
use FindBin qw/$RealBin/;
use List::Util qw/shuffle/;

use lib "$RealBin/../lib/perl5";

use JSON ();
use LWP::Simple qw/get/;
use MediaWiki::API;
use Image::Info qw/image_info dim/;

local $0 = basename $0;
sub logmsg{print STDERR "$0: @_\n";}
exit main();

sub main{
  my $settings = {};
  GetOptions($settings,qw(help)) or die $!;
  usage() if($$settings{help});
  usage() if(!@ARGV);

  my @query = @ARGV;
  my $queryString = join(" ", @query);

  my $mw = MediaWiki::API->new( {
    api_url => 'https://en.wikipedia.org/w/api.php',
    #action  => 'query',
  }  );

  my $res = [ "", [], [], [] ];
  while(length($res) > 1 && !@{ $$res[1] }){
    print "Query:\n  $queryString\n";
    $res = getFirstReasonableHits($mw, $queryString);

    # Remove a random word
    if(@query < 2){
      @query = @ARGV;
    }
    @query = shuffle(@query);
    shift(@query);
    $queryString = join(" ", @query);
  }
  if(!defined($res) || !$$res[0]){
    die "ERROR: no suitable hits";
  }

  my $numResults = @{ $$res[1] };

  # Put results into a hash that makes sense:
  # title => {url=>https://...}
  my %result;
  for(my $i=0;$i<$numResults;$i++){
    $result{$$res[1][$i]} = {url=>$$res[3][$i]};
  }

  # TODO shuffle results??

  my %imageDimensions;
  # Find the first page that has an image
  while(my($title, $info) = each(%result)){
    my $images = getImagesFromPage($mw, $$info{url});

    my @filteredImages;
    for my $image(@$images){
      next if($imageDimensions{$image});

      ## TODO test to see if it's a reasonable image
      my $image_data = get($image);
      my $image_info = image_info(\$image_data);
      my @dim = dim($image_info);

      print "@dim\n";
      if(@dim==2 && $dim[0] > 200 && $dim[1] > 200){
        $imageDimensions{$image} = \@dim;
      }
    }
    #$result{$title}{imageUrl} = \@filteredImages;
  }

  print Dumper \%imageDimensions;

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

  if(!defined($res)){
    $res = [ "", [], [], [] ];
  }
  
  return $res;
}

sub getImagesFromPage{
  my($mw, $url) = @_;

  my $content = get($url);

  #my $p = HTML::TagParser->new($content);
  #my @lowresImg = $p->getElementsByTagName('a

  my @possibleImg;
  while($content =~ /<a\s+.*?href="(.*?)"/g){

    # Get the image URL from the primary URL
    my $img = $1;
    my $imgPageUrl  = "https://en.wikipedia.org/$img";

    # Get the hires landing page for the image
    my $imgPageHtml = get($imgPageUrl);

    $|++;
    while($imgPageHtml =~ /<a\s+.*?href="(.*?)"/g){
      print ".";
      
      # Find the actual hi-resolution URL
      my $hires = $1;
      my $hiresUrl = $hires;
      $hiresUrl =~ s|^//|https://|;
      
      ## Test to see if it's a reasonable image
      my $image_data = get($hiresUrl);
      my $image_info = image_info(\$image_data);
      my @dim = dim($image_info);

      if(@dim < 1){
        next;
      }

      print "$hiresUrl => @dim\n";
    }
    print "\n";

  }

  # TODO randomize?
  return \@possibleImg;
}

sub usage{
  print "$0: generate text from a markov model
  Usage: $0 words in a sentence > out.jpg

  where 'words in a sentence' is an unquoted set of words
  used as a search term for Wikipedia
";
  exit 0;
}

