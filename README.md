# BookAI

[![Build Status](https://travis-ci.com/lskatz/BookAI.svg?branch=master)](https://travis-ci.com/lskatz/BookAI)

Create a sample of text using markov models

## Synopsis

Download a book and then train a model on it
    
    $ wget https://www.gutenberg.org/files/36/36-0.txt -O war-of-the-worlds.txt
    $ scripts/train.pl war-of-the-worlds.txt > wotw.MM.dmp
    $ scripts/generate.pl wotw.MM.dmp
    # See some sample text...

## Details

### Training

Train the model by downloading a book first and then running the script.

    # Start with the first two commands from the synopsis
    $ wget https://www.gutenberg.org/files/36/36-0.txt -O war-of-the-worlds.txt
    # Train but only accept word transitions if they happen at least twice.
    # Also use a Markov order of 3.
    $ scripts/train.pl war-of-the-worlds.txt --mincount 2 --order 3 > wotw.MM.dmp

This Markov model dmp file is in [`Data::Dump`](https://metacpan.org/pod/Data::Dump) format.
My convention is to use `.MM.dmp` to indicate a Markov model dump.
Essentially it shows a perl hash (or data dictionary for those of you coming from different languages).
The two keys in this hash are `markov` and `sentenceTransition`.

#### markov

`markov` is an actual [`String::Markov`](https://metacpan.org/pod/String::Markov) object.

Parts of speech are described in [`Lingua::EN::Tagger`](https://metacpan.org/source/ACOBURN/Lingua-EN-Tagger-0.31/README).

### Generating text from a training file

This command generates one sentence using frequencies found in the `markov` key in the `Data::Dump` file.
It also uses `--seed` to make a deterministic output.
Finally, it also uses `--numsentences 2` to make two sentences.

    $ perl scripts/generate-MM.pl wotw.MM.dmp --seed 42 --numsentences 2
    It was all over the boats pitched aimlessly. Close on towards the world; then I recalled the hole in my own. 



