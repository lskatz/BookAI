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
    $ scripts/train.pl war-of-the-worlds.txt > wotw.MM.dmp

This Markov model dmp file is in [`Data::Dump`](https://metacpan.org/pod/Data::Dump) format.
My convention is to use `.MM.dmp` to indicate a Markov model dump.
Essentially it shows a perl hash (or data dictionary for those of you coming from different languages).
The two keys in this hash are `markov` and `sentenceTransition`.

#### markov

`markov` is an actual [`String::Markov`](https://metacpan.org/pod/String::Markov) object.

#### sentenceTransition

This part of the `Data::Dump` is deprecated in favor of `String::Markov`.

Each key of `sentenceTransition` is a word that can transition to another word.
Each of these words is surrounded by an html-like tag describing its part of speech.
Therefore, the word `end` can come in multiple flavors including `<vb>end</vb>` which is a verb in an infinitive setting and `<nn>end</nn>` which is a noun.
The value of each "word" is another hash whose key is the target word and the value is the frequency at which it occurs.
Parts of speech are described in [`Lingua::EN::Tagger`](https://metacpan.org/source/ACOBURN/Lingua-EN-Tagger-0.31/README).

### Generating text from a training file

This command generates one sentence using frequencies found in the `markov` key in the `Data::Dump` file.
It also uses `--seed` to make a deterministic output.
Finally, it also uses `--numsentences 2` to make two sentences.

    $ perl scripts/generate-MM.pl wotw.MM.dmp --seed 42 --numsentences 2
    It was all over the boats pitched aimlessly. Close on towards the world; then I recalled the hole in my own. 



