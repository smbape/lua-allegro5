class IdentifierDesignator {
    constructor({
        dot,
        identifier
    }, loc) {
        this.dot = dot;
        this.identifier = identifier;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.dot.visit(cb, parents);
        this.identifier.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.IdentifierDesignator = IdentifierDesignator;
