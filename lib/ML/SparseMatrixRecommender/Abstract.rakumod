class ML::SparseMatrixRecommender::Abstract{

    has $!value;

    method set-value($arg) {
        $!value = $arg;
        self
    }

    method take-value() {
        $!value
    }
}
