#!/usr/bin/env raku
use v6.d;

use ML::SparseMatrixRecommender;
use ML::SparseMatrixRecommender::Utilities;
use Data::Importers;
use Data::TypeSystem;

my Bool:D $long-form = False;
my Bool:D $sampling = False;
my $tag-types = <cap-Shape cap-Surface cap-Color bruises? odor gill-Attachment gill-Spacing gill-Size gill-Color edibility>;
#my $tag-types = Whatever;

my $tstart = now;
my $url = 'https://raw.githubusercontent.com/antononcube/MathematicaVsR/refs/heads/master/Data/MathematicaVsR-Data-Mushroom.csv';
my @dsData = data-import($url, headers => 'auto');
my $tend = now;
say "ingestion time: {$tend - $tstart}";

if $long-form {
    say "convert to long form";
    @dsData =
            @dsData
                    .head.keys.grep(* ne 'id')
                    .map( -> $tag-type { @dsData.map({ %( Item => $_<id>, TagType => $tag-type, Tag => $_{$tag-type}, Value => 1) }) })
            .flat(1);

    say "Sample:";
    .say for @dsData.head(4);
}

if $sampling {
    say "length before sampling: { @dsData.elems }";
    @dsData = @dsData.head(floor(0.5 * @dsData.elems));
    say "length after sampling : { @dsData.elems }";
}

#----------------------------------------------------------------------------------------------------
say '-' x 100;

# Convert to wide form
if $long-form {
    my $tstart = now;
    my @dsDataWide = ML::SparseMatrixRecommender::Utilities::convert-to-wide-form(@dsData);
    say deduce-type(@dsDataWide);
    .say for @dsDataWide.head(10);
    my $tend = now;
    say "convert to wide form time: {$tend - $tstart}";
}

#----------------------------------------------------------------------------------------------------
say '-' x 100;

$tstart = now;
my $smrObj;
if $long-form {
    say "Using long form creation";
    $smrObj =
            ML::SparseMatrixRecommender.new(:native)
            .create-from-long-form(@dsData,
                    item-column-name => "Item",
                    tag-type => 'Tag',
                    tag-column-name => 'Value',
                    weight-column-name => Whatever,
                    :!add-tag-types-to-column-names);
} else {
    say "Using wide form creation";
    $smrObj =
            ML::SparseMatrixRecommender.new(:native)
            .create-from-wide-form(@dsData,
                    item-column-name => "id",
                    :$tag-types,
                    :add-tag-types-to-column-names,
                    tag-value-separator => ":");
}

$tend = now;
say "creation time: {$tend - $tstart}";

#----------------------------------------------------------------------------------------------------
say '-' x 100;
$tstart = now;

$smrObj.apply-term-weight-functions("IDF", "None", "Cosine", native => Whatever);

$tend = now;
say "application of term-weight functions time: {$tend - $tstart}";
