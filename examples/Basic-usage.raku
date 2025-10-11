#!/usr/bin/env perl6

use ML::SparseMatrixRecommender;
use Data::Summarizers;
use Data::Reshapers;

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
        .echo-value('recommendation by profile: ')
        .profile(@hist)
        .echo-value('history profile: ')
        .recommend(@hist, :!normalize, :!remove-history)
        .echo-value('recommendation by history: ');

my $recs = $smrObj.take-value;

say ('$recs : ', $recs.raku);

my @dsView = |$smrObj.join-across(@titanic, 'id').take-value;

say to-pretty-table(@dsView, field-names => <score id passengerClass passengerAge passengerSex passengerSurvival>);