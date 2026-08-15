class UnaryExpression {
    constructor({
        operator,
        expression
    }, loc) {
        this.operator = operator;
        this.expression = expression;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.operator.visit(cb, parents);
        this.expression.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.UnaryExpression = UnaryExpression;
