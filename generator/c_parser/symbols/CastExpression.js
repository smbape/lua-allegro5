class CastExpression {
    constructor({
        type,
        expression
    }, loc) {
        this.type = type;
        this.expression = expression;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.type.visit(cb, parents);
        this.expression.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.CastExpression = CastExpression;
