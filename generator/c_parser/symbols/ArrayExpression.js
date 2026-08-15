class ArrayExpression {
    constructor({
        open,
        storage,
        qualifiers,
        expression,
        close
    }, loc) {
        this.open = open;
        this.storage = storage;
        this.qualifiers = qualifiers;
        this.expression = expression;
        this.close = close;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.open.visit(cb, parents);

        if (this.storage) {
            this.storage.visit(cb, parents);
        }

        for (const qualifier of this.qualifiers) {
            qualifier.visit(cb, parents);
        }

        if (this.expression) {
            this.expression.visit(cb, parents);
        }

        this.close.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.ArrayExpression = ArrayExpression;
