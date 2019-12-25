# BookAI

Create a sample of text using markov models

## Synopsis

Download a book and then train a model on it
    
    wget https://www.gutenberg.org/files/36/36-0.txt -O war-of-the-worlds.txt
    scripts/train.pl war-of-the-worlds.txt > wotw.MM.dmp
    scripts/generate.pl wotw.MM.dmp
    # See some sample text...

