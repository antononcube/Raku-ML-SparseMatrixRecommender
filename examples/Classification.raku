#!/usr/bin/env perl6

use ML::SparseMatrixRecommender;
use ML::SparseMatrixRecommender::Utilities;
use Data::Summarizers;

# This file shows how to use a Sparse Matrix Recommender (SMR) as classifier,
# not a full-blown classification Machine Learning workflow.

my @titanic = ML::SparseMatrixRecommender::Utilities::get-titanic-dataset;
@titanic .= map({ $_<passengerAge> = $_<passengerAge>.Int; $_ });

say "Dataset summary:";
records-summary(@titanic);

# Make the recommender
my $smrObj =
        ML::SparseMatrixRecommender
        .new
        .create-from-wide-form(@titanic, item-column-came => <id>, tag-types => Whatever)
        .apply-term-weight-functions('IDF', 'None', 'Cosine');

say (:$smrObj);

# Profile to classify with
my @prof = "passengerClass:1st", "passengerSex:male";

# Classification
$smrObj =
        $smrObj
        .classify-by-profile('passengerSurvival', @prof, n-top-nearest-neighbors => 50, :normalize)
        .echo-value('classification result: ', with => &note);


