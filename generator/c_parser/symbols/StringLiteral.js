class StringLiteral {
    constructor(value, loc) {
        this.value = value;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        cb(this, parents);
    }
}

exports.StringLiteral = StringLiteral;
