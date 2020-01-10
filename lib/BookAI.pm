#!/usr/bin/env perl
package BookAI;
use strict;
use warnings;
use Exporter qw(import);
use File::Basename qw/fileparse basename dirname/;
use Data::Dumper;

use lib dirname($INC{"BookAI.pm"});

our @EXPORT_OK = qw(
         );

local $0=basename $0;

######
# CONSTANTS

our $VERSION = "0.1";

