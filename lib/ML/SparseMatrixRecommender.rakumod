use v6;

use Math::SparseMatrix;

## Monadic-like definition.
class ML::SparseMatrixRecommender {

    ##========================================================
    ## Data members
    ##========================================================
    has %!matrices = %();
    has $!M = Whatever;
    has %!tag-type-weights = %();
    has $!data = Whatever;
    has $!value = Whatever;

    ##========================================================
    ## Setters
    ##========================================================
    method set-smr-matrix(Math::SparseMatrix:D $m) {
        self.m = $m;
        self
    }

    #| Set recommendation matrix.
    method set-M($arg) {
        die "The first argument is expected to be a SSparseMatrix object."
        unless $arg ~~ Math::SparseMatrix:D;
        $!M = $arg.clone;
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
    method echo-M() {
        say $!M;
        self
    }

    method echo-matrices() {
        say %!matrices;
        self
    }

    method echo-tag-type-weights() {
        say %!tag-type-weights;
        self
    }

    method echo-data() {
        say $!data;
        self
    }

    method echo-value() {
        say $!value;
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
        my $M = reduce({$^a.column-bind($^b)}, |$matrices);
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
    method create-item-tag-matrix(@data where @data.all ~~ Map:D, Str:D $item-key, Str:D $tag-key --> Math::SparseMatrix:D) {
        my @edge-dataset = @data.map({ %( :from($_{$item-key}), :to($tag-key ~ ":" ~ $_{$tag-key}), :weight(1) ) });
        return Math::SparseMatrix.new(:@edge-dataset):directed;
    }

    method create-from-wide-form(
            @data where @data.all ~~ Map:D,
            :$tag-types is copy = Whatever,
            :item-column-name(:$item-key) is copy = Whatever,
            *%extra) {
        if $item-key.isa(Whatever) {
            $item-key = @data.head.keys.first({ $_ ~~ /:i id/ });
            die 'Cannot automatically deduces the item column name (item-key)'
            unless $item-key.defined;
        }

        if $tag-types.isa(Whatever) {
            $tag-types = @data.head.keys.grep({$_ ne $item-key})
        }

        die 'The argument $tag-types is expected to be a list of strings or Whatever.'
        unless $tag-types ~~ (Array:D | List:D | Seq:D) && $tag-types.all ~~ Str:D;

        $tag-types .= grep({$_ ne $item-key});
        my %matrices = $tag-types.map(-> $type {
            $type => self.create-item-tag-matrix(@data, $item-key, $type)
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

        return self;
    }

    ##========================================================
    ## Profile
    ##========================================================
    #| Find items profile.
    #| * C<@items> A list or a mix of items.
    #| * C<$normalize> Should the recommendation scores be normalized or not?
    #| * C<$object> Should the result be an object or not?
    #| * C<$warn> Should warnings be issued or not?
    multi method profile(@items, Bool :$normalize = False, Bool :$object = True, Bool :$warn = True) {
        self.profile(Mix(@items), :$normalize, :$object, :$warn)
    }

    multi method profile(Str $item, Bool :$normalize = False, Bool :$object = True, Bool :$warn = True) {
        self.profile(Mix([$item]), :$normalize, :$object, :$warn)
    }

    multi method profile(Mix:D $items, Bool :$normalize = False, Bool :$object = True, Bool :$warn = True) {
        #`[
        ## Transpose inverse indexes if needed
        if %!itemInverseIndexes.elems == 0 { self.transpose-tag-inverse-indexes() }

        ## Except the line above the code of this method is same/dual to .recommend-by-profile

        ## Make sure items are known
        my $itemsQuery = Mix($items{($items (&) $!knownItems).keys}:p);

        if $itemsQuery.elems == 0 and $warn {
            warn 'None of the items is known in the recommender.';
            self.set-value(%());
            return $object ?? self !! self.take-value();
        }

        if $itemsQuery.elems < $items.elems and $warn {
            warn 'Some of the items are unknown in the recommender.';
        }

        ## Compute the profile
        my %itemMix = [(+)] %!itemInverseIndexes{$itemsQuery.keys} Z<<*>> $itemsQuery.values;

        ## Normalize
        if $normalize { %itemMix = self.normalize(%itemMix, 'max-norm') }

        ## Sort
        my @res = %itemMix.sort({ -$_.value });

        ## Result
        self.set-value(@res);

        return $object ?? self !! self.take-value();
        ]
    }

    ##========================================================
    ## Recommend by history
    ##========================================================
    #| Recommend items for a consumption history (that is a list or a mix of items.)
    #| * C<@items> A list or a mix of items.
    #| * C<$nrecs> Number of recommendations.
    #| * C<$normalize> Should the recommendation scores be normalized or not?
    #| * C<$object> Should the result be an object or not?
    #| * C<$warn> Should warnings be issued or not?
    multi method recommend(@items, Numeric:D $nrecs = 12, Bool :$normalize = False, Bool :$object = True,
                           Bool :$warn = True) {
        self.recommend(Mix(@items), $nrecs, :$normalize, :$object, :$warn)
    }

    multi method recommend($item, Numeric:D $nrecs = 12, Bool :$normalize = False, Bool :$object = True,
                           Bool :$warn = True) {
        self.recommend(Mix([$item]), $nrecs, :$normalize, :$object, :$warn)
    }

    multi method recommend(Mix:D $items, Numeric:D $nrecs = 12, Bool :$normalize = False, Bool :$object = True,
                           Bool :$warn = True) {
        ## It is not fast, but it is just easy to compute the profile and call recommend-by-profile.
        #self.recommend-by-profile(Mix(self.profile($items):!object), $nrecs, :$normalize, :$object, :$warn)
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
                                      Bool :$normalize = False,
                                      Bool :$object = True,
                                      Bool :$warn = True) {
        self.recommend-by-profile(Mix(@prof), $nrecs, :$normalize, :$object, :$warn)
    }

    multi method recommend-by-profile(Str $profTag,
                                      Numeric:D $nrecs = 12,
                                      Bool :$normalize = False,
                                      Bool :$object = True,
                                      Bool :$warn = True) {
        self.recommend-by-profile(Mix([$profTag]), $nrecs, :$normalize, :$object, :$warn)
    }

    multi method recommend-by-profile(Mix:D $prof,
                                      Numeric:D $nrecs is copy = 12,
                                      Bool :$normalize = False,
                                      Bool :$warn = True) {

        ## Make sure tags are known
        my %profQuery = $prof.grep({ $_.key ∈ $!M.column-names });

        if %profQuery.elems == 0 && $warn {
            warn 'None of the profile tags is known in the recommender.';
            self.set-value(%());
            return self;
        }

        if %profQuery.elems < $prof.elems and $warn {
            warn 'Some of the profile tags are unknown in the recommender.';
        }

        $nrecs = round($nrecs);

        if $nrecs < 0 {
            warn 'The second argument is expected to be a positive integer or Inf';
            self.set-value(%());
            return self;
        }

        say (:%profQuery);

        ## Make the sparse matrix/vector for the profile
        my $svec = Math::SparseMatrix.new(
                dense-matrix => %profQuery.values.map({ [$_, ]}).Array,
                nrow => %profQuery.elems,
                ncol => 1,
                row-names => %profQuery.keys,
                column-names => ['prof', ]);
        $svec.print;
        $svec .= impose-row-names($!M.column-names);
        say (:$svec);

        ## Compute recommendations
        my $rec = $!M.dot($svec);

        ## Normalize
        # TBD
        #if $normalize { %profMix = self.normalize(%profMix, 'max-norm') }

        ## Sort
        # TBD
        my @res = $rec.row-sums(:p).sort({ -$_.value }).map({ $_.key => $_.value });

        ## Result
        $!value = @res.head(min($nrecs, @res.elems));

        return self;
    }

    ##========================================================
    ## Filter by profile
    ##========================================================
    #| Filter items by profile
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
        note "Filter by matrix is not implemented yet.";
        return self;
        #`[
        my %profMix;
        if $type.lc eq 'intersection' {

            %profMix = [(&)] %!tagInverseIndexes{@prof};

        } elsif $type.lc eq 'union' {

            %profMix = [(|)] %!tagInverseIndexes{@prof};

        } else {
            warn 'The value of the type argument is expected to be one of \'intersection\' or \'union\'.' if $warn;
            self.set-value(%());
            return $object ?? self !! self.take-value();
        }

        ## Result
        self.set-value(%profMix.keys.Array);

        return $object ?? self !! self.take-value();
       ]
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

    multi method classify-by-profile(Str $tagType,
                                     Mix:D $profile,
                                     UInt :$n-top-nearest-neighbors = 100,
                                     Bool :$voting = False,
                                     Bool :$drop-zero-scored-labels = True,
                                     :$max-number-of-labels = Whatever,
                                     Bool :$normalize = True,
                                     Bool :$ignore-unknown = False,
                                     Bool :$object = True) {

        # Verify tag_type
        if %!matrices{$tagType}:!exists {
            die "The value of the first argument $tagType is not a known tag type.";
        }

        note "Classify by profile is not implemented yet.";
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
}