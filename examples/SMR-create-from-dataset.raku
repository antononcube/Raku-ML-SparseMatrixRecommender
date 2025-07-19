#!/usr/bin/env perl6

use lib <. lib>;
use ML::SparseMatrixRecommender::Core;

use Data::Reshapers;

##===========================================================
my Hash @titanic = Data::Reshapers::get-titanic-dataset(headers => 'auto');

.say for @titanic.roll(4);

say @titanic[0].keys.grep({ $_ ne 'id' });

my ML::SparseMatrixRecommender::Core $smrObj .= new;

$smrObj.make-tag-inverse-indexes-from-wide-form( @titanic, tagTypes => @titanic[0].keys.grep({ $_ ne 'id' }).Array, itemColumnName => <id> );

say 'global-weights : ', $smrObj.global-weights('IDF'):!object;

say '$smrObj.take-tag-inverse-indexes().keys :', $smrObj.take-tag-inverse-indexes().keys;

say '$smrObj.take-tag-inverse-indexes() :', $smrObj.take-tag-inverse-indexes();

my $recs = $smrObj.recommend-by-profile( ["passengerClass:1st", "passengerSex:male"], 1000):!object;

say $recs;

say @titanic.grep({ $_<id> (elem) %($recs).keys });

say "-" x 60;