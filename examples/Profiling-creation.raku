#!/usr/bin/env raku
use v6.d;

use ML::SparseMatrixRecommender;
use Data::Importers;

my Bool:D $long-form = False;
my Bool:D $sampling = False;
#my $tag-types = <cap-Shape cap-Surface cap-Color bruises? odor gill-Attachment gill-Spacing gill-Size gill-Color edibility>;
my $tag-types = Whatever;

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
    @dsData = @dsData.pick(floor(0.2 * @dsData.elems));
    say "length after sampling : { @dsData.elems }";
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
                    tag-column-name => 'Tag',
                    weight-column-name => 'Value',
                    :!add-tag-types-to-column-names);
    #.apply-term-weight-functions("IDF", "None", "Cosine");
} else {
    say "Using wide form creation";
    $smrObj =
            ML::SparseMatrixRecommender.new(:native)
            .create-from-wide-form(@dsData,
                    item-column-name => "id",
                    :tag-types,
                    :add-tag-types-to-column-names,
                    tag-value-separator => ":");
    #.apply-term-weight-functions("IDF", "None", "Cosine");
}

$tend = now;
say "creation time: {$tend - $tstart}";