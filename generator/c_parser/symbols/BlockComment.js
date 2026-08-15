class BlockComment {
    constructor({
        start,
        end
    }) {
        this.start = start;
        this.end = end;
    }

    visit(cb, parents = []) {
        cb(this, parents);
    }
}

exports.BlockComment = BlockComment;
