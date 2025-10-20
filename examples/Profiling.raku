#!/usr/bin/env raku
use v6.d;

use ML::SparseMatrixRecommender;
use Data::Importers;

my $tstart = now;
my $url = 'https://raw.githubusercontent.com/antononcube/MathematicaVsR/refs/heads/master/Data/MathematicaVsR-Data-Mushroom.csv';
my @dsData = data-import($url, headers => 'auto');
my $tend = now;
say "ingestion time: {$tend - $tstart}";

#----------------------------------------------------------------------------------------------------
say '-' x 100;

$tstart = now;
my $smrObj =
        ML::SparseMatrixRecommender.new(:native)
                .create-from-wide-form(@dsData,
                item-column-name => "id",
                tag-types => ["cap-Shape", "cap-Surface", "cap-Color", "bruises?", "odor", "gill-Attachment", "gill-Spacing", "gill-Size", "gill-Color", "edibility"],
                :add-tag-types-to-column-names,
                tag-value-separator => ":");

#$smrObj.apply-term-weight-functions("IDF", "None", "Cosine");

$tend = now;
say "creation time: {$tend - $tstart}";

#----------------------------------------------------------------------------------------------------
say '-' x 100;

my %prof = "cap-Shape:convex" => 1.2, "cap-Color:gray" => 1, "edibility:poisonous" => 1.4;
my $n = 100;
my $top-k = 20;
my @res;
$tstart = now;
for ^$n {
    my $vec = $smrObj.to-profile-vector(%prof.Mix);
    my $rec = $smrObj.take-M.dot($vec);

    # Convert to named rules and take the largest
    #my @res = $rec.rules(:names).map({ $_.key.head => $_.value }).sort({ -$_.value });
    #my @res = $rec.rules(:names).sort({ -$_.value });

    # Same as above but using tuples
    #my @res = $rec.tuples.sort(-*.tail)
    #my @res = $rec.tuples;

    # Use the non-zero elements directly
    #my @inds = $rec.core-matrix.transpose.col-index;
    #my @vals = $rec.core-matrix.values;
    #my @recInds = @vals.sort(-*, :k).head($top-k);
    #@res = $rec.row-names[@inds[@recInds]] Z=> @vals[@recInds];

    # Derive a top-K matrix and get row-sums
    #@res = |$rec.top-k-elements-matrix($top-k, :!clone).row-sums(:pairs).sort({ -$_.value });

    # Derive a top-K matrix and get rules (FASTEST)
    @res = |$rec.top-k-elements-matrix($top-k, :!clone).rules(:names).map({ $_.key.head => $_.value }).sort({ -$_.value });
}
$tend = now;
say "recommendations by profile total time: {$tend - $tstart}, per dot-product: {($tend - $tstart)/$n}";
say @res;

# total time 0.777017299, per dot-product 0.007770172990000001

# my @res = $rec.tuples;
# total time 9.335552594, per dot-product 0.09335552593999999

# my @res = $rec.rules(:names).sort({ -$_.value });
# total time 10.208145226, per dot-product 0.10208145226

# my @vals = $rec.core-matrix.values.sort(-*).head(10);
# total time 3.593356987, per dot-product 0.03593356987

# my @inds = $rec.core-matrix.transpose.col-index;
# total time 1.483003293, per dot-product 0.014830032929999999

#----------------------------------------------------------------------------------------------------
say '-' x 100;

# Verification

my @resAll = $smrObj
        .recommend-by-profile(%prof, Inf, :!normalize)
        .take-value
        .Slip;

say (:@resAll);

say "number of records for this profile : {@resAll.grep(*.value ≥ 3.59999).elems == 436}";

say "verify : {(@resAll.grep(*.value ≥ 3.59999).elems, @res.grep(*.value ≥ 3.59999).elems)}";

#----------------------------------------------------------------------------------------------------
say '-' x 100;
#my @resAllByQuery = $smrObj
#        .retrieve-by-query-elements(must => %prof.keys)
#        .take-value
#        .Slip;
#
#say (:@resAllByQuery);
#
#say "verify by query: {(@resAllByQuery.elems, @res.grep(*.value ≥ 3.59999).elems)}";
