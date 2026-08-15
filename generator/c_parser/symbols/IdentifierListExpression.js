class IdentifierListExpression {
    constructor({
        open,
        identifiers,
        close
    }, loc) {
        this.open = open;
        this.identifiers = identifiers;
        this.close = close;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.open.visit(cb, parents);

        for (const identifier of this.identifiers) {
            identifier.visit(cb, parents);
        }

        this.close.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.IdentifierListExpression = IdentifierListExpression;
