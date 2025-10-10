#!/usr/bin/env perl6

use ML::SparseMatrixRecommender;
use Data::Importers;
use Data::Summarizers;

##===========================================================

# Using a dataset from "the web"
my @titanic = data-import("https://raw.githubusercontent.com/antononcube/MathematicaVsR/refs/heads/master/Data/MathematicaVsR-Data-Titanic.csv", headers => 'auto');
@titanic .= map({ $_<passengerAge> = $_<passengerAge>.Int; $_ });

.say for @titanic.roll(4);

records-summary(@titanic);

say @titanic[0].keys.grep({ $_ ne 'id' });

my @prof = "passengerClass:1st", "passengerSex:male", "passengerSurvival:survived";
my @hist = <87 101>;

my ML::SparseMatrixRecommender $smrObj .= new;

$smrObj =
        $smrObj
        .create-from-wide-form(
                @titanic,
                tag-types => @titanic[0].keys.grep({ $_ ne 'id' }).Array,
                item-column-came => <id>)
        .apply-term-weight-functions('IDF', 'None', 'Cosine');

my @prof2 = "passengerClass:1st", "passengerSex:male";
$smrObj =
        $smrObj
        .classify-by-profile('passengerSurvival', @prof2, n-top-nearest-neighbors => 100)
        .echo-value('classification result: ', with => &note);


