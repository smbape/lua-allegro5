class CompoundStatement {
    constructor({
        open,
        blocks,
        close
    }, loc) {
        this.open = open;
        this.blocks = blocks;
        this.close = close;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.open.visit(cb, parents);

        for (const block of this.blocks) {
            block.visit(cb, parents);
        }

        this.close.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.CompoundStatement = CompoundStatement;
