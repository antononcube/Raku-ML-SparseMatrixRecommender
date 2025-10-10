use v6;

use Math::SparseMatrix;
use ML::SparseMatrixRecommender::DocumentTermWeightish;

## Monadic-like definition.
class ML::SparseMatrixRecommender
        does ML::SparseMatrixRecommender::DocumentTermWeightish {

    ##========================================================
    ## Data members
    ##========================================================
    has %!matrices = %();
    has $!M = Whatever;
    has %!tag-type-weights = %();
    has $!data = Whatever;
    has $!value = Whatever;

    ##========================================================
    ## Performance
    ##========================================================
    has %!items = %();
    has %!tags = %();

    method !file-in-items-and-tags() {
        %!items = $!M.row-names Z=> (^$!M.nrow);
        %!tags = $!M.column-names Z=> (^$!M.ncol);
    }

    method make-profile-vector(
            Mix:D $mix,
            Bool:D :$column = True,
            Str:D :$item-name = 'profile',
            Bool:D :$warn = False
                               ) {
        # Make sure the items and tags are current
        self!file-in-items-and-tags if %!items.elems == 0 || %!tags.elems == 0 || %!items.elems != $!M.nrow || %!tags.elems != $!M.ncol;

        # Make the rules
        my @rules = $mix.map({ (%!tags{$_.key}, 0) => $_.value });

        if $warn {
            note 'None of the keys of the argument are known tags.' if @rules.elems == 0;
            note 'Some of the keys of the argument are not known tags.' if 0 < @rules.elems < $mix.elems;
        }

        # Make the column matrix
        my $mat = Math::SparseMatrix.new(
                    :@rules,
                    nrow => $!M.ncol,
                    ncol => 1,
                    row-names => $!M.column-names,
                    column-names => [$item-name, ]);

        if !$column { $mat .= transpose }

        return $mat;
    }

    method make-history-vector(
            Mix:D $mix,
            Bool:D :$column = False,
            Str:D :$tag-name = 'history',
            Bool:D :$warn = False
                               ) {
        # Make sure the items and tags are current
        self!file-in-items-and-tags if %!items.elems == 0 || %!tags.elems == 0 || %!items.elems != $!M.nrow || %!tags.elems != $!M.ncol;

        # Make the rules
        my @rules = $mix.map({ (0, %!items{$_.key}) => $_.value });

        if $warn {
            note 'None of the keys of the argument are known items.' if @rules.elems == 0;
            note 'Some of the keys of the argument are not known items.' if 0 < @rules.elems < $mix.elems;
        }

        # Make the row matrix
        my $mat = Math::SparseMatrix.new(
                :@rules,
                nrow => 1,
                ncol => $!M.nrow,
                row-names => [$tag-name, ],
                column-names => $!M.row-names,
                );

        if $column { $mat .= transpose }

        return $mat;
    }

    ##========================================================
    ## Setters
    ##========================================================
    method set-smr-matrix($m) {
        return self.set-M($m);
    }

    #| Set recommendation matrix.
    method set-M($arg) {
        die "The first argument is expected to be a Math::SparseMatrix object."
        unless $arg ~~ Math::SparseMatrix:D;
        $!M = $arg.clone;
        self!file-in-items-and-tags;
        return self;
    }

    #| Set recommendation sub-matrices.
    method set-matrices($arg) {
        die "The first argument is expected to be a hashmap of Math::SparseMatrix objects."
        unless $arg ~~ Map:D && $arg.values.all ~~ Math::SparseMatrix:D;
        %!matrices = $arg;
        return self;
    }

    #| Set the tag type weights.
    method set-tag-type-weights($arg) {
        die "The first argument is expected to be a hashmap of strings to numbers."
        unless $arg ~~ Map:D && $arg.values.all ~~ Numeric:D;
        %!tag-type-weights = $arg;
        return self;
    }

    #| Set data.
    method set-data($arg) {
        $!data = $arg;
        return self;
    }

    #| Set pipeline value.
    method set-value($arg) {
        $!value = $arg;
        return self;
    }

    ##========================================================
    ## Takers
    ##========================================================
    #| Take the tag type matrices
    method take-matrices() { %!matrices }

    #| Take the recommender matrix
    method take-smr-matrix() { $!M}

    #| Take the recommender matrix
    method take-M() { $!M }

    #| Take tag type weights
    method take-tag-type-weights(-->Map:D) {
        %!tag-type-weights
    }

    #| Take the data
    method take-data() {
        $!data
    }

    #| Take the pipeline value.
    method take-value() {
        $!value
    }

    #| Take sub-matrix corresponding to the argument.
    method sub-matrix(Str:D $tag-type) {
        die "The tag type $tag-type is not known in the recommender."
        unless self.take-matrices{$tag-type}:exists;
        self.take-matrices{$tag-type}
    }

    ##========================================================
    ## Echoers
    ##========================================================
    method echo-M(:&with = &say) {
        &with($!M);
        self
    }

    method echo-matrices(:&with = &say) {
        &with(%!matrices);
        self
    }

    method echo-tag-type-weights(:&with = &say) {
        &with(%!tag-type-weights);
        self
    }

    method echo-data(:&with = &say) {
        &with($!data);
        self
    }

    method echo-value(Str:D $note = '', :&with = &say) {
        &with($note, $!value);
        self
    }

    ##========================================================
    ## BUILD
    ##========================================================
    submethod BUILD(:$!M = Whatever, :%!matrices = %(), :%!tag-type-weights = %(), :$!data = Whatever, :$!value = Whatever) {
    }

    multi method new(:$M = Whatever, :%matrices = %(), :%tag-type-weights = %(), :$data = Whatever, :$value = Whatever) {
        self.bless(:$M, :%matrices, :%tag-type-weights, :$data, :$value);
    }

    multi method new($matrices, :$value = Whatever) {
        die 'The first argument is expected to be a hashmap of Math::SparseMatrix objects.'
        unless $matrices ~~ Map:D && $matrices.values.all ~~ Math::SparseMatrix:D;
        my $M = reduce({$^a.column-bind($^b)}, |$matrices.values);
        self.bless(:$M, :$matrices, :$value);
    }

    ##========================================================
    ## Clone
    ##========================================================
    method clone(::?CLASS:D: --> ::?CLASS:D) {
        return ML::SparseMatrixRecommender.new(:$!M, :%!matrices, :%!tag-type-weights, :$!data, :$!value);
    }

    ##========================================================
    ## Creation methods
    ##========================================================
    method create-item-tag-matrix(
            @data where @data.all ~~ Map:D,
            Str:D $item-key,
            Str:D $tag-key,
            Bool:D :$add-tag-types-to-column-names = True,
            Str:D :$tag-value-separator = ':'
            --> Math::SparseMatrix:D) {
        my @edge-dataset =
                do if $add-tag-types-to-column-names {
                    @data.map({ %( :from($_{$item-key}), :to($tag-key ~ $tag-value-separator ~ $_{$tag-key}), :weight(1) ) })
                } else {
                    @data.map({ %( :from($_{$item-key}), :to($_{$tag-key}), :weight(1) ) })
                }
        return Math::SparseMatrix.new(:@edge-dataset):directed;
    }

    method create-from-wide-form(
            @data where @data.all ~~ Map:D,
            :$tag-types is copy = Whatever,
            :item-column-name(:$item-key) is copy = Whatever,
            Bool:D :$add-tag-types-to-column-names = True,
            Str:D :$tag-value-separator = ':',
            *%extra) {
        if $item-key.isa(Whatever) {
            $item-key = @data.head.keys.first({ $_ ~~ /:i id/ });
            die 'Cannot automatically deduces the item column name (item-key)'
            unless $item-key.defined;
        }

        if $tag-types.isa(Whatever) {
            $tag-types = @data.head.keys.grep({$_ ne $item-key}).List
        }

        die 'The argument $tag-types is expected to be a list of strings or Whatever.'
        unless $tag-types ~~ (Array:D | List:D | Seq:D) && $tag-types.all ~~ Str:D;

        $tag-types .= grep({$_ ne $item-key});
        my %matrices = |$tag-types.map(-> $type {
            $type => self.create-item-tag-matrix(@data, $item-key, $type, :$add-tag-types-to-column-names, :$tag-value-separator)
        });

        return self.create-from-matrices(%matrices, |%extra);
    }

    method create-from-matrices(
            $matrices,
            Bool:D :$add-tag-types-to-column-names = True,
            Bool:D :$numerical-columns-as-categorical = False,
            Str:D :sep(:$tag-value-separator) = ':') {

        die 'The first argument is expected to be a hashmap of Math::SparseMatrix objects.'
        unless $matrices ~~ Map:D && $matrices.values.all ~~ Math::SparseMatrix:D;

        my @rowNames = $matrices.values.map(*.row-names);

        # Check if the row names of the matrices are the same
        if !reduce(&infix:<eqv>, @rowNames».sort».List) {
            @rowNames = $matrices.map(*.row-names).flat.unique.sort;
            %!matrices = $matrices.map({ $_.impose-rows(@rowNames) })
        } else {
            %!matrices = |$matrices
        }
        %!tag-type-weights = %!matrices.keys X=> 1;

        # Make the recommender matrix
        $!M = reduce({$^a.column-bind($^b)}, %!matrices.values);
        self!file-in-items-and-tags;

        return self;
    }


    ##========================================================
    ## Apply LSI functions
    ##========================================================
    #| Apply LSI functions to the entries of the recommendation matrix.
    multi method apply-term-weight-functions(
            :global(:$global-weight-func) = Whatever, #= LSI global term weight function. One of "ColumnSum", "Entropy", "IDF", "None".
            :local(:$local-weight-func)  = Whatever,  #= LSI local term weight function. One of "Binary", "Log", "None".
            :normalizer(:$normalizer-func) = Whatever    #= LSI normalizer function. One of "Cosine", "None", "RowSum".
                                             ) {
        return self.apply-term-weight-functions($global-weight-func, $local-weight-func, $normalizer-func);
    }

    multi method apply-term-weight-functions(
            $global-weight-func is copy = Whatever, #= LSI global term weight function. One of "ColumnSum", "Entropy", "IDF", "None".
            $local-weight-func is copy = Whatever,  #= LSI local term weight function. One of "Binary", "Log", "None".
            $normalizer-func is copy = Whatever     #= LSI normalizer function. One of "Cosine", "None", "RowSum".
                                             ) {
        %!matrices = %!matrices.kv.map(-> $k, $m {
            $k => self.apply-lsi-weight-functions($m, $global-weight-func, $local-weight-func, $normalizer-func)
        });

        # Make the recommender matrix
        $!M = reduce({$^a.column-bind($^b)}, %!matrices.values);
        self!file-in-items-and-tags;
        return self;
    }

    ##========================================================
    ## Profile
    ##========================================================
    #| Find items profile.
    #| * C<@items> A list or a mix of items.
    #| * C<$normalize> Should the recommendation scores be normalized or not?
    #| * C<$warn> Should warnings be issued or not?
    multi method profile(@items, Bool:D :$normalize = True, Bool:D :$warn = True) {
        self.profile(Mix(@items), :$normalize, :$warn)
    }

    multi method profile(Str:D $item, Bool:D :$normalize = True, Bool:D :$warn = True) {
        self.profile(Mix([$item]), :$normalize, :$warn)
    }

    multi method profile($items where * ~~ Map:D, Bool:D :$normalize = True, Bool:D :$warn = True) {
        self.profile($items.Mix, :$normalize, :$warn)
    }

    multi method profile(Mix:D $items, Bool:D :$normalize = True, Bool:D :$warn = True) {

        # Make sure the items and tags are current
        self!file-in-items-and-tags if %!items.elems == 0 || %!tags.elems == 0 || %!items.elems != $!M.nrow || %!tags.elems != $!M.ncol;

        ## Make sure items are known
        my %itemsQuery = $items.grep({ %!items{$_.key}:exists });

        if %itemsQuery.elems == 0 && $warn {
            warn 'None of the items is known in the recommender.';
            self.set-value(%());
            return self
        }

        if %itemsQuery.elems < $items.elems && $warn {
            warn 'Some of the items are unknown in the recommender.';
        }

        # Make history vector
        my $histVec = self.make-history-vector(%itemsQuery.Mix);

        ## Compute the profile
        my $prof = $histVec.dot($!M);

        ## Normalize
        if $normalize {
            $prof = self!max-normalize-sparse-matrix($prof, :abs-max);
        }

        ## Sort
        my @res = $prof.column-sums(:p).grep(*.value > 0).sort({ -$_.value }).map({ $_.key => $_.value });

        ## Result
        $!value = @res;

        return self;
    }

    ##========================================================
    ## Recommend by history
    ##========================================================
    #| Recommend items for a consumption history (that is a list or a mix of items.)
    #| * C<@items> A list or a mix of items.
    #| * C<$nrecs> Number of recommendations.
    #| * C<$normalize> Should the recommendation scores be normalized or not?
    #| * C<$remove-history> Should the history be removed from the result recommendations or not??
    #| * C<$warn> Should warnings be issued or not?
    multi method recommend(@items,
                           Numeric:D $nrecs = 12,
                           Bool:D :$normalize = False,
                           Bool:D :$remove-history = True,
                           Bool:D :$warn = True) {
        self.recommend(Mix(@items), $nrecs, :$normalize, :$remove-history, :$warn)
    }

    multi method recommend(%items where * ~~ Map:D,
                           Numeric:D $nrecs = 12,
                           Bool:D :$normalize = False,
                           Bool:D :$remove-history = True,
                           Bool:D :$warn = True) {
        self.recommend(%items.Mix, $nrecs, :$normalize, :$remove-history, :$warn)
    }

    multi method recommend($item,
                           Numeric:D $nrecs = 12,
                           Bool:D :$normalize = False,
                           Bool:D :$remove-history = True,
                           Bool:D :$warn = True) {
        self.recommend(Mix([$item]), $nrecs, :$normalize, :$remove-history, :$warn)
    }

    multi method recommend(Mix:D $items,
                           Numeric:D $nrecs = 12,
                           Bool:D :$normalize = False,
                           Bool:D :$remove-history = True,
                           Bool:D :$warn = True) {
        # It can be made faster using a history vector,
        # but it is just easy to compute the profile first and then call recommend-by-profile.
        self.recommend-by-profile(self.profile($items).take-value, $nrecs, :$normalize, :$warn)
    }

    ##========================================================
    ## Recommend by profile
    ##========================================================
    #| Recommend items for a consumption profile (that is a list or a mix of tags.)
    #| * C<@prof> A list or a mix of tags.
    #| * C<$nrecs> Number of recommendations.
    #| * C<$normalize> Should the recommendation scores be normalized or not?
    #| * C<$object> Should the result be an object or not?
    #| * C<$warn> Should warnings be issued or not?
    multi method recommend-by-profile(@prof,
                                      Numeric:D $nrecs = 12,
                                      Bool:D :$normalize = True,
                                      Bool:D :$vector-result = False,
                                      Bool:D :$warn = True) {
        self.recommend-by-profile(Mix(@prof), $nrecs, :$normalize, :$vector-result, :$warn)
    }

    multi method recommend-by-profile(%prof where * ~~ Map:D,
                                      Numeric:D $nrecs = 12,
                                      Bool:D :$normalize = True,
                                      Bool:D :$vector-result = False,
                                      Bool:D :$warn = True) {
        self.recommend-by-profile(%prof.Mix, $nrecs, :$normalize, :$vector-result, :$warn)
    }

    multi method recommend-by-profile(Str $profTag,
                                      Numeric:D $nrecs = 12,
                                      Bool:D :$normalize = True,
                                      Bool:D :$vector-result = False,
                                      Bool:D :$warn = True) {
        self.recommend-by-profile(Mix([$profTag]), $nrecs, :$normalize, :$vector-result, :$warn)
    }

    multi method recommend-by-profile(Mix:D $prof,
                                      Numeric:D $nrecs is copy = 12,
                                      Bool:D :$normalize = True,
                                      Bool:D :$vector-result = False,
                                      Bool:D :$warn = True) {

        # Make sure the items and tags are current
        self!file-in-items-and-tags if %!items.elems == 0 || %!tags.elems == 0 || %!items.elems != $!M.nrow || %!tags.elems != $!M.ncol;

        ## Make sure tags are known
        my %profQuery = $prof.grep({ %!tags{$_.key}:exists });

        if %profQuery.elems == 0 && $warn {
            warn 'None of the profile tags is known in the recommender.';
            self.set-value(%());
            return self;
        }

        if 0 < %profQuery.elems < $prof.elems && $warn {
            warn 'Some of the profile tags are unknown in the recommender.';
        }

        $nrecs = round($nrecs);

        if $nrecs <= 0 {
            note 'The second argument is expected to be a positive integer or Inf.';
            self.set-value(%());
            return self;
        }

        ## Make the sparse matrix/vector for the profile
        my $svec = self.make-profile-vector(%profQuery.Mix, :$warn);

        ## Compute recommendations
        my $rec = $!M.dot($svec);

        ## Normalize
        if $normalize {
            $rec = self!max-normalize-sparse-matrix($rec, :abs-max);
        }

        # Vector result
        if $vector-result {

            if $nrecs < $rec.rows-count {
                my %recs2 = $rec.row-sums(:p);
                my @recs2 = %recs2.grep(*.value > 0).sort(-*.value)>>.key[^$nrecs];
                $rec = $rec[@recs2;*].impose-row-names($rec.row-names);
            }

        } else {
            ## Sort
            my @res = $rec.row-sums(:p).sort({ -$_.value }).map({ $_.key => $_.value });

            ## Result
            $rec = @res.head(min($nrecs, @res.elems)).Array;
        }

        # Assign obtained recommendations to the pipeline value
        $!value = $rec;

        return self;
    }

    ##========================================================
    ## Filter by profile
    ##========================================================
    #| Filter items by profile.
    #| * C<$prof> A profile specification used to filter with.
    #| * C<$type> The type of filtering one of "union" or "intersection".
    #| * C<$object> Should the result be an object or not?
    #| * C<$warn> Should warnings be issued or not?
    multi method filter-by-profile(Mix:D $prof,
                                   Str :$type = 'intersection',
                                   Bool :$object = True,
                                   Bool :$warn = True) {
        return self.filter-by-profile($prof.keys, :$type, :$object, :$warn);
    }

    multi method filter-by-profile(@prof,
                                   Str :$type = 'intersection',
                                   Bool :$object = True,
                                   Bool :$warn = True) {
        my %profMix;
        if $type.lc eq 'intersection' {
            my $profileVec = self.make-profile-vector(@prof.Mix);
            my %sVec = self.take-M.unitize(:clone).dot($profileVec).row-sums(:pairs);
            my $n = $profileVec.column-sums.head;
            %profMix = %sVec.grep({ $_.value >= $n });

        } elsif $type.lc eq 'union' {

            %profMix = self.recommend-by-profile(@prof).take-value

        } else {
            note 'The value of the type argument is expected to be one of \'intersection\' or \'union\'.' if $warn;
            self.set-value(%());
            return self;
        }

        ## Result
        self.set-value(%profMix.keys.List);

        return self;
    }

    ##========================================================
    ## Retrieve by query elements
    ##========================================================
    # TBD...

    ##========================================================
    ## Classify
    ##========================================================
    #| Classify by profile vector.
    #| C<$tagType> -- Tag type to classify to.
    #| C<$profile> -- A tag, a list of tags, a dictionary of scored tags.
    #| C<:$n-top-nearest-neighbors> -- Number of top nearest neighbors to use.
    #| C<:$voting> -- Should simple voting be used or a weighted sum?
    #| C<:$max-number-of-labels> -- The maximum number of labels to be returned; if None all found labels are returned.
    #| C<:$drop-zero-scored-labels> -- Should the labels with zero scores be dropped or not?
    #| C<:$normalize> -- Should the scores be normalized?
    #| C<:$ignore-unknown> -- Should the unknown tags be ignored or not?
    #| C<$object> -- Should the result be an object or not?
    multi method classify-by-profile(Str $tagType, @profile, *%args) {
        return self.classify-by-profile($tagType, %(@profile X=> 1.0).Mix, |%args);
    }

    multi method classify-by-profile(Str:D $tag-type,
                                     Mix:D $profile,
                                     UInt:D :$n-top-nearest-neighbors = 100,
                                     Bool:D :$voting = False,
                                     Bool:D :$drop-zero-scored-labels = True,
                                     :$max-number-of-labels = Whatever,
                                     Bool:D :$normalize = True,
                                     Bool:D :$warn = False) {

        # Verify tag_type
        unless $tag-type ∈ self.take-matrices.keys {
            die "The value of the first argument is not a known tag type.";
        }

        # Compute the recommendations
        my $recs = self.recommend-by-profile(
                $profile,
                $n-top-nearest-neighbors,
                vector-result => True,
                :$warn
                ).take-value;

        # "Nothing" result
        if $recs.column-sums.head== 0 {
            self.set-value(%());
            return self;
        }

        # Get the tag type matrix
        my $mat-tag-type = self.take-matrices{$tag-type}.clone;

        # Transpose in place
        $recs = $recs.transpose;

        # Respect voting
        if $voting {
            $recs.unitize(:!clone);
        }

        # Get scores
        my $cl-res = $recs.dot($mat-tag-type);

        # Convert to dictionary
        $cl-res = $cl-res.column-sums(:pairs);

        # Drop zero scored labels
        if $drop-zero-scored-labels {
            $cl-res = $cl-res.grep({ .value > 0 }).Hash;
        }

        # Normalize
        if $normalize {
            my $cl-max = $cl-res.values.max;
            if $cl-max > 0 {
                $cl-res = $cl-res.map({ .key => .value / $cl-max }).Hash;
            }
        }

        # Reverse sort
        $cl-res = $cl-res.sort({ -$_.value }).Hash;

        # Pick max-top labels
        if $max-number-of-labels && $max-number-of-labels < $cl-res.elems {
            $cl-res = $cl-res.List[^$max-number-of-labels].Hash;
        }

        # Result
        self.set-value($cl-res);

        return self;
    }

    ##========================================================
    ## Prove by metadata
    ##========================================================
    multi method prove-by-metadata(@profile, @items) {
        return self.prove-by-metadata(%( @profile X=> 1.0), @items);
    }

    multi method prove-by-metadata(%profile, @items) {
        note "Proving by metadata is not implemented yet.";
        return self;
    }

    ##========================================================
    ## Prove by history
    ##========================================================
    multi method prove-by-history(@history, @items) {
        return self.prove-by-history(%( @history X=> 1.0), @items);
    }

    multi method prove-by-history(%history, @items) {
        note "Proving by history is not implemented yet.";
        return self;
    }

    ##========================================================
    ## Remove tag type(s)
    ##========================================================
    #| Remove tag types.
    #| * C<@tagTypes> A list of tag types to be removed
    method remove-tag-types(@tagTypes) {
        note "Removing tag types is not implemented yet.";
        return self;
    }

    ##========================================================
    ## Filter matrix
    ##========================================================
    multi method filter-matrix(%profile) {
        return self.filter-matrix(%profile.values);
    }

    multi method filter-matrix(@profile) {
        note "Filter matrix is not implemented yet.";
        return self;
    }

    ##========================================================
    ## Recommenders algebra -- Join
    ##========================================================
    method join($smr2, Str $type = 'same') {
        my @expectedJoinTypes = <same outer union inner left>;
        note "Recommender joining is not implemented yet.";
        return self;
    }

    ##========================================================
    ## Recommenders algebra -- Annex matrix
    ##========================================================
    method annex-sub-matrix(%matrixInverseIndexes, Str $newTagType) {
        note "Annexing of a sub-matrix is not implemented yet.";
        return self;
    }

    ##========================================================
    ## Recommenders algebra -- To tag type recommender
    ##========================================================
    method make-tag-type-recommender(Str $tagTypeTo, @tagTypes) {
        note "Tag type recommender making is not implemented yet.";
        return self;
    }

    ##========================================================
    ## Representation
    ##========================================================
    #| To Hash
    multi method Hash(::?CLASS:D:-->Hash) {
        return
                {
                    matrices => self.take-matrices,
                    tag-type-weights => self.take-tag-type-weights,
                    data => self.take-data,
                    value => self.take-value,
                };
    }

    #| To string
    multi method Str(::?CLASS:D:-->Str) {
        return self.gist;
    }

    #| To gist
    multi method gist(::?CLASS:D:-->Str) {
        return 'ML::SparseMatrixRecommender' ~ (matrix-dimensions => (self.take-M.rows-count, self.take-M.columns-count),
                                                density => self.take-M.density,
                                                tag-types => self.take-matrices.elems ≤ 12 ?? self.take-matrices.keys.List !! self.take-matrices.elems).List.raku;
    }
}