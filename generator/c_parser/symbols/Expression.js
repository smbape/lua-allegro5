class Expression {
    constructor(expression, loc) {
        this.expression = expression;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        cb(this, parents);
    }
}

exports.Expression = Expression;
