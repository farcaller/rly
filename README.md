[![Build Status](https://secure.travis-ci.org/farcaller/rly.png?branch=master)](http://travis-ci.org/farcaller/rly)

# Rly

Rly is a lexer and parser generator for ruby (O RLY?), based on ideas and solutions of
Python's [Ply](http://www.dabeaz.com/ply/) (in some places it's a total rip off actually).

## Installation

Install via rubygems

    gem install rly

## Usage

You need to create lexer and parser classes for each grammar you want to process.
It is commonly done by subclassing {Rly::Lex} and {Rly::Parse} classes (check the
appropriate docs).
