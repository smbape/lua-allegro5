class ArrowExpression {
    constructor({
        arrow,
        identifier
    }, loc) {
        this.arrow = arrow;
        this.identifier = identifier;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.arrow.visit(cb, parents);
        this.identifier.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.ArrowExpression = ArrowExpression;
