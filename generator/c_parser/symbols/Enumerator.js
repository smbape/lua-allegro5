class Enumerator {
    constructor({
        identifier,
        equals,
        expression
    }, loc) {
        this.identifier = identifier;
        this.equals = equals;
        this.expression = expression;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.identifier.visit(cb, parents);
        this.equals.visit(cb, parents);
        this.expression.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.Enumerator = Enumerator;
