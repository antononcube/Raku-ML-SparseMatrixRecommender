use v6.d;

use Statistics::Distributions::Utilities;

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

#==========================================================
# Categorize to intervals
#==========================================================
our sub categorize-to-intervals(
        @vec,
        :$breaks is copy = Whatever,
        :$probs is copy = Whatever,
        Bool :$interval-names = False) returns List {
    # Validate input vector
    die "The first argument is expected to be an array of numeric values."
    unless @vec.all ~~ Numeric:D;

    # Handle probabilities
    my @mprobs = do if $probs.isa(Whatever) {
        (^11) >>/>> 10;
    } elsif $probs ~~ (Array:D | List:D | Seq:D) && $probs.all ~~ Numeric:D {
        $probs.unique.sort
    } else {
        die 'The $probs argument is expected to be a list of probabilities or Whatever.'
    }

    # Determine breaks
    my @mbreaks = do if $breaks.isa(Whatever) {
        my @q = Statistics::Distributions::Utilities::quantile(@vec, @mprobs);
        @q.unique.sort;
    } elsif $breaks ~~ (Array:D | List:D | Seq:D) && $breaks.all ~~ Numeric:D {
        $breaks.grep(Numeric).unique.sort;
    } else {
        die 'The $breaks argument is expected to be a list numbers or Whatever.'
    }

    die "Need at least two distinct break points to define intervals"
    unless @mbreaks ≥ 2;

    # Categorize each value using binary search equivalent
    my @res = Statistics::Distributions::Utilities::find-interval(@vec, @mbreaks);

    # Interval names, if specified
    if $interval-names {
        my @names = @mbreaks.rotor(2 => -1).map({"{$_.head}≤v<{$_.tail}"});
        @names.push: "{@mbreaks.tail}≤v<∞";

        @res = @res.map: -> $i {
            $i < @names.elems ?? @names[$i] !! @names.tail
        }
    }

    return @res;
}