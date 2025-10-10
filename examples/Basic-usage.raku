#!/usr/bin/env perl6

use ML::SparseMatrixRecommender;
use Data::Reshapers;
use Data::Summarizers;

##===========================================================
my @titanic = Data::Reshapers::get-titanic-dataset(headers => 'auto');
@titanic .= map({ $_<passengerAge> = $_<passengerAge>.Int; $_ });

# Using a dataset from "the web"
#use Data::Importers;
#my @titanic = data-import("https://raw.githubusercontent.com/antononcube/MathematicaVsR/refs/heads/master/Data/MathematicaVsR-Data-Titanic.csv", headers => 'auto');
#@titanic .= map({ $_<passengerAge> = $_<passengerAge>.Int; $_ });

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
        .apply-term-weight-functions('IDF', 'None', 'Cosine')
        .echo-M()
        .echo-matrices()
        .recommend-by-profile(@prof, 10, :!normalize)
        .echo-value()
        .profile(@hist)
        .echo-value()
        .recommend(@hist, :!normalize)
        .echo-value();

my $recs = $smrObj.take-value;

say ('$recs : ', $recs.raku);

my @dsRecs = $recs.map({ %(id => $_.key, score => $_.value) }).Array;
.say for @dsRecs;
my @dsView = join-across(@dsRecs, @titanic, <id>).sort({ -$_<score> });

say to-pretty-table(@dsView, field-names => <score id passengerClass passengerAge passengerSex passengerSurvival>);