#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw/basename dirname/;
use Data::Dumper qw/Dumper/;
use Getopt::Long qw/GetOptions/;
use JSON ();
use FindBin qw/$RealBin/;

local $0 = basename $0;
sub logmsg{print STDERR "$0: @_\n";}
exit main();

sub main{
  my $settings = {};
  GetOptions($settings,qw(help api_key|api-key|api=s)) or die $!;
  usage() if($$settings{help});
  usage() if(!@ARGV);
  
  my $apiKey = getApiKey($settings);
  my $images = search(\@ARGV, $apiKey, $settings);
  return 0;
}

# Get the API key from the command line flag or the file.
# If not supplied one way or the other, create a template
# config file for the api key.
sub getApiKey{
  my($settings) = @_;
  if($$settings{api_key}){
    return $$settings{api_key};
  }

  my $confFile = "$RealBin/../config/google.conf";
  if(! -e $confFile){
    mkdir dirname($confFile);
    open(my $confFh, ">", $confFile) or die "ERROR: could not make conf file $confFile: $!";
    print $confFh "api\tABC123\n";
    close $confFh;
    die "ERROR: conf file did not exist and so I made a blank template at $confFh! Add your API key there from Google.";
  }

  open(my $confFh, $confFile) or die "ERROR: could not read $confFile: $!";
  my $apiLine = <$confFh>;
  close $confFh;
  my(undef, $apiKey) = split(/\s+/, $apiLine);
  return $apiKey;
}

# Lots of help from
# https://developers.google.com/custom-search/v1/cse/list
sub search{
  my($searchArr, $apiKey, $settings) = @_;

  # Join the search terms to make the query
  my $query = join("%20", @$searchArr);

  # Start generating the REST API URL
  my $restUrl = "https://www.googleapis.com/customsearch/v1?key=$apiKey&q=$query";
  # Limit to JPG
  $restUrl   .= "&fileType=jpg";
  # Large images
  $restUrl   .= "&imgSize=large";
  # Public domain rights
  $restUrl   .= "&rights=cc_publicdomain";
  # Safe search on
  $restUrl   .= "&safe=active";
  # Image search
  $restUrl   .= "&searchType=image";

  # Limit the whole thing to 2048 characters
  if(length($restUrl) > 2048){
    die "ERROR: REST API limit is 2048 characters and this one is ".length($restUrl)."\n$restUrl\n";
  }

  my $json = `wget "$restUrl"`;
  print $json;
  die;
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

