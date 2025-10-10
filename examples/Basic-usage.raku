#!/usr/bin/env perl6

#use lib <. lib>;
use ML::SparseMatrixRecommender;

use Data::Reshapers;
use Data::Summarizers;
use Data::Importers;
use Math::SparseMatrix :ALL;
use Math::SparseMatrix::Utilities;

##===========================================================
#my Hash @titanic = Data::Reshapers::get-titanic-dataset(headers => 'auto');
#@titanic .= map({ $_<passengerAge> = $_<passengerAge>.Int; $_ });

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

say '=' x 100;
say 'Classify';
say '-' x 100;

my @prof2 = "passengerClass:1st", "passengerSex:male";
$smrObj = $smrObj.classify-by-profile('passengerSurvival', @prof2, n-top-nearest-neighbors => 300).echo-value;


