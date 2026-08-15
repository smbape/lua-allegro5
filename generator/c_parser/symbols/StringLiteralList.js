class StringLiteralList {
    constructor(literals, loc) {
        this.literals = literals;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        for (const literal of this.literals) {
            literal.visit(cb, parents);
        }

        parents.pop();
        cb(this, parents);
    }
}

exports.StringLiteralList = StringLiteralList;
