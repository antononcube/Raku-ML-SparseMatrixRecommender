use v6.d;

unit module ML::SparseMatrixRecommender::Utilities;

#| Get the Titanic dataset. Returns an array of hashmaps.
our sub get-titanic-dataset() {
    my $fileResource = %?RESOURCES<dfTitanic.csv>;

    my @lines = slurp($fileResource).subst('"', :g).lines;
    my @keys = @lines.head.split(',', :skip-empty).Array;
    my @tbl = do for @lines.tail(*-1).grep(*) -> $line {
        (@keys Z=> $line.split(',', :skip-empty).Array).Hash
    }
    return @tbl;
}
#= Ingests the resource file "dfTitanic.csv" of ML::SparseMatrixRecommender.

#| Convert a long form dataset into wide form dataset.
our sub convert-to-wide-form(
        @data where @data.all ~~ Map:D,                     #= A data frame with long form(at) data.
        :$item-column-name = "Item",                        #= Name of the column with the items.
        :$tag-type-column-name = "TagType",                 #= Name of the column with the tag types.
        :$tag-column-name = "Tag",                          #= Name of the column with the tags.
        :$weight-column-name = "Weight",                    #= Name of the column with the tag weights.
        Bool:D :$combine-tag-types-and-tags = False,        #= Should tag types be used as prefixes or not?
        Str:D :$tag-value-separator = ':',                  #= String to separate tag-type prefixes from tags.
        :$missing-value = 'NA',                             #= Missing value to use.
                             ) {
    my @dsDataWide;
    if $combine-tag-types-and-tags {
        @dsDataWide =
                @data
                .classify(*{$item-column-name}).kv
                .map(-> $i, @records { [
                    id => $i,
                    |@records.map({ Pair.new($_{$tag-type-column-name} ~ $tag-value-separator ~ $_{$tag-column-name}, $_{$weight-column-name} // 1) })
                ].Hash });
        my @tags-all = @dsDataWide>>.keys.flat.unique;
        my %empty-record = id => 'NA', |(@tags-all X=> 'NA');
        @dsDataWide .= map({ my %h = |%empty-record , |$_; %h  });
    } else {
        my @tag-types-all = @data.map(*{$tag-type-column-name}).unique;
        my %empty-record = id => 'NA', |(@tag-types-all X=> 'NA');
        @dsDataWide = @data.classify(*{$item-column-name}).kv.map(-> $i, @recs { [id => $i, |@recs.map({ $_{$tag-type-column-name} => $_{$tag-column-name} })].Hash });
        @dsDataWide .= map({ my %h = |%empty-record , |$_; %h  });
    }

    return @dsDataWide;
}
