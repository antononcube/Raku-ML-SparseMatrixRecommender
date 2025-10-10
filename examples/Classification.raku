#!/usr/bin/env perl6

use ML::SparseMatrixRecommender;
use ML::SparseMatrixRecommender::Utilities;
use Data::Summarizers;

##===========================================================

# Using a dataset from "the web"
my @titanic = ML::SparseMatrixRecommender::Utilities::get-titanic-dataset;
@titanic .= map({ $_<passengerAge> = $_<passengerAge>.Int; $_ });

say "Dataset summary:";
records-summary(@titanic);

my @prof = "passengerClass:1st", "passengerSex:male", "passengerSurvival:survived";
my @hist = <87 101>;

my ML::SparseMatrixRecommender $smrObj .= new;

$smrObj =
        $smrObj
        .create-from-wide-form(@titanic, item-column-came => <id>, tag-types => Whatever)
        .apply-term-weight-functions('IDF', 'None', 'Cosine');

say (:$smrObj);

# Profile to classify with
my @prof2 = "passengerClass:1st", "passengerSex:male";

# Classification
$smrObj =
        $smrObj
        .classify-by-profile('passengerSurvival', @prof2, n-top-nearest-neighbors => 50, :normalize)
        .echo-value('classification result: ', with => &note);


